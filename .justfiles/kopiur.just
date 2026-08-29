set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[doc('List snapshots for an app')]
[script]
list app ns="default":
    command -v kubectl-kopiur &>/dev/null || just log fatal "kubectl-kopiur plugin not found"
    kubectl kopiur snapshots list --policy {{ app }} --namespace {{ ns }}

[doc('Trigger an immediate snapshot for an app')]
[script]
snapshot app ns="default" wait="true":
    command -v kubectl-kopiur &>/dev/null || just log fatal "kubectl-kopiur plugin not found"
    kubectl kopiur snapshot now --policy {{ app }} --namespace {{ ns }} {{ if wait == "true" { "--wait" } else { "" } }}

[doc('Snapshot all apps across all namespaces without waiting')]
[script]
snapshot-all:
    command -v kubectl &>/dev/null || just log fatal "kubectl not found"
    kubectl get snapshotpolicies -A --no-headers -o jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}' | while IFS=, read -r ns app; do
        just kopiur snapshot "$app" "$ns" false
    done

[doc('Restore an app from a specific snapshot (latest if snapshot omitted)')]
[script]
restore app ns="default" snapshot="":
    for cmd in flux kubectl kubectl-kopiur; do command -v "$cmd" &>/dev/null || just log fatal "$cmd not found"; done
    kubectl --namespace {{ ns }} get snapshotpolicy {{ app }} &>/dev/null || just log fatal "snapshotpolicy not found" "namespace" "{{ ns }}" "app" "{{ app }}"
    controller="deployment"
    kubectl --namespace {{ ns }} get deployment {{ app }} &>/dev/null || controller="statefulset"
    # Suspend
    flux --namespace flux-system suspend kustomization cluster-apps
    flux --namespace {{ ns }} suspend helmrelease {{ app }}
    kubectl --namespace {{ ns }} scale "$controller"/{{ app }} --replicas 0
    kubectl --namespace {{ ns }} wait pod --for=delete --selector="app.kubernetes.io/instance={{ app }}" --timeout=5m
    # Restore into a side-by-side PVC, matching the source PVC's current size/class.
    # Pass snapshot= to target a specific Snapshot CR by name instead of the policy's latest.
    if [[ -n "{{ snapshot }}" ]]; then
        source_flag="--from-snapshot {{ snapshot }}"
    else
        source_flag="--from-policy {{ app }} --policy-namespace {{ ns }}"
    fi
    pvc_name="$(kubectl --namespace {{ ns }} get snapshotpolicy {{ app }} -o jsonpath='{.spec.sources[0].pvc.name}')"
    pvc_capacity="$(kubectl --namespace {{ ns }} get pvc "$pvc_name" -o jsonpath='{.spec.resources.requests.storage}')"
    pvc_storageclass="$(kubectl --namespace {{ ns }} get pvc "$pvc_name" -o jsonpath='{.spec.storageClassName}')"
    kubectl kopiur restore $source_flag --create-pvc "${pvc_name}-restored" --size "$pvc_capacity" \
        --storage-class "$pvc_storageclass" --namespace {{ ns }} --wait
    # Resume
    flux --namespace flux-system resume kustomization cluster-apps
    flux --namespace {{ ns }} resume helmrelease {{ app }}
    flux --namespace {{ ns }} reconcile helmrelease {{ app }} --force
    kubectl --namespace {{ ns }} wait pod --for=condition=ready --selector="app.kubernetes.io/instance={{ app }}" --timeout=5m
