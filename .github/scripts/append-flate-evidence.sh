#!/usr/bin/env bash
# Render the cluster-impact diff with flate and append it to pr-context.md as
# reviewer evidence. Used by both the primary review (full/deep depth) and,
# separately, the escalated re-review (which also claims "full depth" and
# needs the same evidence -- see renovate-review.yaml).
#
# Distinguishes three outcomes instead of collapsing "render failed" and
# "render succeeded with no changes" into the same empty-file signal:
#   - rendered diff present
#   - render succeeded, no changes (real no-op)
#   - render failed (non-zero exit) -- reported as a blocker, not a no-op
#
# Required env:
#   FLATE_PATH - path to flate config, e.g. setup/flux/cluster
#
# Appends to: pr-context.md (repo root, must already exist)

set -euo pipefail

: "${FLATE_PATH:?FLATE_PATH required}"

rc=0
# flate intermittently SIGSEGVs (exit 139) in the Forgejo runner's job pods --
# never on GitHub-hosted runners, cause unknown despite repeated investigation
# (see git log for kubernetes/default/forgejo/runner.yaml and
# .forgejo/workflows/flate.yaml). Retrying is a deliberate mitigation, not a
# fix: a genuine render failure exits non-139 and is not retried.
for attempt in 1 2 3; do
  flate diff all \
    --allow-missing-secrets \
    --skip-kinds ValidatingWebhookConfiguration \
    --skip-kinds MutatingWebhookConfiguration \
    -o diff > flate.diff 2> flate.err || rc=$?
  [ "$rc" -eq 139 ] || break
  echo "flate segfaulted (attempt $attempt/3), retrying" >&2
  rc=0
  sleep 2
done

{
  printf '\n---\n## Rendered manifest diff (flate)\n\n'
  printf 'This is the actual cluster-impact diff after Helm/Kustomize rendering -- treat it as\n'
  printf 'authoritative over the raw git diff above.\n\n'
  if [[ "$rc" -ne 0 ]]; then
    printf '**RENDER FAILED (exit %s) -- treat as a blocker, not a no-op.** The manifests may\n' "$rc"
    printf 'not apply cleanly; do not read this as "no rendered manifest changes".\n\n'
    printf '```\n'
    tail -c 4000 flate.err
    printf '\n```\n'
  elif [ -s flate.diff ]; then
    LIMIT=40000
    if [ "$(wc -c < flate.diff)" -gt "$LIMIT" ]; then
      printf '```diff\n'
      head -c "$LIMIT" flate.diff
      printf '\n```\n\n(truncated at %s bytes)\n' "$LIMIT"
    else
      printf '```diff\n'
      cat flate.diff
      printf '\n```\n'
    fi
  else
    printf '(render succeeded; no rendered manifest changes -- a genuine no-op)\n'
  fi
} >> pr-context.md

echo "flate render: rc=$rc diff_bytes=$(wc -c < flate.diff 2>/dev/null || echo 0)"
