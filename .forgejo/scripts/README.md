# `.forgejo/scripts`

Supporting scripts for `.forgejo/workflows/renovate-review.yaml`.

Several entries here are **symlinks into `.github/scripts/`**. Those scripts are pure text
processing with no platform coupling, and the GitHub and Forgejo review gates run in parallel
until the Forgejo one is proven out — a divergent copy on either side would confound that
comparison. Symlinking removes the possibility:

| Symlinked (shared, unchanged) | Ported (Forgejo `/api/v1`) |
| --- | --- |
| `append-flate-evidence.sh` | `forgejo-api.sh` (shared auth/pagination helper) |
| `classify-renovate-pr.sh` | `review-fingerprint.sh` |
| `detect-advisory-findings.sh` | `dismiss-stale-reviews.sh` |
| `sanitize-review-body.sh` | `post-review.sh` |
| | `prepare-review-body.sh` |
| | `publish-review-status.sh` |
| | `report-claude-usage.sh` |
| | `check-escalation.sh` |

Once the GitHub workflow is retired, each symlink has to become a real file in the same
change. A dangling symlink fails loudly rather than silently, which is the intent.

`finalize-review.sh` has no counterpart here: Forgejo has no endpoint to edit a submitted
review, so `prepare-review-body.sh` does that work up front instead of after the fact — see
its header.
