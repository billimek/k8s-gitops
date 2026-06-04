#!/usr/bin/env bash
# Summarize Claude Code usage from the action's execution file.
# Posts (or upserts) a sticky github-actions[bot] issue comment with a cumulative
# table — one row per workflow run — so every review run's cost is visible rather
# than overwriting the previous run's numbers.
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

# NOTE: computed fields must guard the source field INSIDE the expression. jq's //
# binds looser than / and *, so a trailing `// 0` does NOT prevent a null/number
# division or multiply error. Use `(.x // 0)/...` not `(.x/...) // 0`.
get() { printf '%s' "$r" | jq -r "$1 // 0"; }

# ---------------------------------------------------------------------------
# Actions step summary — single-run detail table (unchanged from before)
# ---------------------------------------------------------------------------
if [ -n "$r" ] && [ "$r" != "null" ]; then
  {
    echo "### Claude Review Usage"
    echo "| Metric | Value |"
    echo "|---|---|"
    echo "| Model | \`${MODEL:-unknown}\` |"
    echo "| Turns | $(get '.num_turns') |"
    echo "| Duration | $(get '(.duration_ms // 0)/1000 | floor')s |"
    echo "| Input tokens | $(get '.usage.input_tokens') |"
    echo "| Output tokens | $(get '.usage.output_tokens') |"
    echo "| Cache read | $(get '.usage.cache_read_input_tokens') |"
    echo "| Cache create | $(get '.usage.cache_creation_input_tokens') |"
    echo "| Cost (USD) | \$$(get '(.total_cost_usd // 0)|(.*10000|round)/10000') |"
  } >> "$out"
else
  echo "model=${MODEL:-unknown} (no usage data: execution file missing or unparseable)" >> "$out"
fi

# ---------------------------------------------------------------------------
# Sticky PR comment — cumulative table (one row appended per run)
# ---------------------------------------------------------------------------
if [ -z "${PR:-}" ] || [ -z "${REPO:-}" ]; then
  exit 0
fi

# Build values for this run's row.
when=$(date -u +'%Y-%m-%d %H:%M')

# Extract version range from the PR title.
# Renovate titles look like:
#   "feat(container): update image ghcr.io/org/name ( 1.0.0 → 1.1.0 )"
# We want "1.0.0 -> 1.1.0" (ASCII arrow, compact).
version="-"
pr_title=$(gh pr view "$PR" --repo "$REPO" --json title --jq '.title' 2>/dev/null || true)
if [ -n "$pr_title" ]; then
  # Capture the two version strings around the → arrow (handles both → and ->).
  from_ver=$(printf '%s' "$pr_title" | grep -oE '\( [^ ]+ [→>-]' | grep -oE '[0-9][^ ]+' | head -1 || true)
  to_ver=$(printf '%s' "$pr_title" | grep -oE '[→>-] [^ ]+ \)' | grep -oE '[0-9][^ ]+' | head -1 || true)
  if [ -n "$from_ver" ] && [ -n "$to_ver" ]; then
    version="${from_ver} -> ${to_ver}"
  elif [ -n "$to_ver" ]; then
    version="-> ${to_ver}"
  fi
fi

model_short="${MODEL:-unknown}"
if [ -n "$r" ] && [ "$r" != "null" ]; then
  turns=$(get '.num_turns')
  cost=$(get '(.total_cost_usd // 0)|(.*10000|round)/10000')
  newrow="| ${when} | ${version} | \`${model_short}\` | ${turns} | \$${cost} |"
else
  newrow="| ${when} | ${version} | \`${model_short}\` | - | - (no data) |"
fi

# Fetch the existing sticky comment: id + body.
existing=$(gh api "repos/$REPO/issues/$PR/comments" --paginate \
  --jq "[.[] | select(.user.login==\"github-actions[bot]\" and (.body|startswith(\"$MARKER\")))] | last | {id: (.id // empty), body: (.body // \"\")}" \
  2>/dev/null || true)

cid=""
prior_rows=""
if [ -n "$existing" ] && [ "$existing" != "null" ]; then
  cid=$(printf '%s' "$existing" | jq -r '.id // empty' 2>/dev/null || true)
  existing_body=$(printf '%s' "$existing" | jq -r '.body // ""' 2>/dev/null || true)
  # Extract prior data rows: lines that start with "| " but are NOT the header
  # ("| When") or the separator ("| ---").
  if [ -n "$existing_body" ]; then
    prior_rows=$(printf '%s' "$existing_body" \
      | grep -E '^\| ' \
      | grep -vE '^\| (When|---)' \
      || true)
    # Cap at 30 rows to stay well within GitHub's 65536-char comment limit.
    prior_rows=$(printf '%s' "$prior_rows" | tail -30 || true)
  fi
fi

# Build the full comment body from scratch each time.
header="| When (UTC) | Version | Model | Turns | Cost |"
sep="|---|---|---|---|---|"

body_lines="${MARKER}
### Claude Review Usage
${header}
${sep}"

if [ -n "$prior_rows" ]; then
  body_lines="${body_lines}
${prior_rows}"
fi
body_lines="${body_lines}
${newrow}"

comment_body="$body_lines"

if [ -n "$cid" ] && [[ "$cid" =~ ^[0-9]+$ ]]; then
  gh api -X PATCH "repos/$REPO/issues/comments/$cid" \
    -f body="$comment_body" || true
else
  echo "Usage comment cid lookup result: ${cid:-(empty)} — posting new comment"
  gh api -X POST "repos/$REPO/issues/$PR/comments" \
    -f body="$comment_body" || true
fi
