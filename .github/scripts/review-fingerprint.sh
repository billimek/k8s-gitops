#!/usr/bin/env bash
# Compute a stable fingerprint for a Renovate PR's effective diff + review config,
# then check whether a prior claude[bot]/github-actions[bot] review already covers
# that exact fingerprint. If so, the model call can be skipped and the prior
# verdict re-published as-is.
#
# Writes the PR diff to pr.diff so downstream steps (Gather PR evidence, flate
# render) reuse it instead of re-fetching.
#
# Required env:
#   REPO      - owner/repo
#   PR        - PR number
#   GH_TOKEN  - token with repo read access
#
# Outputs (GITHUB_OUTPUT):
#   fp    - the fingerprint string (patch-id-config-hash)
#   skip  - "true" if a prior review already covers this fingerprint

set -euo pipefail

: "${REPO:?REPO required}"
: "${PR:?PR required}"

MARKER_PREFIX="<!-- rr-fp:"

if ! gh pr diff "$PR" --repo "$REPO" > pr.diff 2>/dev/null; then
  : > pr.diff
fi

patch_id="$(git patch-id --stable < pr.diff 2>/dev/null | awk 'NR==1{print $1}' || true)"
if [[ -z "$patch_id" ]]; then
  patch_id="empty-diff"
fi

# Config hash: any edit to the workflow or its scripts invalidates cached
# fingerprints, so a prompt/routing/script change always forces a fresh review.
config_hash="$(cat .github/workflows/renovate-review.yaml .github/scripts/*.sh 2>/dev/null \
  | sha256sum | cut -c1-12)"

fp="${patch_id}-${config_hash}"

skip=false
review_state="$(gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
  --jq "[.[] | select((.user.login == \"claude[bot]\" or .user.login == \"github-actions[bot]\")
        and (.body // \"\" | contains(\"${MARKER_PREFIX}${fp} -->\"))
        and (.state == \"APPROVED\" or .state == \"CHANGES_REQUESTED\"))] | last | .state // \"\"" \
  2>/dev/null || echo "")"

if [[ -n "$review_state" ]]; then
  skip=true
fi

echo "fp=$fp" >> "$GITHUB_OUTPUT"
echo "skip=$skip" >> "$GITHUB_OUTPUT"
echo "fingerprint=$fp patch_id=$patch_id config_hash=$config_hash skip=$skip (prior_state=${review_state:-none})"
