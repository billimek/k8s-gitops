#!/usr/bin/env bash
# Publish the claude/renovate-review commit status.
#
# This status reports whether the automation itself completed. Actual merge
# gating happens via branch protection's required-approving-review rule reading
# the review state the harness submitted (APPROVED / REQUEST_CHANGES /
# COMMENT), not via this status. A COMMENT verdict deliberately withholds
# approval so the PR waits for a human, without failing this check.
#
# Unlike the .github/ version this does not retry the review lookup: there the
# review is posted asynchronously by the model and may not be visible yet, but
# here a deterministic step posted it earlier in the same job, so one read is
# authoritative.
#
# Required env:
#   REPO, PR, SHA, FORGEJO_TOKEN, FORGEJO_API
#   GATE_OUTCOME - outcome of the classify step
#   IS_RENOVATE, GATED, SKIP
#
# Optional env:
#   RUN_URL

set -euo pipefail

: "${PR:?PR required}"
: "${SHA:?SHA required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.forgejo/scripts/forgejo-api.sh
source "$SCRIPT_DIR/forgejo-api.sh"

context="claude/renovate-review"

if [[ "${GATE_OUTCOME:-}" != "success" ]]; then
  # Classify PR itself failed (or the job died before it ran) -- IS_RENOVATE is
  # unset in that case, which would otherwise fall through to the "not a
  # Renovate PR" branch below and post a green status for a PR whose review
  # never ran. Fail closed instead, matching every other failure mode here.
  state="failure"
  desc="Classification step failed - review did not run"
elif [[ "${IS_RENOVATE:-}" != "true" ]]; then
  state="success"
  desc="Not a Renovate PR - skipped"
elif [[ "${GATED:-}" != "true" ]]; then
  state="success"
  desc="Ungated update type (digest/forgejo-action/grafana-dashboard) - auto-approved"
else
  suffix=""
  [[ "${SKIP:-}" == "true" ]] && suffix=" (cached, diff unchanged)"

  review_state="$(fj_get_all "/pulls/${PR}/reviews" \
    | jq -r "${FJ_OUR_REVIEWS_JQ} | last | .state // \"\"" 2>/dev/null || echo "")"

  case "$review_state" in
    APPROVED)
      state="success"
      desc="Claude approved - safe to merge${suffix}"
      ;;
    REQUEST_CHANGES)
      state="success"
      desc="Claude requested changes - manual review required${suffix}"
      ;;
    COMMENT)
      state="success"
      desc="Claude flagged advisory findings - approval needed to merge${suffix}"
      ;;
    *)
      state="failure"
      desc="Claude review pending or errored"
      ;;
  esac
fi

echo "Posting commit status: context=$context state=$state desc=$desc"

jq -n \
  --arg state "$state" \
  --arg context "$context" \
  --arg description "$desc" \
  --arg target_url "${RUN_URL:-}" \
  '{state: $state, context: $context, description: $description, target_url: $target_url}' \
  > status.json

fj_post_json "/statuses/${SHA}" status.json > /dev/null
