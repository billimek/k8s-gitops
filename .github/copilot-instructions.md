# Copilot Instructions

GitOps Kubernetes cluster on Talos + FluxCD. Infrastructure (`/setup`) separate from apps (`/kubernetes`).

## Key Commands

```bash
task                    # List all tasks
task k8s:sync-secrets   # Force sync ExternalSecrets
flux reconcile kustomization cluster-apps --with-source
```

## Architecture

**Directory Structure**:
- `/setup/` - Talos config, FluxCD setup, OCI repositories
- `/kubernetes/{namespace}/{app}/` - Application manifests

**Namespaces**: cert-manager, default, flux-system, kube-system, monitoring, rook-ceph, system-upgrade

**Patterns**:
- **Primary**: OCIRepository + chartRef (NOT HelmRepository)
- **Ingress**: Envoy Gateway with HTTPRoute (NOT Traefik)
- **Storage**: Ceph block, NFS media, VolSync+Kopia backups
- **Secrets**: ExternalSecret CRDs only (no plaintext)
- **Backups**: ResourceSet automation in kube-system/volsync/

## Application Template

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v4.schema.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: &app app-name
  namespace: target-namespace
spec:
  chartRef:
    kind: OCIRepository
    name: app-template
    namespace: flux-system
  values:
    controllers:
      app-name:
        containers:
          app:
            image:
              repository: ghcr.io/org/image
              tag: 1.0.0@sha256:...  # Always pin SHA
            securityContext:
              runAsNonRoot: true
              runAsUser: 1001
              readOnlyRootFilesystem: true
              capabilities: {drop: ["ALL"]}
    
    service:
      app:
        controller: app-name
        ports:
          http:
            port: 8080
    
    route:
      app:
        parentRefs:
          - name: internal
            namespace: kube-system
        hostnames:
          - "app.eviljungle.com"
        rules:
          - matches:
              - path: {type: PathPrefix, value: /}
            backendRefs:
              - name: app-name
                port: http
    
    persistence:
      config:
        existingClaim: app-name-config
```

## ExternalSecret Template

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/external-secrets.io/externalsecret_v1.json
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-name-secret
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword-connect
  target:
    name: app-name-secret
    template:
      engineVersion: v2
      data:
        API_KEY: "{{ .api_key }}"
  dataFrom:
    - extract:
        key: app-name
```

## Backup Configuration

Add to `kubernetes/kube-system/volsync/resourceset-inputprovider.yaml`:

```yaml
apps:
  - app: app-name
    pvcName: app-name-config
    runAsUser: "1001"
    schedule: "0 4 * * *"
```

## Troubleshooting

**Stuck HelmRelease**: Scale deployment to 0 replicas to allow updates:
```bash
kubectl scale deployment app-name --replicas=0 -n namespace
# Wait for reconciliation, then scale back up
kubectl scale deployment app-name --replicas=1 -n namespace
```

## Schema Standards

- **App-template HelmReleases**: Use `https://raw.githubusercontent.com/bjw-s/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v4.schema.json`
- **Other HelmReleases**: Use `https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/helmrelease-helm-v2.json`
- **ExternalSecret**: Use `https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/external-secrets.io/externalsecret_v1.json`

## Standards

- **Images**: Always pin with SHA256 digest
- **Security**: Non-root (UID 1001), read-only, dropped capabilities
- **Naming**: kebab-case for all resources
- **Schemas**: Include validation on all CRDs
- **No Kustomization**: Intentionally avoided throughout