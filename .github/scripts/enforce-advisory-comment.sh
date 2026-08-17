#!/usr/bin/env bash
# Deterministic backstop for the review-state merge gate.
#
# The reviewer prompt says: submit --comment (not --approve) when the review
# body carries a non-empty "New features worth adopting" / "Known issues"
# section but no breaking changes. In practice the model doesn't always
# follow that rule -- it sometimes approves anyway, which silently satisfies
# branch protection's required-approving-review count instead of holding the
# PR for a human. detect-advisory-findings.sh already does the deterministic
# classification (it used to drive a status-check failure before the gate
# moved to review state); reuse it here to catch and correct the mismatch:
# dismiss the wrongly-APPROVED review and resubmit the identical body as a
# COMMENT review instead.
#
# Required env:
#   REPO, PR, GH_TOKEN

set -euo pipefail

: "${REPO:?REPO required}"
: "${PR:?PR required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

review_json="$(gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
  --jq '[.[] | select(.user.login == "claude[bot]" or .user.login == "github-actions[bot]")] | last // {}' \
  2>/dev/null || echo '{}')"

review_id="$(printf '%s' "$review_json" | jq -r '.id // empty')"
state="$(printf '%s' "$review_json" | jq -r '.state // ""')"
body="$(printf '%s' "$review_json" | jq -r '.body // ""')"

if [[ -z "$review_id" || "$state" != "APPROVED" ]]; then
  echo "no APPROVED review to check -- nothing to do (state=${state:-none})"
  exit 0
fi

findings="$(printf '%s' "$body" | bash "$SCRIPT_DIR/detect-advisory-findings.sh")"

if [[ "$findings" -eq 0 ]]; then
  echo "APPROVED review has 0 advisory findings -- correct, nothing to do"
  exit 0
fi

echo "APPROVED review has $findings advisory finding(s) -- retargeting review $review_id to COMMENT"

gh api -X PUT "repos/$REPO/pulls/$PR/reviews/$review_id/dismissals" \
  -f message="Retargeted to COMMENT: approved review carries advisory finding(s) that need a human before merge (see .github/scripts/enforce-advisory-comment.sh)" > /dev/null

jq -n --arg body "$body" '{event: "COMMENT", body: $body}' \
  | gh api -X POST "repos/$REPO/pulls/$PR/reviews" --input - > /dev/null

echo "resubmitted as COMMENT"
