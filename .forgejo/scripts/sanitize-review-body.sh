#!/usr/bin/env bash
# Rewrite github.com URLs to redirect.github.com so upstream PRs/issues/commits
# linked from the review body don't get spammed with "mentioned in" cross-refs.
# Also neutralizes bare "#NNN" references, which GitHub auto-links against
# THIS repo regardless of which upstream project the model meant -- wrapping
# them in a code span (`#NNN`) stops the auto-link while staying readable.
# Reads the review body on stdin, writes the sanitized body to stdout.
#
# This replaces the prompt paragraphs that used to ask the model to do this
# rewrite itself (unreliable) -- see misospace/pr-reviewer-action's
# scripts/sanitize_review_markdown.py for the upstream precedent.
#
# NOTE: this runs *after* the review is already posted, so it can't retract
# the wrong-repo cross-reference notification GitHub fires at post time -- it
# only fixes what future readers of the review body see. The prompt rule
# telling the model to avoid bare #NNN in the first place remains the primary
# defense; this is a deterministic backstop for when it doesn't.
#
# Optional env:
#   OWN_REPO - owner/repo of the reviewed repo; self-links are left alone since
#              github.com/OWN_REPO/... referencing THIS repo's own PRs/issues
#              should keep normal auto-linking behavior.

set -euo pipefail

OWN_REPO="${OWN_REPO:-}"

# NOTE: the python script is passed via `-c "$(...)"` command substitution,
# not a heredoc on python3's own stdin -- a heredoc there would consume fd 0
# and shadow the piped review body before sys.stdin.read() ever sees it.
python3 -c "$(cat <<'PY'
import re
import sys

own_repo = sys.argv[1]
body = sys.stdin.read()

url_pattern = re.compile(r'https://github\.com/([^\s")\]]+)')

def repl(m):
    rest = m.group(1)
    if own_repo and rest.startswith(own_repo.rstrip('/') + '/'):
        return m.group(0)
    return 'https://redirect.github.com/' + rest

body = url_pattern.sub(repl, body)

# Bare "#NNN" (not "org/repo#NNN", not inside a URL, not already in a code
# span) auto-links to THIS repo on GitHub regardless of which project the
# model meant. A char class covering word chars, "/", and "`" immediately
# before the "#" is enough to skip all three: word-char/slash catches
# "repo#123" and URL path segments like ".../pull/123#issuecomment-456"
# (digit before "#"); backtick catches an already-escaped reference.
bare_ref_pattern = re.compile(r'(?<![\w/`])#(\d+)')
body = bare_ref_pattern.sub(r'`#\1`', body)

sys.stdout.write(body)
PY
)" "$OWN_REPO"
