#!/usr/bin/env bash
# Summarize Claude Code usage from the action's execution file and optionally
# post it as a sticky comment on the PR.
#
# The action writes JSON.stringify(messages) -> a JSON ARRAY, so the result
# record must be selected with map()/last, NOT a bare `select()` (that throws
# "Cannot index array with string", which silently broke earlier attempts).
#
# Required env:
#   EXEC_FILE    - path to the execution file from steps.claude.outputs.execution_file
#   MODEL        - model name from steps.model_tier.outputs.model
#
# Optional env (sticky PR comment):
#   PR           - PR number
#   REPO         - owner/repo
#   GH_TOKEN     - token with pull-requests:write

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

body=$(cat <<EOF
$MARKER
### Claude Review Usage
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

printf '%s\n' "$body" >> "$out"

# Sticky PR comment: upsert by hidden marker so Renovate rebase/sync re-runs
# update one comment instead of spamming new ones. Best-effort; never fail job.
# NOTE: gh api has no --arg; the MARKER constant is interpolated directly (safe:
# it's a fixed string, not user input). --paginate + gh's built-in --jq is the
# correct combination here (standalone jq would need jq -s which changes semantics).
if [ -n "${PR:-}" ] && [ -n "${REPO:-}" ]; then
  cid=$(gh api "repos/$REPO/issues/$PR/comments" --paginate \
    --jq "[.[] | select(.user.login==\"github-actions[bot]\" and (.body|startswith(\"$MARKER\")))] | last | .id // empty" \
    2>/dev/null || true)
  if [ -n "$cid" ]; then
    gh api -X PATCH "repos/$REPO/issues/comments/$cid" -f body="$body" >/dev/null 2>&1 || true
  else
    gh api -X POST "repos/$REPO/issues/$PR/comments" -f body="$body" >/dev/null 2>&1 || true
  fi
fi
