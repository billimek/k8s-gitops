#!/usr/bin/env bash
# Forgejo port of .github/scripts/review-fingerprint.sh.
#
# Compute a stable fingerprint for a Renovate PR's effective diff + review
# config, then check whether a prior harness review already covers that exact
# fingerprint. If so, the model call can be skipped and the prior verdict left
# standing as-is.
#
# Writes the PR diff to pr.diff so downstream steps (Gather PR evidence, flate
# render) reuse it instead of re-fetching.
#
# Required env:
#   REPO, PR, FORGEJO_TOKEN, FORGEJO_API
#
# Outputs (GITHUB_OUTPUT):
#   fp    - the fingerprint string (patch-id-config-hash)
#   skip  - "true" if a prior review already covers this fingerprint

set -euo pipefail

: "${PR:?PR required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.forgejo/scripts/forgejo-api.sh
source "$SCRIPT_DIR/forgejo-api.sh"

MARKER_PREFIX="<!-- rr-fp:"

if ! fj_get_raw "/pulls/${PR}.diff" > pr.diff 2>/dev/null; then
  : > pr.diff
fi

patch_id="$(git patch-id --stable < pr.diff 2>/dev/null | awk 'NR==1{print $1}' || true)"
if [[ -z "$patch_id" ]]; then
  patch_id="empty-diff"
fi

# Config hash: any edit to the workflow or its scripts invalidates cached
# fingerprints, so a prompt/routing/script change always forces a fresh review.
# The glob picks up the symlinked shared scripts too -- cat follows them, so an
# edit on the .github/ side invalidates Forgejo fingerprints as well.
config_hash="$(cat .forgejo/workflows/renovate-review.yaml .forgejo/scripts/*.sh 2>/dev/null \
  | sha256sum | cut -c1-12)"

fp="${patch_id}-${config_hash}"

skip=false
review_state="$(fj_get_all "/pulls/${PR}/reviews" \
  | FP_MARKER="${MARKER_PREFIX}${fp} -->" jq -r \
    "${FJ_OUR_REVIEWS_JQ} | [.[] | select((.body // \"\") | contains(env.FP_MARKER))] | last | .state // \"\"" \
  2>/dev/null || echo "")"

if [[ -n "$review_state" ]]; then
  skip=true
fi

echo "fp=$fp" >> "$GITHUB_OUTPUT"
echo "skip=$skip" >> "$GITHUB_OUTPUT"
echo "fingerprint=$fp patch_id=$patch_id config_hash=$config_hash skip=$skip (prior_state=${review_state:-none})"
