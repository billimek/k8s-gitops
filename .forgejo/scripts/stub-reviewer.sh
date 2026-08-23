#!/usr/bin/env bash
# Stand-in for the model step while the deterministic harness is being proved
# out (#6149). Writes the same two files the real reviewer will write in #6150
# -- review.md and verdict.txt -- so swapping the model in is a one-step change
# and nothing downstream has to move.
#
# The stub deliberately emits APPROVED alongside a `Known issues` bullet, so
# prepare-review-body.sh downgrades it to COMMENT. That exercises the highest-
# value deterministic path in the harness and, because COMMENT does not satisfy
# branch protection's required-approving-review rule, it also guarantees the
# stub can never rubber-stamp a real version bump into an automerge while the
# GitHub gate is still the authoritative one.
#
# Optional env:
#   DEPTH, MODEL - echoed into the body so tier routing is visible in the PR

set -euo pipefail

cat > review.md <<EOF
### Stubbed review -- deterministic harness only

**Verdict**: Safe to merge

The Forgejo renovate-review harness ran end to end, but the model step is not
wired up yet (billimek/k8s-gitops#6149). **No analysis of this upgrade was
performed.** Tier routing selected depth \`${DEPTH:-unknown}\` / model
\`${MODEL:-unknown}\`, which is the only real signal in this review.

**Known issues**:
- The reviewer model is stubbed, so this verdict carries no research behind it. Treat the GitHub \`claude/renovate-review\` check as authoritative until billimek/k8s-gitops#6150 lands.

**Sources consulted**:
- none (stub)
EOF

echo "APPROVED" > verdict.txt

echo "wrote stub review.md and verdict.txt (depth=${DEPTH:-unknown} model=${MODEL:-unknown})"
