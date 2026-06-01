#!/usr/bin/env bash
# Summarize Claude Code usage from the action's execution file.
# Appends the usage table into Claude's own PR review (amend via PUT), so it
# appears inline in the review rather than as a separate comment.
#
# The action writes JSON.stringify(messages) -> a JSON ARRAY, so the result
# record must be selected with map()/last, NOT a bare `select()` (that throws
# "Cannot index array with string", which silently broke earlier attempts).
#
# Required env:
#   EXEC_FILE    - path to execution file (steps.claude.outputs.execution_file)
#   MODEL        - model name (steps.model_tier.outputs.model)
#
# Optional env (amend into Claude's review):
#   PR           - PR number
#   REPO         - owner/repo
#   HEAD_SHA     - PR head SHA to match this run's review by commit_id
#   GH_TOKEN     - Claude App token (steps.claude.outputs.github_token) for edit

set -u

MARKER="<!-- claude-usage -->"
out="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

r=""
if [ -n "${EXEC_FILE:-}" ] && [ -f "$EXEC_FILE" ]; then
  r=$(jq -c 'map(select(.type=="result")) | last' "$EXEC_FILE" 2>/dev/null)
fi

if [ -z "$r" ] || [ "$r" = "null" ]; then
  echo "model=${MODEL:-unknown} (no usage data: execution file missing or unparseable)" >> "$out"
  exit 0
fi

# NOTE: computed fields must guard the source field INSIDE the expression. jq's //
# binds looser than / and *, so a trailing `// 0` does NOT prevent a null/number
# division or multiply error. Use `(.x // 0)/...` not `(.x/...) // 0`.
get() { printf '%s' "$r" | jq -r "$1 // 0"; }

table=$(cat <<EOF
| Metric | Value |
|---|---|
| Model | \`${MODEL:-unknown}\` |
| Turns | $(get '.num_turns') |
| Duration | $(get '(.duration_ms // 0)/1000 | floor')s |
| Input tokens | $(get '.usage.input_tokens') |
| Output tokens | $(get '.usage.output_tokens') |
| Cache read | $(get '.usage.cache_read_input_tokens') |
| Cache create | $(get '.usage.cache_creation_input_tokens') |
| Cost (USD) | \$$(get '(.total_cost_usd // 0)|(.*10000|round)/10000') |
EOF
)

# Write to Actions step summary
{
  echo "### Claude Review Usage"
  printf '%s\n' "$table"
} >> "$out"

# Amend into Claude's own PR review (best-effort; never fail job).
# Match this run's review by commit_id == HEAD_SHA so we don't touch reviews
# from prior runs on older commits.
# Requires GH_TOKEN = Claude App token (steps.claude.outputs.github_token) to
# have author identity for the edit.
if [ -n "${PR:-}" ] && [ -n "${REPO:-}" ] && [ -n "${HEAD_SHA:-}" ]; then
  rid=$(gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
    --jq "[.[] | select(.user.login==\"claude[bot]\" and .commit_id==\"$HEAD_SHA\")] | last | .id // empty" \
    2>/dev/null || true)
  if [ -n "$rid" ]; then
    body=$(gh api "repos/$REPO/pulls/$PR/reviews/$rid" --jq '.body' 2>/dev/null || true)
    if [ -n "$body" ]; then
      # Strip any existing usage block (idempotent: replaces stale data on re-runs).
      # Pattern: cut from MARKER onward, then trim the trailing \n and \n--- separator.
      base="${body%%"$MARKER"*}"
      base="${base%$'\n'}"
      base="${base%$'\n---'}"
      base="${base%$'\n'}"
      newbody=$(printf '%s\n\n---\n%s\n%s' "$base" "$MARKER" "$table")
      gh api -X PUT "repos/$REPO/pulls/$PR/reviews/$rid" \
        -f body="$newbody" >/dev/null 2>&1 || true
    fi
  fi
  # No matching review (rebase/skip run): do nothing on the PR — adding no noise.
fi
