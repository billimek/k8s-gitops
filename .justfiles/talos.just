set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[doc('Render secrets.yaml for topf from 1Password')]
[script]
generate-secrets:
    for cmd in op envsubst; do command -v "$cmd" &>/dev/null || just log fatal "$cmd not found"; done
    [[ -f "$SETUP_DIR/talos/secrets.yaml.tpl" ]] || just log fatal "secrets.yaml.tpl not found"
    [[ -f "$SETUP_DIR/talos/secrets.env" ]] || just log fatal "secrets.env not found"
    op user get --me &>/dev/null || just log fatal "not signed in to 1Password"
    op run --env-file "$SETUP_DIR/talos/secrets.env" --no-masking -- sh -c \
        "envsubst < $SETUP_DIR/talos/secrets.yaml.tpl > $SETUP_DIR/talos/secrets.yaml"

[doc('Render Talos machine configs locally for validation (no apply)')]
[script]
render-clusterconfig:
    command -v topf &>/dev/null || just log fatal "topf not found"
    [[ -f "$SETUP_DIR/talos/topf.yaml" ]] || just log fatal "topf.yaml not found"
    [[ -f "$SETUP_DIR/talos/secrets.yaml" ]] || just log fatal "secrets.yaml not found"
    cd "$SETUP_DIR/talos" && topf render -o ./render-output

[doc('Generate talosconfig from the secrets bundle')]
[script]
generate-talosconfig:
    command -v topf &>/dev/null || just log fatal "topf not found"
    [[ -f "$SETUP_DIR/talos/topf.yaml" ]] || just log fatal "topf.yaml not found"
    [[ -f "$SETUP_DIR/talos/secrets.yaml" ]] || just log fatal "secrets.yaml not found"
    cd "$SETUP_DIR/talos" && topf talosconfig > "$TALOSCONFIG"

[doc('Apply clusterconfig for a Talos cluster')]
[script]
apply-clusterconfig dry_run="false":
    command -v topf &>/dev/null || just log fatal "topf not found"
    [[ -f "$SETUP_DIR/talos/topf.yaml" ]] || just log fatal "topf.yaml not found"
    [[ -f "$SETUP_DIR/talos/secrets.yaml" ]] || just log fatal "secrets.yaml not found"
    cd "$SETUP_DIR/talos" && topf apply {{ if dry_run == "true" { "--dry-run" } else { "" } }}

[doc('Apply Talos config to a node')]
[script]
apply-node node dry_run="false":
    command -v topf &>/dev/null || just log fatal "topf not found"
    [[ -f "$SETUP_DIR/talos/secrets.yaml" ]] || just log fatal "secrets.yaml not found"
    cd "$SETUP_DIR/talos" && topf apply --nodes-filter "^{{ node }}$" {{ if dry_run == "true" { "--dry-run" } else { "" } }}

[doc('Upgrade Talos on a single node')]
[script]
upgrade-node node mode="powercycle":
    command -v topf &>/dev/null || just log fatal "topf not found"
    [[ -f "$SETUP_DIR/talos/secrets.yaml" ]] || just log fatal "secrets.yaml not found"
    cd "$SETUP_DIR/talos" && topf upgrade --nodes-filter "^{{ node }}$" --reboot-mode={{ mode }}

[doc('Upgrade Kubernetes across the whole cluster')]
[script]
upgrade-k8s version:
    for cmd in jq talosctl; do command -v "$cmd" &>/dev/null || just log fatal "$cmd not found"; done
    node="$(talosctl --talosconfig "$TALOSCONFIG" config info --output json | jq --exit-status --raw-output '.endpoints[]' | shuf -n 1)"
    talosctl --nodes "$node" get machineconfig &>/dev/null || just log fatal "cannot reach node" "node" "$node"
    talosctl --nodes "$node" upgrade-k8s --to {{ version }}

# TODO: talosctl reboot doesn't appear to cordon and drain the node prior to rebooting - it just immediately reboots. Not sure if this is going to be a problem.
[doc('Reboot Talos on a single node')]
[script]
reboot-node node mode="powercycle":
    command -v talosctl &>/dev/null || just log fatal "talosctl not found"
    talosctl --nodes {{ node }} get machineconfig &>/dev/null || just log fatal "cannot reach node" "node" "{{ node }}"
    talosctl --nodes {{ node }} reboot --mode={{ mode }}

[confirm('Reboot all Talos nodes one by one ... continue?')]
[doc('Reboot Talos nodes one at a time across the whole cluster')]
[script]
reboot-cluster mode="powercycle":
    for cmd in jq talosctl; do command -v "$cmd" &>/dev/null || just log fatal "$cmd not found"; done
    talosctl --talosconfig "$TALOSCONFIG" config info --output json | jq --exit-status --raw-output '.nodes[]' | sort -r | while read -r node; do
        just talos reboot-node "$node" {{ mode }}
    done

[confirm('Shutdown the Talos cluster ... continue?')]
[doc('Shutdown Talos across the whole cluster')]
[script]
shutdown-cluster:
    for cmd in jq talosctl; do command -v "$cmd" &>/dev/null || just log fatal "$cmd not found"; done
    nodes="$(talosctl --talosconfig "$TALOSCONFIG" config info --output json | jq --exit-status --join-output '[.nodes[]] | join(",")')"
    talosctl --nodes "$nodes" get machineconfig &>/dev/null || just log fatal "cannot reach nodes"
    talosctl shutdown --nodes "$nodes" --force

[confirm('Reset Talos node ... continue?')]
[doc('Reset Talos on a single node')]
[script]
reset-node node:
    command -v topf &>/dev/null || just log fatal "topf not found"
    [[ -f "$SETUP_DIR/talos/secrets.yaml" ]] || just log fatal "secrets.yaml not found"
    cd "$SETUP_DIR/talos" && topf reset --nodes-filter "^{{ node }}$"

[confirm('Reset the Talos cluster ... continue?')]
[doc('Reset Talos across the whole cluster')]
[script]
reset-cluster:
    command -v topf &>/dev/null || just log fatal "topf not found"
    [[ -f "$SETUP_DIR/talos/secrets.yaml" ]] || just log fatal "secrets.yaml not found"
    cd "$SETUP_DIR/talos" && topf reset

[doc('Generate the kubeconfig for a Talos cluster')]
[script]
kubeconfig:
    command -v topf &>/dev/null || just log fatal "topf not found"
    [[ -f "$SETUP_DIR/talos/secrets.yaml" ]] || just log fatal "secrets.yaml not found"
    cd "$SETUP_DIR/talos" && topf kubeconfig --validity 8760h0m0s > "$KUBECONFIG"
