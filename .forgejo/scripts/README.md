# `.forgejo/scripts`

Supporting scripts for `.forgejo/workflows/renovate-review.yaml`.

`append-flate-evidence.sh`, `classify-renovate-pr.sh`, `detect-advisory-findings.sh`, and
`sanitize-review-body.sh` were symlinks into `.github/scripts/` while the GitHub and Forgejo
review gates ran in parallel; now that `.github/` is retired they are real copies here.

Ported (Forgejo `/api/v1`): `forgejo-api.sh` (shared auth/pagination helper),
`review-fingerprint.sh`, `dismiss-stale-reviews.sh`, `post-review.sh`,
`prepare-review-body.sh`, `publish-review-status.sh`, `report-claude-usage.sh`,
`check-escalation.sh`.

`finalize-review.sh` has no counterpart here: Forgejo has no endpoint to edit a submitted
review, so `prepare-review-body.sh` does that work up front instead of after the fact — see
its header.
