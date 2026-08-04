#!/usr/bin/env bash
# Post-process the just-posted claude[bot] review in a single PUT:
#   1. Sanitize github.com links -> redirect.github.com (sanitize-review-body.sh)
#   2. Warn-mode validate the must_check list against the review body
#   3. Stamp the fingerprint marker so a future identical PR can be skipped
#
# Required env:
#   REPO, PR, GH_TOKEN, FP (fingerprint from review-fingerprint.sh)
#
# Optional env:
#   MUST_CHECK_PAIRS_FILE - "keyword|description" lines from classify-renovate-pr.sh
#
# Outputs (GITHUB_OUTPUT):
#   unaddressed_count

set -euo pipefail

: "${REPO:?REPO required}"
: "${PR:?PR required}"
: "${FP:?FP required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAIRS_FILE="${MUST_CHECK_PAIRS_FILE:-must-check-pairs.txt}"

review_json="$(gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
  --jq '[.[] | select(.user.login == "claude[bot]" or .user.login == "github-actions[bot]")] | last // {}' \
  2>/dev/null || echo '{}')"

review_id="$(printf '%s' "$review_json" | jq -r '.id // empty')"
body="$(printf '%s' "$review_json" | jq -r '.body // ""')"

if [[ -z "$review_id" ]]; then
  echo "no claude[bot]/github-actions[bot] review found to finalize -- nothing to do"
  echo "unaddressed_count=0" >> "$GITHUB_OUTPUT"
  exit 0
fi

# 1. Sanitize links and bare "#NNN" upstream references (rewritten to `#NNN`
# code spans by sanitize-review-body.sh so they stop auto-linking to this
# repo). This can't retract a cross-reference notification that already fired
# at post time -- see the NOTE in sanitize-review-body.sh -- so still flag any
# survivors in the step log for visibility. After sanitizing, a survivor is
# one already inside a code span (harmless) or one the rewrite's lookbehind
# intentionally left alone (e.g. "org/repo#123"); exclude both from the log.
body="$(printf '%s' "$body" | OWN_REPO="$REPO" "$SCRIPT_DIR/sanitize-review-body.sh")"

bare_refs="$(echo "$body" | grep -oE '(^|[^A-Za-z0-9/\`])#[0-9]+' | grep -oE '#[0-9]+' | sort -u || true)"
if [[ -n "$bare_refs" ]]; then
  echo "WARNING: review body still contains unescaped bare #NNN references (auto-linked to the wrong repo at post time): $(echo "$bare_refs" | tr '\n' ' ')"
fi

# 2. Warn-mode required-check validation
unaddressed=()
if [[ -f "$PAIRS_FILE" ]]; then
  while IFS='|' read -r keyword description; do
    [[ -z "$keyword" ]] && continue
    if ! echo "$body" | grep -qi "$keyword"; then
      unaddressed+=("$description")
    fi
  done < "$PAIRS_FILE"
fi

if [[ "${#unaddressed[@]}" -gt 0 ]]; then
  note="

---
> [!WARNING]
> **Unaddressed required checks (auto-detected, warn mode)**
> The following deterministically-derived checks were not clearly addressed in this review:
$(for u in "${unaddressed[@]}"; do echo ">- $u"; done)
"
  body="${body}${note}"
fi

# 3. Stamp fingerprint marker (enables future skip)
body="${body}

<!-- rr-fp:${FP} -->"

gh api -X PUT "repos/$REPO/pulls/$PR/reviews/$review_id" -f body="$body" > /dev/null

echo "unaddressed_count=${#unaddressed[@]}" >> "$GITHUB_OUTPUT"
echo "finalized review $review_id: unaddressed=${#unaddressed[@]} fp=$FP"
