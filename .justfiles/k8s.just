set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

# Mount a PVC to a temp container
[doc('Browse a PVC')]
[script]
browse-pvc claim ns="default":
    if ! command -v kubectl &>/dev/null; then just log fatal "kubectl not found"; fi
    if ! kubectl browse-pvc --version &>/dev/null; then just log fatal "kubectl browse-pvc plugin not found"; fi
    if ! kubectl --namespace {{ ns }} get persistentvolumeclaims {{ claim }} &>/dev/null; then just log fatal "PVC not found" "namespace" "{{ ns }}" "claim" "{{ claim }}"; fi
    kubectl browse-pvc --namespace {{ ns }} --image mirror.gcr.io/alpine:latest {{ claim }}

[doc('Open a shell to a node')]
[script]
node-shell node:
    if ! command -v kubectl &>/dev/null; then just log fatal "kubectl not found"; fi
    if ! kubectl get nodes {{ node }} &>/dev/null; then just log fatal "node not found" "node" "{{ node }}"; fi
    trap 'kubectl delete pod --namespace default --selector app.kubernetes.io/managed-by=kubectl-debug --ignore-not-found=true' EXIT
    kubectl debug node/{{ node }} --namespace default --image=mirror.gcr.io/alpine:latest --profile=sysadmin -it

[doc('Sync all ExternalSecrets')]
[script]
sync-secrets:
    if ! command -v kubectl &>/dev/null; then just log fatal "kubectl not found"; fi
    kubectl get externalsecret --all-namespaces --no-headers --output=jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}' | while IFS=, read -r ns name; do
        kubectl --namespace "$ns" annotate externalsecret "$name" force-sync="$(date +%s)" --overwrite
    done

[doc('Cleanse pods with a Failed/Pending/Succeeded phase')]
[script]
cleanse-pods:
    if ! command -v kubectl &>/dev/null; then just log fatal "kubectl not found"; fi
    for phase in Failed Pending Succeeded; do
        kubectl delete pods --all-namespaces --field-selector status.phase="$phase" --ignore-not-found=true
    done

[doc('Suspend flux kustomization for cluster-apps')]
[script]
suspend-flux:
    if ! command -v flux &>/dev/null; then just log fatal "flux not found"; fi
    flux --namespace flux-system suspend kustomization cluster-apps

[doc('Resume flux kustomization for cluster-apps')]
[script]
resume-flux:
    if ! command -v flux &>/dev/null; then just log fatal "flux not found"; fi
    flux --namespace flux-system resume kustomization cluster-apps

# Set minReplicas=1 to prevent scale-to-zero
[doc('Suspend all NFS zero-scalers')]
[script]
hpa-suspend:
    if ! command -v kubectl &>/dev/null; then just log fatal "kubectl not found"; fi
    kubectl get hpa --all-namespaces -l app.kubernetes.io/part-of=nfs-scalers --no-headers --output=jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}' | while IFS=, read -r ns name; do
        kubectl --namespace "$ns" patch hpa "$name" --type=merge -p '{"spec":{"minReplicas":1}}'
    done

# Set minReplicas=0 to allow scale-to-zero
[doc('Resume all NFS zero-scalers')]
[script]
hpa-resume:
    if ! command -v kubectl &>/dev/null; then just log fatal "kubectl not found"; fi
    kubectl get hpa --all-namespaces -l app.kubernetes.io/part-of=nfs-scalers --no-headers --output=jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}' | while IFS=, read -r ns name; do
        kubectl --namespace "$ns" patch hpa "$name" --type=merge -p '{"spec":{"minReplicas":0}}'
    done

[doc('Request a 2FA code from Apple for kei iCloud auth')]
[script]
kei-get-code:
    if ! command -v kubectl &>/dev/null; then just log fatal "kubectl not found"; fi
    if ! kubectl --namespace default get deployment kei &>/dev/null; then just log fatal "kei deployment not found"; fi
    kubectl exec --namespace default deploy/kei -- kei login get-code --config /etc/kei/config.toml

[doc('Submit a 2FA code for kei iCloud auth')]
[script]
kei-submit-code code:
    if ! command -v kubectl &>/dev/null; then just log fatal "kubectl not found"; fi
    if ! kubectl --namespace default get deployment kei &>/dev/null; then just log fatal "kei deployment not found"; fi
    kubectl exec --namespace default deploy/kei -- kei login submit-code --config /etc/kei/config.toml {{ code }}

[doc('View a secret')]
[script]
view-secret secret ns="default":
    if ! command -v kubectl &>/dev/null; then just log fatal "kubectl not found"; fi
    if ! kubectl view-secret --help &>/dev/null; then just log fatal "kubectl view-secret plugin not found"; fi
    kubectl view-secret --namespace {{ ns }} {{ secret }}
