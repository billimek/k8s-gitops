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
[[ "$title" == fix\(container\):* || "$title" == fix\(helm\):* ]] && is_patch=true
is_blast_radius=false
echo "$title" | grep -qiE 'envoy|cilium|rook|ceph|kopiur|cert-manager|external-secrets|talos|tuppr|cloudnative-pg|cnpg|postgres|victoria|home-assistant|silo' && is_blast_radius=true
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

# Files aren't named "helmrelease*" in this repo (app-template convention is
# <app>.yaml), so path matching never fires. Grep the changed files themselves
# (at PR head, already checked out) for the resource kind instead.
#
# Most apps consume the shared app-template chart (chartRef -> name:
# app-template); a Renovate PR against one of those only bumps a container
# image tag in `values`, not the chart itself, so the chart's values schema
# is unaffected -- skip those. Apps that ship their own chart (kopiur,
# victoria-metrics-k8s-stack, ...) have a chartRef that does NOT point at
# app-template, and a version/tag bump there IS a chart change.
helmrelease_file=""
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  if [[ -f "$p" ]] && grep -qE '^kind: ?HelmRelease' "$p" && ! grep -q 'name: app-template' "$p"; then
    helmrelease_file="$p"
    break
  fi
done <<< "$changed_paths"

# Extract old/new versions from a Renovate title like "( 1.2.3 -> 2.0.0 )" and
# compare majors.
from_ver="$(echo "$title" | grep -oE '\( ?v?[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
to_ver="$(echo "$title" | grep -oE '[→>-] ?v?[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -1 || true)"
# Patch bumps (same major.minor) don't change a chart's values schema; skip the
# check there. Unparseable versions keep it.
patch_only=false
if [[ -n "$from_ver" && -n "$to_ver" && "${from_ver%.*}" == "${to_ver%.*}" ]]; then
  patch_only=true
fi

if [[ -n "$helmrelease_file" && "$patch_only" != "true" ]]; then
  checks+=("values schema compatibility for the chart change in ${helmrelease_file}")
  keywords+=("schema")
fi

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

if echo "$changed_paths" | grep -q '^kubernetes/default/silo/'; then
  old_build="$(grep -oE '^-[[:space:]]+tag: build-[0-9]+' "$DIFF_FILE" | grep -oE '[0-9]+$' | head -1 || true)"
  new_build="$(grep -oE '^\+[[:space:]]+tag: build-[0-9]+' "$DIFF_FILE" | grep -oE '[0-9]+$' | head -1 || true)"
  if [[ -n "$old_build" && -n "$new_build" ]]; then
    checks+=("silo build-${old_build} to build-${new_build}: every new or changed required env var, config key, migration and upgrade note in the Upstream evidence section is satisfied by kubernetes/default/silo/silo.yaml for BOTH the silo and silo-transcode controllers")
    keywords+=("env")
  fi
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

# Upstream evidence for silo build bumps: image revision labels are read from
# ghcr.io, then the upstream commit range, changed files, new env var reads and
# upgrade docs are appended to the must-check file.
if [[ -n "${old_build:-}" && -n "${new_build:-}" ]]; then
  silo_upstream_evidence() {
    local repo="silo-server/silo-server" gh_repo="Silo-Server/silo-server" tok
    tok="$(curl -fsS "https://ghcr.io/token?scope=repository:${repo}:pull" | jq -r .token)"
    revision_of() {
      local idx amd cfg
      idx="$(curl -fsS -H "Authorization: Bearer $tok" -H 'Accept: application/vnd.oci.image.index.v1+json' "https://ghcr.io/v2/${repo}/manifests/$1")"
      amd="$(echo "$idx" | jq -r '.manifests[] | select(.platform.architecture=="amd64") | .digest' | head -1)"
      cfg="$(curl -fsS -H "Authorization: Bearer $tok" -H 'Accept: application/vnd.oci.image.manifest.v1+json' "https://ghcr.io/v2/${repo}/manifests/${amd}" | jq -r .config.digest)"
      curl -fsSL -H "Authorization: Bearer $tok" "https://ghcr.io/v2/${repo}/blobs/${cfg}" | jq -r '.config.Labels["org.opencontainers.image.revision"]'
    }
    local old_rev new_rev cmp
    old_rev="$(revision_of "build-${old_build}")"
    new_rev="$(revision_of "build-${new_build}")"
    cmp="$(curl -fsS ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} "https://api.github.com/repos/${gh_repo}/compare/${old_rev}...${new_rev}")"
    echo
    echo "## Upstream evidence (silo build-${old_build} -> build-${new_build})"
    echo
    echo "Image revisions: ${old_rev} -> ${new_rev}"
    echo "Compare: https://github.com/${gh_repo}/compare/${old_rev}...${new_rev}"
    echo "Commits in range: $(echo "$cmp" | jq -r '.total_commits') (build numbers are not all tagged, so the range can span several builds)"
    echo
    echo "### Commit subjects (up to 150)"
    echo "$cmp" | jq -r '.commits[:150][] | "- " + (.commit.message | split("\n")[0])'
    echo
    echo "### Changed files (up to 300)"
    echo "$cmp" | jq -r '.files[:300][] | "- " + .filename'
    echo
    echo "### Env var names added in code or docs (added lines)"
    echo "$cmp" | jq -r '.files[] | select((.filename | endswith(".go")) or (.filename | startswith("docs/"))) | .patch // empty' \
      | grep -E '^\+' | grep -oE '\b(SILO_[A-Z0-9_]+|(NODE|CORE|REDIS|DATABASE|JF|MODE)_[A-Z0-9_]+|MODE)\b' | sort -u | sed 's/^/- /' || true
    echo
    echo "### Upgrade guide patches (docs/update-*, docs/upgrad*, docs/migrat*; truncated)"
    echo "$cmp" | jq -r '.files[] | select(.filename | test("^docs/(update|upgrad|migrat)")) | "#### " + .filename + "\n" + ((.patch // "") | split("\n")[:150] | join("\n"))' | head -300
  }
  if ! silo_upstream_evidence >> "$MUST_CHECK_FILE" 2>silo-evidence.err; then
    {
      echo
      echo "## Upstream evidence (silo build-${old_build} -> build-${new_build})"
      echo
      echo "Upstream evidence could not be fetched. Research the upstream commit range"
      echo "yourself with gh against Silo-Server/silo-server and list any gap under **Unknowns**."
    } >> "$MUST_CHECK_FILE"
    cat silo-evidence.err >&2 || true
  fi
fi

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
