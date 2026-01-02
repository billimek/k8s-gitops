# Copilot Instructions

This file provides guidance to GitHub Copilot and other AI assistants when working with code in this repository.

## Repository Overview

This is a GitOps-based Kubernetes cluster managed by FluxCD on Talos Linux. The repository follows a strict separation between infrastructure setup (`/setup`) and application workloads (`/kubernetes`), with FluxCD continuously reconciling the desired state from Git.

## Common Commands

### Taskfile Commands

All commands use [Task](https://taskfile.dev) and should be run from repository root:

```bash
# List all available tasks
task

# Talos cluster management
task talos:generate-clusterconfig  # Generate Talos config from talconfig.yaml
task k8s-bootstrap:talos           # Bootstrap Talos cluster nodes

# Kubernetes bootstrapping
task k8s-bootstrap:apps            # Bootstrap cluster with Cilium, CRDs, Flux

# Kubernetes operations
task k8s:browse-pvc CLAIM=pvc-name NS=namespace  # Mount PVC to temp container
task k8s:node-shell NODE=node-name               # Shell into a cluster node
task k8s:sync-secrets                            # Force sync all ExternalSecrets
task k8s:cleanse-pods                            # Remove Failed/Pending/Succeeded pods
task k8s:suspend-flux                            # Suspend cluster-apps reconciliation
task k8s:resume-flux                             # Resume cluster-apps reconciliation
```

### Direct kubectl/flux Commands

```bash
# Flux operations (requires flux CLI)
flux reconcile kustomization cluster-apps --with-source
flux get helmreleases --all-namespaces
flux logs --follow --level=error

# Kubectl with kubeconfig (set in Taskfile vars)
export KUBECONFIG=./kubeconfig
kubectl get pods -A
kubectl get helmreleases -A
```

## Architecture Overview

### Directory Structure & Reconciliation Flow

```
/setup/
├── bootstrap/      # Helmfile for initial cluster bootstrap (CNI, CRDs, Flux)
├── flux/           # FluxCD configuration and HelmRepository definitions
└── talos/          # Talos Linux OS configuration (talconfig.yaml)

/kubernetes/        # Application workloads by namespace
├── flux-system/    # Flux controllers, notifications
├── kube-system/    # CNI, DNS, secrets, CSI drivers
├── cert-manager/   # TLS certificate management
├── rook-ceph/      # Ceph storage cluster
├── system-upgrade/ # Talos/K8s auto-upgrades
├── default/        # User applications (Plex, Radarr, Home-Assistant, etc.)
└── monitoring/     # Prometheus, Grafana, VictoriaMetrics
```

### FluxCD Bootstrap Chain

FluxCD reconciles in stages (defined in `/setup/flux/cluster/cluster.yaml`):

1. **flux-repositories** → Deploys all HelmRepository CRDs first
2. **cluster-apps** → Deploys all applications (depends on above)

This ensures HelmRepositories exist before any workload tries to use them.

### Key Architectural Patterns

**CRDs Management**: CRDs are applied at bootstrap time via `/setup/bootstrap/helmfile.d/00-crds.yaml`. For adding new CRDs to an existing cluster, use the `task k8s-bootstrap:crds` command. Ongoing CRD lifecycle management is handled by Flux through HelmReleases in their respective namespaces (e.g., `/kubernetes/monitoring/prometheus-operator-crds/`).

**Secret Management**: All secrets use ExternalSecret CRDs backed by 1Password Connect. Never commit plaintext secrets. Structure: `kubernetes/{namespace}/{app}/externalsecret.yaml`.

**Storage Strategy**:
- **Config**: Ceph block storage (`ceph-block` storageClass)
- **Media**: NFS mounts from `nas.home` (read-only for most apps)
- **Tmp/Cache**: emptyDir volumes

**Dual-Gateway Architecture**:
- **Public Gateway** (10.0.6.150): Internet-accessible services via `eviljungle.com` (Cloudflare DNS)
- **Internal Gateway** (10.0.6.151): LAN and Tailscale access
- External-DNS watches HTTPRoute annotations and manages both DNS backends

**HTTPRoute Pattern**: Apps use Envoy Gateway with HTTPRoute resources. Services can be exposed via `public` gateway, `internal` gateway, or both (split-horizon) for dual access to the same hostname.

## Adding New Applications

### 1. Create Application Directory

```bash
kubernetes/{namespace}/{app-name}/
├── {app-name}.yaml       # HelmRelease
├── externalsecret.yaml   # If secrets needed
└── volsync.yaml          # If backups needed
```

### 2. HelmRelease Template

Most apps use the `bjw-s/app-template` chart. Follow this structure:

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v4.schema.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: &app app-name
  namespace: namespace
spec:
  interval: 1h
  chart:
    spec:
      chart: app-template
      version: 3.x.x  # Pin explicit version
      sourceRef:
        kind: HelmRepository
        name: bjw-s
        namespace: flux-system
  install:
    createNamespace: true
    remediation:
      retries: -1  # Infinite retries until success
  upgrade:
    cleanupOnFail: true
    remediation:
      retries: 3
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
            securityContext:  # Standard security defaults
              runAsNonRoot: true
              runAsUser: 1001
              runAsGroup: 1001
              readOnlyRootFilesystem: true
              allowPrivilegeEscalation: false
              seccompProfile:
                type: RuntimeDefault
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
      tmp:
        type: emptyDir
        globalMounts:
          - path: /tmp
```

### 3. Register HelmRepository (if new)

If using a new Helm repository, add it first:

```bash
setup/flux/repositories/{repo-name}.yaml
```

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/helmrepository-source-v1.json
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: repo-name
  namespace: flux-system
spec:
  interval: 1h
  url: https://charts.example.com
```

For OCI registries:

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: repo-name
  namespace: flux-system
spec:
  type: oci
  interval: 1h
  url: oci://ghcr.io/org/charts
```

## Working with CRDs

### Adding New CRDs

When adding a new operator or chart that includes CRDs:

1. **Add to bootstrap helmfile**: Include the chart in `/setup/bootstrap/helmfile.d/00-crds.yaml`
   - The helmfile uses a postRenderer to extract only CRDs from charts
   - Existing CRDs are applied at bootstrap time via `task k8s-bootstrap:apps`

2. **Apply to existing cluster**: Run `task k8s-bootstrap:crds` to apply new CRDs without re-bootstrapping

3. **Create ongoing management**: For CRD lifecycle management after bootstrap, create a HelmRelease in the appropriate namespace:
   ```yaml
   # kubernetes/{namespace}/{operator}-crds/
   ---
   apiVersion: source.toolkit.fluxcd.io/v1
   kind: OCIRepository
   metadata:
     name: operator-crds
     namespace: namespace
   spec:
     interval: 5m
     layerSelector:
       mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
       operation: copy
     ref:
       tag: 1.0.0
     url: oci://ghcr.io/org/charts/operator-crds
   ---
   apiVersion: helm.toolkit.fluxcd.io/v2
   kind: HelmRelease
   metadata:
     name: operator-crds
     namespace: namespace
   spec:
     chartRef:
       kind: OCIRepository
       name: operator-crds
     interval: 1h
   ```

### Updating CRDs

CRDs are updated through two mechanisms:

1. **Bootstrap helmfile**: Renovate updates versions in `/setup/bootstrap/helmfile.d/00-crds.yaml`
2. **Flux HelmReleases**: Renovate updates HelmRelease versions (e.g., `prometheus-operator-crds` in monitoring namespace)

Both methods ensure CRDs stay current with their respective operators.

## Secret Management with 1Password

### ExternalSecret Pattern

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/external-secrets.io/externalsecret_v1.json
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-name-secret
  namespace: namespace
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword-connect
  target:
    name: app-name-secret
    creationPolicy: Owner
    template:
      engineVersion: v2
      data:
        # Simple key extraction
        API_KEY: "{{ .api_key }}"
        # Template with multiple fields
        config.yaml: |
          username: {{ .username }}
          password: {{ .password }}
  dataFrom:
    - extract:
        key: app-name  # 1Password item name
```

Secrets are stored in 1Password vaults and synced via External-Secrets operator.

## Image Management

### Image Pinning

Always pin images with SHA256 digest:

```yaml
image:
  repository: ghcr.io/org/image
  tag: 1.0.0@sha256:abc123...
```

Renovate will automatically update these and create PRs.

### Custom Images

Many apps use custom images from `ghcr.io/home-operations/*`. These are pre-configured with specific settings and are maintained separately.

## Backup with VolSync

For applications requiring backup:

```yaml
---
apiVersion: volsync.backube/v1alpha1
kind: ReplicationSource
metadata:
  name: app-name
  namespace: namespace
spec:
  sourcePVC: app-name-config
  trigger:
    schedule: "0 0 * * *"  # Daily at midnight
  restic:
    repository: app-name-restic-secret
    copyMethod: Snapshot
    pruneIntervalDays: 10
    retain:
      daily: 10
      weekly: 4
      monthly: 3
```

Backups use Restic to S3-compatible storage (Garage service).

## HTTPRoute Patterns

### Internal-Only Access

For services accessible only from LAN and Tailscale:

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
      - &host "app-name.${SECRET_DOMAIN}"
    rules:
      - backendRefs:
          - identifier: app
            port: http
```

### Public Internet Access

For services accessible from the internet:

```yaml
route:
  app:
    annotations:
      external-dns.alpha.kubernetes.io/external: "true"
    parentRefs:
      - name: public
        namespace: kube-system
        sectionName: https  # HTTPS-only
    hostnames:
      - &host "app-name.${SECRET_DOMAIN}"
    rules:
      - backendRefs:
          - identifier: app
            port: http
```

### Split-Horizon (Dual Access)

For services accessible both internally and externally with the same hostname:

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
      - &host "app-name.${SECRET_DOMAIN}"
    rules:
      - backendRefs:
          - identifier: app
            port: http
  internal:
    annotations:
      external-dns.alpha.kubernetes.io/internal: "true"
    parentRefs:
      - name: internal
        namespace: kube-system
        sectionName: https
    hostnames:
      - *host
    rules:
      - backendRefs:
          - identifier: app
            port: http
```

External-DNS creates both Cloudflare DNS records (public) and OpnSense host overrides (internal).

## YAML Schema Validation

Always include schema validation comments:

- **HelmRelease (bjw-s)**: `# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v4.schema.json`
- **HelmRelease (standard)**: `# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/helmrelease-helm-v2.json`
- **Kustomization**: `# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/kustomization-kustomize-v1.json`
- **ExternalSecret**: `# yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/external-secrets.io/externalsecret_v1.json`
- **HelmRepository**: `# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/helmrepository-source-v1.json`
- **HTTPRoute**: `# yaml-language-server: $schema=https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.1/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml`
- **Gateway**: `# yaml-language-server: $schema=https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.1/config/crd/standard/gateway.networking.k8s.io_gateways.yaml`
- **Namespace**: `# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/v1/namespace.json`

## Key Technologies

- **Talos Linux**: Immutable Kubernetes OS
- **FluxCD v2**: GitOps controller using HelmRelease v2 and Kustomization APIs
- **Cilium**: CNI, network policy, and LoadBalancer IPAM
- **Envoy Gateway**: Gateway API implementation for ingress (replaces nginx)
- **Rook-Ceph**: Distributed block storage
- **External-Secrets**: Secret management with 1Password backend
- **External-DNS**: Automatic DNS management for both internal (OpnSense) and external (Cloudflare)
- **Cert-Manager**: TLS certificate automation
- **Renovate**: Automated dependency updates
- **VolSync**: PVC backup using Restic

## Naming Conventions

- Use **kebab-case** for resource names (e.g., `media-browser`, `cluster-apps`)
- Use **lowercase** for namespace names
- Use descriptive names that indicate function rather than implementation

## Reconciliation Intervals

- **Cluster-level Kustomizations**: 30m
- **HelmReleases**: 15m (or 1h for stable apps)
- **External source repositories**: 1h

## Important Notes

- **Avoid Kustomization files**: This repo intentionally avoids proliferating `kustomization.yaml` files throughout the tree
- **Security defaults**: All containers run as non-root (UID 1001) with dropped capabilities and read-only root filesystem
- **Renovate automation**: Images and charts auto-update via PRs. Review breaking changes before merging
- **Gateway selection**: Use `internal` gateway for LAN/Tailscale-only services, `public` gateway for internet-facing services, or both for split-horizon access
- **No plaintext secrets**: All secrets must use ExternalSecret CRDs backed by 1Password
- **HTTP→HTTPS redirect**: Automatic global redirect configured at gateway level; use `sectionName: https` to target HTTPS listener directly
