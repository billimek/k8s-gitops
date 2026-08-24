#!/usr/bin/env bash
# POST the prepared review body to Forgejo as a single submitted review.
#
# Required env:
#   REPO, PR, FORGEJO_TOKEN, FORGEJO_API
#   VERDICT - APPROVED | REQUEST_CHANGES | COMMENT
#
# Optional env:
#   BODY_FILE - defaults to review-body.md
#   COMMIT_ID - PR head SHA, pinned so the review is not marked stale by a
#               push that lands mid-run

set -euo pipefail

: "${PR:?PR required}"
: "${VERDICT:?VERDICT required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.forgejo/scripts/forgejo-api.sh
source "$SCRIPT_DIR/forgejo-api.sh"

BODY_FILE="${BODY_FILE:-review-body.md}"
[[ -s "$BODY_FILE" ]] || { echo "$BODY_FILE missing or empty" >&2; exit 1; }

jq -n \
  --rawfile body "$BODY_FILE" \
  --arg event "$VERDICT" \
  --arg commit_id "${COMMIT_ID:-}" \
  '{body: $body, event: $event} + (if $commit_id == "" then {} else {commit_id: $commit_id} end)' \
  > review-request.json

posted="$(fj_post_json "/pulls/${PR}/reviews" review-request.json)"

echo "posted review $(printf '%s' "$posted" | jq -r '.id') state=$(printf '%s' "$posted" | jq -r '.state')"
