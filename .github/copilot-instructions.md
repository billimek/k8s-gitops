# Copilot Instructions

GitOps-based Kubernetes cluster managed by FluxCD on Talos Linux. Infrastructure (`/setup`) is separated from applications (`/kubernetes`).

## Key Commands

```bash
task                    # List all tasks
task k8s-bootstrap:crds # Apply new CRDs to existing cluster
task k8s:sync-secrets   # Force sync ExternalSecrets
flux reconcile kustomization cluster-apps --with-source
```

## Architecture

**Directory Structure**:
- `/setup/` - Talos config, FluxCD setup, HelmRepositories
- `/kubernetes/{namespace}/{app}/` - Application manifests

**Key Patterns**:
- **CRDs**: Bootstrap via helmfile, manage via HelmReleases
- **Secrets**: ExternalSecret CRDs backed by 1Password (no plaintext)
- **Storage**: Ceph block (`ceph-block`), NFS media mounts, VolSync+Kopia backups
- **Ingress**: Envoy Gateway with HTTPRoute resources
- **Gateways**: `public` (10.0.6.150, internet), `internal` (10.0.6.151, LAN/Tailscale)

## Adding New Applications

Create `kubernetes/{namespace}/{app-name}/{app-name}.yaml`:

**HelmRelease Template** (using `bjw-s/app-template`):

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v4.schema.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: &app app-name
spec:
  interval: 1h
  chart:
    spec:
      chart: app-template
      version: 3.x.x
      sourceRef:
        kind: HelmRepository
        name: bjw-s
        namespace: flux-system
  values:
    controllers:
      app-name:
        containers:
          app:
            image:
              repository: ghcr.io/org/image
              tag: 1.0.0@sha256:...  # Always pin with SHA
            env:
              TZ: America/New_York
            securityContext:
              runAsNonRoot: true
              runAsUser: 1001
              readOnlyRootFilesystem: true
              allowPrivilegeEscalation: false
              capabilities:
                drop: ["ALL"]
    
    service:
      app:
        controller: app-name
        ports:
          http:
            port: 8080
    
    route:
      app:
        annotations:
          external-dns.alpha.kubernetes.io/internal: "true"
          external-dns.alpha.kubernetes.io/target: "10.0.6.151"
        parentRefs:
          - name: internal
            namespace: kube-system
        hostnames:
          - &host "app-name.${SECRET_DOMAIN}"
        rules:
          - backendRefs:
              - identifier: app
                port: http
    
    persistence:
      config:
        existingClaim: app-name-config
        globalMounts:
          - path: /config
```

**ExternalSecret** (if secrets needed):

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
        key: app-name  # 1Password item name
```

**Backups**: Add to `kubernetes/kube-system/volsync/resourceset-volsync-backups.yaml`:
```yaml
inputs:
  - app: app-name
    pvcName: app-name-config
    runAsUser: "1001"
    schedule: "0 4 * * *"
```

## HTTPRoute Patterns

**Internal-only** (LAN/Tailscale):

```yaml
route:
  app:
    annotations:
      external-dns.alpha.kubernetes.io/internal: "true"
      external-dns.alpha.kubernetes.io/target: "10.0.6.151"
    parentRefs:
      - name: internal
        namespace: kube-system
    hostnames:
      - "app.${SECRET_DOMAIN}"
```

**Public** (internet-accessible):

```yaml
route:
  app:
    annotations:
      external-dns.alpha.kubernetes.io/external: "true"
    parentRefs:
      - name: public
        namespace: kube-system
        sectionName: https
    hostnames:
      - "app.${SECRET_DOMAIN}"
```

**Split-horizon** (both internal + external):

```yaml
route:
  app:
    annotations:
      external-dns.alpha.kubernetes.io/external: "true"
    parentRefs:
      - name: public
        namespace: kube-system
        sectionName: https
    hostnames:
      - &host "app.${SECRET_DOMAIN}"
  internal:
    annotations:
      external-dns.alpha.kubernetes.io/internal: "true"
    parentRefs:
      - name: internal
        namespace: kube-system
    hostnames:
      - *host
```

## YAML Schemas

Always include schema validation:
- **HelmRelease (bjw-s)**: `$schema=https://raw.githubusercontent.com/bjw-s/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v4.schema.json`
- **ExternalSecret**: `$schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/external-secrets.io/externalsecret_v1.json`
- **HTTPRoute**: `$schema=https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.1/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml`

## Important Notes

- **Images**: Always pin with SHA256 digest (`tag: 1.0.0@sha256:...`)
- **Security**: Containers run as non-root (UID 1001), read-only root filesystem, dropped capabilities
- **Backups**: Centrally managed in `kubernetes/kube-system/volsync/resourceset-volsync-backups.yaml`
- **No Kustomization files**: Intentionally avoided throughout the tree
- **No plaintext secrets**: Use ExternalSecret CRDs only
- **Naming**: Use kebab-case for resources
