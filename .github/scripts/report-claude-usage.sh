#!/usr/bin/env bash
# Summarize Claude Code usage from the action's execution file.
# Posts (or upserts) a sticky github-actions[bot] issue comment with the usage table.
#
# The action writes JSON.stringify(messages) -> a JSON ARRAY, so the result
# record must be selected with map()/last, NOT a bare `select()` (that throws
# "Cannot index array with string", which silently broke earlier attempts).
#
# Required env:
#   EXEC_FILE    - path to execution file (steps.claude.outputs.execution_file)
#   MODEL        - model name (steps.model_tier.outputs.model)
#
# Optional env (sticky PR comment as github-actions[bot]):
#   PR           - PR number
#   REPO         - owner/repo
#   GH_TOKEN     - default GITHUB_TOKEN (github.token)

set -u

MARKER="<!-- claude-renovate-usage -->"
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

# Sticky PR comment as github-actions[bot] (best-effort; never fail job).
# Upsert by hidden marker so Renovate rebase/sync re-runs update one comment
# instead of spamming new ones.
if [ -n "${PR:-}" ] && [ -n "${REPO:-}" ]; then
  comment_body=$(printf '%s\n### Claude Review Usage\n%s' "$MARKER" "$table")
  cid=$(gh api "repos/$REPO/issues/$PR/comments" --paginate \
    --jq "[.[] | select(.user.login==\"github-actions[bot]\" and (.body|startswith(\"$MARKER\")))] | last | .id // empty" \
    2>&1 || true)
  if [ -n "$cid" ] && [[ "$cid" =~ ^[0-9]+$ ]]; then
    gh api -X PATCH "repos/$REPO/issues/comments/$cid" \
      -f body="$comment_body" || true
  else
    echo "Usage comment cid lookup result: ${cid:-(empty)}"
    gh api -X POST "repos/$REPO/issues/$PR/comments" \
      -f body="$comment_body" || true
  fi
fi
