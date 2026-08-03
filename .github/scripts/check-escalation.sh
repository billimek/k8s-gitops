#!/usr/bin/env bash
# Decide whether a "light" (haiku) tier review needs to be escalated to a
# second, deeper "full" (sonnet) pass. Mirrors misospace/pr-reviewer-action's
# post-hoc escalation: primary model runs first and cheap; escalate only when
# its output signals an insufficient review.
#
# Required env:
#   DEPTH      - the tier depth that was used (light/full/deep)
#   REPO, PR   - to fetch the just-posted review body
#   GH_TOKEN
#
# Optional env:
#   EXEC_FILE  - path to the claude-code-action execution file
#
# Outputs (GITHUB_OUTPUT):
#   escalate  - "true"/"false"
#   reason    - short human-readable reason

set -euo pipefail

: "${DEPTH:?DEPTH required}"
: "${REPO:?REPO required}"
: "${PR:?PR required}"

escalate=false
reason=""

if [[ "$DEPTH" != "light" ]]; then
  echo "escalate=false" >> "$GITHUB_OUTPUT"
  echo "reason=not-light-tier" >> "$GITHUB_OUTPUT"
  echo "skipping escalation check: depth=$DEPTH is not light"
  exit 0
fi

if [[ -n "${EXEC_FILE:-}" && -f "$EXEC_FILE" ]]; then
  result="$(jq -c 'map(select(.type=="result")) | last' "$EXEC_FILE" 2>/dev/null || echo "null")"
  subtype="$(printf '%s' "$result" | jq -r '.subtype // ""' 2>/dev/null || true)"
  is_error="$(printf '%s' "$result" | jq -r '.is_error // false' 2>/dev/null || true)"
  if [[ "$subtype" == "error_max_turns" ]]; then
    escalate=true
    reason="hit max-turns budget at light tier"
  elif [[ "$is_error" == "true" ]]; then
    escalate=true
    reason="execution errored at light tier"
  fi
fi

if [[ "$escalate" == false ]]; then
  body="$(gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
    --jq '[.[] | select(.user.login == "claude[bot]" or .user.login == "github-actions[bot]")] | last | .body // ""' \
    2>/dev/null || echo "")"
  if echo "$body" | grep -qiE 'could not (verify|confirm|determine)|not (publicly available|found)|unable to (verify|confirm|determine)'; then
    escalate=true
    reason="review body hedges on findings it could not verify"
  fi
fi

echo "escalate=$escalate" >> "$GITHUB_OUTPUT"
echo "reason=${reason:-none}" >> "$GITHUB_OUTPUT"
echo "escalate=$escalate reason=${reason:-none}"
