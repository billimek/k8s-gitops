#!/usr/bin/env bash
# Classify a gated Renovate PR: pick a model tier (as before) and emit a
# deterministic "must_check" list the reviewer is required to address. The
# must_check list is the "address EACH of these" injection technique borrowed
# from misospace/pr-reviewer-action's classifier.py.
#
# Required env:
#   PR_TITLE  - the PR title
#
# Optional env:
#   DIFF_FILE - path to the PR diff (default: pr.diff, written by review-fingerprint.sh)
#
# Outputs (GITHUB_OUTPUT):
#   model, depth, max_turns  - unchanged tier logic
#   must_check_file          - path to a file containing the "## Required checks" block
#                               (multiline output is passed as a file, not a GITHUB_OUTPUT
#                               heredoc, so it can be `cat`-ed straight into pr-context.md)

set -euo pipefail

: "${PR_TITLE:?PR_TITLE required}"
DIFF_FILE="${DIFF_FILE:-pr.diff}"
MUST_CHECK_FILE="must-check.md"

title="$PR_TITLE"

# ---------------------------------------------------------------------------
# Tier routing (unchanged from the original "Select model tier" step)
# ---------------------------------------------------------------------------
is_patch=false
[[ "$title" == fix\(container\):* ]] && is_patch=true
is_blast_radius=false
echo "$title" | grep -qiE 'envoy|cilium|rook|ceph|volsync|cert-manager|external-secrets' && is_blast_radius=true
is_breaking=false
echo "$title" | grep -qE 'group|!:' && is_breaking=true

if [[ "$is_breaking" == true ]] || { [[ "$is_blast_radius" == true ]] && [[ "$is_patch" == false ]]; }; then
  model=sonnet; depth=deep; max_turns=40
elif [[ "$is_blast_radius" == true ]]; then
  model=sonnet; depth=full; max_turns=25
elif [[ "$is_patch" == true ]]; then
  model=haiku; depth=light; max_turns=25
else
  model=sonnet; depth=full; max_turns=25
fi

echo "model=$model" >> "$GITHUB_OUTPUT"
echo "depth=$depth" >> "$GITHUB_OUTPUT"
echo "max_turns=$max_turns" >> "$GITHUB_OUTPUT"

# ---------------------------------------------------------------------------
# must_check: deterministic rules over the diff paths + title
# ---------------------------------------------------------------------------
changed_paths="$(grep -E '^\+\+\+ b/' "$DIFF_FILE" 2>/dev/null | sed 's#^+++ b/##' || true)"

# checks[] holds the human-readable line injected into the prompt; keywords[]
# holds a matching short keyword used later (finalize-review.sh) to
# keyword-match whether the posted review actually addressed each item.
checks=()
keywords=()

if echo "$changed_paths" | grep -qE 'HelmRelease|helmrelease'; then
  chart="$(echo "$changed_paths" | grep -oE '[^/]+/[^/]+\.ya?ml$' | head -1 || true)"
  checks+=("values schema compatibility for the chart change in ${chart:-the changed HelmRelease}")
  keywords+=("schema")
fi

# Extract old/new versions from a Renovate title like "( 1.2.3 -> 2.0.0 )" and
# compare majors.
from_ver="$(echo "$title" | grep -oE '\( ?v?[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
to_ver="$(echo "$title" | grep -oE '[→>-] ?v?[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -1 || true)"
if [[ -n "$from_ver" && -n "$to_ver" ]]; then
  from_major="${from_ver%%.*}"
  to_major="${to_ver%%.*}"
  if [[ "$from_major" != "$to_major" ]]; then
    checks+=("breaking changes in every intermediate release between v${from_ver} and v${to_ver} (major version change)")
    keywords+=("breaking")
  fi
fi

if echo "$changed_paths" | grep -qiE 'rook-ceph|cert-manager|external-secrets|cilium|envoy'; then
  checks+=("CRD version compatibility and any required migration steps for the changed component")
  keywords+=("CRD")
fi

if echo "$changed_paths" | grep -qE '^kubernetes/kube-system/kopiur/'; then
  checks+=("backup schedule and retention semantics are unchanged by this bump")
  keywords+=("backup")
fi

if echo "$title" | grep -qi 'group'; then
  checks+=("each component bundled in this group PR is covered separately, not just the group as a whole")
  keywords+=("group")
fi

{
  if [[ "${#checks[@]}" -gt 0 ]]; then
    echo "## Required checks"
    echo
    echo "The following items were derived deterministically from the diff and PR title."
    echo "Address EACH one explicitly in your review. If one cannot be verified, say so"
    echo "under an explicit **Unknowns** heading rather than omitting it."
    echo
    for c in "${checks[@]}"; do
      echo "- $c"
    done
  fi
} > "$MUST_CHECK_FILE"

# "keyword|description" pairs consumed by finalize-review.sh for warn-mode
# validation; not shown to the model.
: > must-check-pairs.txt
for i in "${!checks[@]}"; do
  printf '%s|%s\n' "${keywords[$i]}" "${checks[$i]}" >> must-check-pairs.txt
done

echo "must_check_file=$MUST_CHECK_FILE" >> "$GITHUB_OUTPUT"
echo "must_check_pairs_file=must-check-pairs.txt" >> "$GITHUB_OUTPUT"
echo "must_check_count=${#checks[@]}" >> "$GITHUB_OUTPUT"
echo "model=$model depth=$depth max_turns=$max_turns must_check_count=${#checks[@]}"
