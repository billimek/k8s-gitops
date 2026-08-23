#!/usr/bin/env bash
# Shared Forgejo /api/v1 helpers for the renovate-review harness. Sourced, not
# executed. Replaces the `gh api` calls the .github/ version makes -- `gh`
# cannot be used here at all, because Forgejo Actions points GITHUB_API_URL at
# the Forgejo instance itself (see b5f5cd6, 2e92012), so `gh` would silently
# speak GitHub's REST dialect to a Gitea-shaped API.
#
# Required env:
#   FORGEJO_TOKEN - the per-job Actions token (secrets.GITHUB_TOKEN)
#   FORGEJO_API   - API root, e.g. https://git.example.com/api/v1
#   REPO          - owner/repo

: "${FORGEJO_TOKEN:?FORGEJO_TOKEN required}"
: "${FORGEJO_API:?FORGEJO_API required}"
: "${REPO:?REPO required}"

# The per-job Actions token authenticates as Forgejo's built-in actions user
# (id -2), NOT as the user who triggered the run -- verified against the PR
# timeline, where labeler-applied labels are attributed to "forgejo-actions"
# while everything renovate did is attributed to "renovate". Two consequences:
# reviews this harness posts are authored by that account (so it replaces the
# claude[bot]/github-actions[bot] filters from the .github/ version), and the
# API's "you cannot approve your own pull request" check never trips on a
# Renovate PR.
FJ_REVIEWER_LOGIN="${FJ_REVIEWER_LOGIN:-forgejo-actions}"
export FJ_REVIEWER_LOGIN

# Reviews we own and that still count: Forgejo does not rewrite a dismissed
# review's state to DISMISSED the way GitHub does -- it keeps APPROVED and
# flips a separate `dismissed` boolean -- so every lookup must filter on it or
# a dismissed verdict keeps being read back as live.
# shellcheck disable=SC2089,SC2090  # a jq program, interpolated into another jq program -- never re-split as shell words
FJ_OUR_REVIEWS_JQ='[.[] | select(.user.login == env.FJ_REVIEWER_LOGIN
  and (.dismissed | not)
  and (.state == "APPROVED" or .state == "REQUEST_CHANGES" or .state == "COMMENT"))]'
# shellcheck disable=SC2090
export FJ_OUR_REVIEWS_JQ

# fj_curl METHOD PATH [extra curl args...]
# PATH is relative to /repos/{owner}/{repo}.
fj_curl() {
  local method="$1" path="$2"
  shift 2
  curl -sSL --fail-with-body -X "$method" \
    -H "Authorization: token ${FORGEJO_TOKEN}" \
    -H "Accept: application/json" \
    "$@" \
    "${FORGEJO_API}/repos/${REPO}${path}"
}

# fj_post_json PATH FILE - POST FILE as the JSON request body.
fj_post_json() {
  fj_curl POST "$1" -H "Content-Type: application/json" --data-binary "@$2"
}

# fj_patch_json PATH FILE - PATCH FILE as the JSON request body.
fj_patch_json() {
  fj_curl PATCH "$1" -H "Content-Type: application/json" --data-binary "@$2"
}

# fj_get_raw PATH - GET a non-JSON response (e.g. a .diff) to stdout.
fj_get_raw() {
  curl -sSL --fail-with-body \
    -H "Authorization: token ${FORGEJO_TOKEN}" \
    "${FORGEJO_API}/repos/${REPO}${1}"
}

# fj_get_all PATH - GET every page of a list endpoint, concatenated into one
# JSON array on stdout. Forgejo paginates with page/limit and, unlike GitHub,
# sends no Link header to follow, so the loop stops on a short page instead.
fj_get_all() {
  local path="$1" page=1 limit=50 sep="?" acc="[]" chunk n
  [[ "$path" == *\?* ]] && sep="&"
  while :; do
    chunk="$(fj_curl GET "${path}${sep}page=${page}&limit=${limit}")"
    # Callers include a continue-on-error usage reporter running without -e, so
    # a failed or non-array page must end the loop rather than corrupt acc.
    n="$(printf '%s' "$chunk" | jq 'if type == "array" then length else -1 end' 2>/dev/null || echo -1)"
    [[ "$n" -lt 0 ]] && break
    acc="$(jq -s 'add' <(printf '%s' "$acc") <(printf '%s' "$chunk"))"
    [[ "$n" -lt "$limit" ]] && break
    page=$((page + 1))
    # Sanity stop; no list this harness reads should approach 1000 entries.
    [[ "$page" -gt 20 ]] && break
  done
  printf '%s' "$acc"
}
