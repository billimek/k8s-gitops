# `.forgejo/scripts`

Supporting scripts for `.forgejo/workflows/renovate-review.yaml`.

Several entries here are **symlinks into `.github/scripts/`**. Those scripts are pure text
processing with no platform coupling, and the GitHub and Forgejo review gates run in parallel
until #6151 signs off — a divergent copy on either side would confound exactly the comparison
that phase exists to make. Symlinking removes the possibility:

| Symlinked (shared, unchanged) | Ported (Forgejo `/api/v1`) |
| --- | --- |
| `append-flate-evidence.sh` | `forgejo-api.sh` (shared auth/pagination helper) |
| `classify-renovate-pr.sh` | `review-fingerprint.sh` |
| `detect-advisory-findings.sh` | `dismiss-stale-reviews.sh` |
| `sanitize-review-body.sh` | `post-review.sh` |
| | `prepare-review-body.sh` |
| | `publish-review-status.sh` |
| | `report-claude-usage.sh` |
| | `stub-reviewer.sh` (temporary, replaced in #6150) |

At cutover (#6121) `.github/` goes away, so each symlink has to become a real file in the same
change. A dangling symlink fails loudly rather than silently, which is the intent.

`check-escalation.sh` and `finalize-review.sh` have no counterpart here: escalation keys off the
model's execution file and lands with the model in #6150, and finalization is impossible
after the fact on Forgejo — see the header of `prepare-review-body.sh`.
