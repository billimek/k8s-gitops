#!/usr/bin/env bash
# Append the pinned Talos and Kubernetes versions to pr-context.md.
# Appends to: pr-context.md (repo root, must already exist)

set -euo pipefail

topf=setup/talos/topf.yaml
talos=$(sed -n 's/^talosVersion: *//p' "$topf")
k8s=$(sed -n 's/^kubernetesVersion: *//p' "$topf")

{
  printf '\n---\n## Platform versions\n\n'
  printf 'Pinned in `%s` (PR head state):\n\n' "$topf"
  printf -- '- Talos: %s\n' "${talos:-unknown}"
  printf -- '- Kubernetes: %s\n' "${k8s:-unknown}"
} >> pr-context.md
