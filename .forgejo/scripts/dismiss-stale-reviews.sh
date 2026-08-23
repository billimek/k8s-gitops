#!/usr/bin/env bash
# Dismiss any live harness review on this PR so the one about to be posted is
# the only verdict a status lookup or branch-protection check can see.
#
# The .github/ version inlines this in the workflow as `gh api -X PUT
# .../dismissals`. Forgejo's equivalent is a POST, and dismissal there sets a
# `dismissed` flag rather than rewriting the review state, so the filter that
# picks reviews to dismiss has to skip already-dismissed ones itself (see
# FJ_OUR_REVIEWS_JQ) or every run re-dismisses the whole history.
#
# Required env:
#   REPO, PR, FORGEJO_TOKEN, FORGEJO_API
#
# Optional env:
#   DISMISS_MESSAGE - defaults to "Superseded by updated review"

set -euo pipefail

: "${PR:?PR required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.forgejo/scripts/forgejo-api.sh
source "$SCRIPT_DIR/forgejo-api.sh"

MESSAGE="${DISMISS_MESSAGE:-Superseded by updated review}"

ids="$(fj_get_all "/pulls/${PR}/reviews" \
  | jq -r "${FJ_OUR_REVIEWS_JQ} | .[].id")"

if [[ -z "$ids" ]]; then
  echo "no live harness reviews to dismiss"
  exit 0
fi

jq -n --arg message "$MESSAGE" '{message: $message, priors: false}' > dismissal.json

for id in $ids; do
  echo "dismissing review $id"
  fj_post_json "/pulls/${PR}/reviews/${id}/dismissals" dismissal.json > /dev/null
done
