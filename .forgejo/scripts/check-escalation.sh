#!/usr/bin/env bash
# Decide whether a "light" (haiku) tier review needs to be escalated to a
# second, deeper "full" (sonnet) pass: max-turns error, execution error,
# hedging language, missing release notes, or an Unknowns section.
#
# Required env:
#   DEPTH      - the tier depth that was used (light/full/deep)
#
# Optional env:
#   REVIEW_FILE - defaults to review.md
#   EXEC_FILE   - path to the reviewer's captured `claude --output-format
#                 json` result (a single JSON object)
#
# Outputs (GITHUB_OUTPUT):
#   escalate  - "true"/"false"
#   reason    - short human-readable reason

set -euo pipefail

: "${DEPTH:?DEPTH required}"

REVIEW_FILE="${REVIEW_FILE:-review.md}"

escalate=false
reason=""

if [[ "$DEPTH" != "light" ]]; then
  echo "escalate=false" >> "$GITHUB_OUTPUT"
  echo "reason=not-light-tier" >> "$GITHUB_OUTPUT"
  echo "skipping escalation check: depth=$DEPTH is not light"
  exit 0
fi

if [[ -n "${EXEC_FILE:-}" && -f "$EXEC_FILE" ]]; then
  subtype="$(jq -r '.subtype // ""' "$EXEC_FILE" 2>/dev/null || true)"
  is_error="$(jq -r '.is_error // false' "$EXEC_FILE" 2>/dev/null || true)"
  if [[ "$subtype" == "error_max_turns" ]]; then
    escalate=true
    reason="hit max-turns budget at light tier"
  elif [[ "$is_error" == "true" ]]; then
    escalate=true
    reason="execution errored at light tier"
  fi
fi

if [[ "$escalate" == false && -s "$REVIEW_FILE" ]]; then
  body="$(cat "$REVIEW_FILE")"
  # Missing release notes, hedged findings, and Unknowns bullets all escalate.
  if echo "$body" | grep -qiE 'could not (verify|confirm|determine|be retrieved)|not (publicly available|found)|unable to (verify|confirm|determine)|no upstream release notes published'; then
    escalate=true
    reason="review body hedges on findings it could not verify"
  elif printf '%s\n' "$body" | awk '/^\*\*Unknowns\*\*/{s=1;next} /^(\*\*|---)/{s=0} s&&/^[[:space:]]*[-*][[:space:]]/&&!/[Nn]one|[Nn]\/[Aa]/{f=1} END{exit !f}'; then
    escalate=true
    reason="review lists Unknowns at light tier"
  fi
fi

echo "escalate=$escalate" >> "$GITHUB_OUTPUT"
echo "reason=${reason:-none}" >> "$GITHUB_OUTPUT"
echo "escalate=$escalate reason=${reason:-none}"
