set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[confirm('Bootstrap the entire cluster from scratch (secrets, Talos, apps)?')]
[doc('Full cluster bootstrap (secrets -> talos -> apps), for a fresh cluster')]
[script]
cluster:
    just talos generate-secrets
    just talos render-clusterconfig
    just bootstrap talos
    just bootstrap apps

[doc('Bootstrap Talos')]
[script]
talos:
    for cmd in jq minijinja-cli talosctl; do command -v "$cmd" &>/dev/null || just log fatal "$cmd not found"; done
    if [[ ! -f "$TALOSCONFIG" ]]; then just log fatal "TALOSCONFIG not found" "path" "$TALOSCONFIG"; fi
    talosctl config info &>/dev/null || just log fatal "no talosctl context configured"
    controller="$(talosctl --talosconfig "$TALOSCONFIG" config info --output json | jq --raw-output '.endpoints[]' | shuf -n 1)"
    just talos apply-clusterconfig
    until talosctl --nodes "$controller" bootstrap; do sleep 5; done
    talosctl kubeconfig --nodes "$controller" --force --force-context-name "home" "$KUBECONFIG"

[confirm('Bootstrap apps into Talos cluster?')]
[doc('Bootstrap Apps')]
[script]
apps:
    for cmd in op helmfile kubectl yq; do command -v "$cmd" &>/dev/null || just log fatal "$cmd not found"; done
    if [[ ! -f "$TALOSCONFIG" ]]; then just log fatal "TALOSCONFIG not found" "path" "$TALOSCONFIG"; fi
    for f in "$SETUP_DIR/bootstrap/helmfile.d/00-crds.yaml" "$SETUP_DIR/bootstrap/helmfile.d/01-apps.yaml" "$SETUP_DIR/bootstrap/templates/resources.yaml.j2"; do
        [[ -f "$f" ]] || just log fatal "required file missing" "file" "$f"
    done
    op user get --me &>/dev/null || just log fatal "not signed in to 1Password"
    talosctl config info &>/dev/null || just log fatal "no talosctl context configured"
    until kubectl wait nodes --for=condition=Ready=False --all --timeout=10m; do sleep 5; done
    just template "$SETUP_DIR/bootstrap/templates/resources.yaml.j2" | op inject | kubectl apply --server-side --filename -
    just bootstrap crds
    helmfile --quiet --file "$SETUP_DIR/bootstrap/helmfile.d/01-apps.yaml" sync --hide-notes

[doc('Apply CRDs from bootstrap helmfile (for adding new CRDs to existing cluster)')]
[script]
crds:
    for cmd in helmfile kubectl yq; do command -v "$cmd" &>/dev/null || just log fatal "$cmd not found"; done
    if [[ ! -f "$SETUP_DIR/bootstrap/helmfile.d/00-crds.yaml" ]]; then just log fatal "crds helmfile missing"; fi
    helmfile -f "$SETUP_DIR/bootstrap/helmfile.d/00-crds.yaml" template -q | kubectl apply --server-side --force-conflicts -f -

# See setup/talos/README.md for details on which nodes use which ceph disks that need to be wiped
[confirm('WARNING: This will PERMANENTLY ERASE data on the specified disks. Continue?')]
[doc('Wipe disks on Talos nodes')]
[script]
wipe-disks:
    command -v talosctl &>/dev/null || just log fatal "talosctl not found"
    if [[ ! -f "$TALOSCONFIG" ]]; then just log fatal "TALOSCONFIG not found" "path" "$TALOSCONFIG"; fi
    talosctl config info &>/dev/null || just log fatal "no talosctl context configured"
    mappings="$(cat <<'EOF'
    10.0.7.52:sda
    10.0.7.53:sdb
    10.0.7.55:sda
    10.0.7.59:sda
    EOF
    )"
    echo "The following disks will be wiped:"
    echo "$mappings"
    echo "Proceeding in 5 seconds... Press Ctrl+C to abort"
    sleep 5
    echo "$mappings" | while IFS=: read -r node disk; do
        echo "Wiping disk /dev/${disk} on node ${node}..."
        talosctl --talosconfig "$TALOSCONFIG" wipe disk "${disk}" --nodes="${node}" || echo "Failed to wipe disk ${disk} on node ${node}, continuing..."
        talosctl --talosconfig "$TALOSCONFIG" get disk "${disk}" --nodes="${node}" || echo "Failed to get disk ${disk} on node ${node}, continuing..."
    done
