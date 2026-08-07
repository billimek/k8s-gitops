#!/usr/bin/env bash
# Count actionable advisory findings in a claude/renovate-review body.
#
# The reviewer emits two non-blocking sections alongside an APPROVED verdict:
# `**New features worth adopting**:` and `**Known issues**:`. Those are meant
# to be seen by a human before merging, but with automerge now covering a
# wide package set, an approved PR carrying an advisory note merges itself
# overnight and the note lands in a merged PR nobody revisits. This script
# lets the "Publish review status" step in renovate-review.yaml turn a
# non-empty advisory section into a blocking commit status.
#
# Reads the review body on stdin, prints a single integer (count of
# actionable findings) to stdout. No gh calls, no env deps.
#
# The reviewer routinely documents a negative search result as a bullet
# (e.g. "- Searched upstream issues for v1.21.1 -- no open regressions
# reported.") -- that is diligence, not a finding, so it must not block.
# NEGATIVE_RE matches those so they're excluded from the count.

set -euo pipefail

NEGATIVE_RE='none found|none reported|none identified|no results|no reported|no regressions|no bug reports|no issues found|no matching|no known issues|no open [^.]{0,60}(issues|regressions|bugs)|^none\b|^n/a\b'

body="$(cat)"

count=0
in_section=0

while IFS= read -r line; do
  if [[ "$line" =~ ^\*\*(New\ features\ worth\ adopting|Known\ issues) ]]; then
    in_section=1
    # Inline content on the header line itself, e.g. "**Known issues**: None found."
    rest="$(printf '%s' "$line" | sed -E 's/^\*\*[^*]*\*\*:?[[:space:]]*//')"
    if [[ -n "$rest" ]] && ! echo "$rest" | grep -qiE "$NEGATIVE_RE"; then
      count=$((count + 1))
    fi
    continue
  fi

  if [[ "$in_section" == 1 ]]; then
    if [[ "$line" =~ ^(\*\*|---) ]]; then
      in_section=0
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*[-*][[:space:]] ]]; then
      item="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*[-*][[:space:]]*//')"
      if ! echo "$item" | grep -qiE "$NEGATIVE_RE"; then
        count=$((count + 1))
      fi
    fi
  fi
done <<< "$body"

echo "$count"
