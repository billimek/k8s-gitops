#!/usr/bin/env bash
# Rewrite github.com URLs to redirect.github.com so upstream PRs/issues/commits
# linked from the review body don't get spammed with "mentioned in" cross-refs.
# Reads the review body on stdin, writes the sanitized body to stdout.
#
# This replaces the prompt paragraphs that used to ask the model to do this
# rewrite itself (unreliable) -- see misospace/pr-reviewer-action's
# scripts/sanitize_review_markdown.py for the upstream precedent.
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

pattern = re.compile(r'https://github\.com/([^\s")\]]+)')

def repl(m):
    rest = m.group(1)
    if own_repo and rest.startswith(own_repo.rstrip('/') + '/'):
        return m.group(0)
    return 'https://redirect.github.com/' + rest

sys.stdout.write(pattern.sub(repl, body))
PY
)" "$OWN_REPO"
