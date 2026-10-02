#!/usr/bin/env bash
# Pre-post transform: take the reviewer's raw output (review.md + verdict.txt)
# and produce the exact body and event that get POSTed, in one shot.
#
# On GitHub this work is split across two after-the-fact steps --
# enforce-advisory-comment.sh dismisses a wrongly-APPROVED review and reposts
# it, and finalize-review.sh PUTs an edited body back onto the posted review.
# Neither is possible here: Forgejo has no "edit a submitted review" endpoint
# at all (POST /pulls/{i}/reviews/{id} submits a *pending* review, it does not
# update a submitted one), so anything that has to be in the final body has to
# be in it before the first POST. That constraint is what turns these into a
# transform rather than a repair pass, and it also removes the double-submit
# and dismiss-and-repost failure modes the GitHub version has to police.
#
# Reads:
#   review.md   - the reviewer's body
#   verdict.txt - APPROVED | REQUEST_CHANGES | COMMENT
#
# Writes:
#   review-body.md - the final body to POST
#
# Required env:
#   FP   - fingerprint from review-fingerprint.sh
#   REPO - owner/repo (passed to the sanitizer so self-links are left alone)
#
# Optional env:
#   REVIEW_FILE, VERDICT_FILE, MUST_CHECK_PAIRS_FILE
#   HEAD_SHA, SERVER_URL - when both are set, `path:LINE` code spans link to
#                          that line at the head commit and a footer is added
#   REVIEW_MODEL         - model name shown in the footer
#
# Outputs (GITHUB_OUTPUT):
#   verdict, findings, unaddressed_count

set -euo pipefail

: "${FP:?FP required}"
: "${REPO:?REPO required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REVIEW_FILE="${REVIEW_FILE:-review.md}"
VERDICT_FILE="${VERDICT_FILE:-verdict.txt}"
PAIRS_FILE="${MUST_CHECK_PAIRS_FILE:-must-check-pairs.txt}"

[[ -s "$REVIEW_FILE" ]] || { echo "$REVIEW_FILE missing or empty" >&2; exit 1; }

verdict="$(tr -d '[:space:]' < "$VERDICT_FILE")"
case "$verdict" in
  APPROVED|REQUEST_CHANGES|COMMENT) ;;
  *)
    # Forgejo maps an unrecognized `event` to a PENDING review rather than
    # rejecting it, so a typo here would post a draft nobody ever sees and
    # leave the merge gate unsatisfied with no visible error. Fail loudly.
    echo "invalid verdict '${verdict}' (want APPROVED|REQUEST_CHANGES|COMMENT)" >&2
    exit 1
    ;;
esac

body="$(cat "$REVIEW_FILE")"

# 1. Sanitize links and bare "#NNN" upstream references. Unlike the GitHub
# version this runs before the post, so it actually prevents the wrong-repo
# auto-link instead of only fixing what later readers see.
body="$(printf '%s' "$body" | OWN_REPO="$REPO" "$SCRIPT_DIR/sanitize-review-body.sh")"

# 2. Advisory-finding backstop. A verdict of APPROVED on a body carrying
# actionable "New features worth adopting" / "Known issues" bullets is
# downgraded to COMMENT, which deliberately leaves branch protection's
# required-approving-review unsatisfied so a human looks before it merges.
findings="$(printf '%s' "$body" | bash "$SCRIPT_DIR/detect-advisory-findings.sh")"
if [[ "$verdict" == "APPROVED" && "$findings" -gt 0 ]]; then
  echo "downgrading APPROVED -> COMMENT: $findings advisory finding(s)"
  verdict="COMMENT"
fi

# 2a. Link `path/to/file:LINE` code spans to that line at the head commit.
if [[ -n "${HEAD_SHA:-}" && -n "${SERVER_URL:-}" ]]; then
  src_base="${SERVER_URL}/${REPO}/src/commit/${HEAD_SHA}"
  body="$(printf '%s\n' "$body" | sed -E 's#`([^`[:space:]:]+/[^`[:space:]:]+\.[A-Za-z0-9]+):([0-9]+)`#[`\1:\2`]('"$src_base"'/\1\#L\2)#g')"
fi

# 2b. Collapse the low-signal sections into <details> blocks.
body="$(printf '%s\n' "$body" | awk '
  function close_block() { if (open) { print "\n</details>\n"; open = 0 } }
  /^\*\*(Not applicable to this repo|Sources consulted)\*\*:?[[:space:]]*$/ {
    close_block()
    t = $0; gsub(/^\*\*|\*\*:?[[:space:]]*$/, "", t)
    print "<details>\n<summary>" t "</summary>\n"
    open = 1
    next
  }
  open && /^(\*\*|---|<!--|>)/ { close_block() }
  { print }
  END { close_block() }
')"

# 3. Warn-mode required-check validation
unaddressed=()
if [[ -f "$PAIRS_FILE" ]]; then
  while IFS='|' read -r keyword description; do
    [[ -z "$keyword" ]] && continue
    if ! printf '%s' "$body" | grep -qi "$keyword"; then
      unaddressed+=("$description")
    fi
  done < "$PAIRS_FILE"
fi

if [[ "${#unaddressed[@]}" -gt 0 ]]; then
  body="${body}

---
> [!WARNING]
> **Unaddressed required checks (auto-detected, warn mode)**
> The following deterministically-derived checks were not clearly addressed in this review:
$(for u in "${unaddressed[@]}"; do echo ">- $u"; done)"
fi

# 3b. Footer naming the commit and model that produced the review.
if [[ -n "${HEAD_SHA:-}" && -n "${SERVER_URL:-}" ]]; then
  body="${body}

<sub>Reviewed [\`${HEAD_SHA:0:7}\`](${SERVER_URL}/${REPO}/commit/${HEAD_SHA}) with ${REVIEW_MODEL:-unknown}.</sub>"
fi

# 4. Stamp the fingerprint marker so an identical re-push skips the model.
body="${body}

<!-- rr-fp:${FP} -->"

printf '%s\n' "$body" > review-body.md

{
  echo "verdict=$verdict"
  echo "findings=$findings"
  echo "unaddressed_count=${#unaddressed[@]}"
} >> "$GITHUB_OUTPUT"

echo "verdict=$verdict findings=$findings unaddressed=${#unaddressed[@]} fp=$FP"
