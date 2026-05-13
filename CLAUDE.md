# Agent Instructions

> Edit either `AGENTS.md` or `CLAUDE.md` — they are the same file (symlink).

GitOps Kubernetes cluster on Talos + FluxCD. Infrastructure (`/setup`) separate from apps (`/kubernetes`).

## Key Commands

```bash
task                    # List all tasks
task k8s:sync-secrets   # Force sync ExternalSecrets
task k8s:cleanse-pods   # Delete Failed/Pending/Succeeded pods
task volsync:snapshot APP=<name>  # Trigger immediate backup
task volsync:list                 # List ReplicationSources/Destinations
task volsync:restore APP=<name>   # Restore an app's PVC from latest backup
flux reconcile kustomization cluster-apps --with-source
```

## Architecture

**Directory Structure**:
- `/setup/` - Talos config, FluxCD setup, OCI repositories
- `/kubernetes/{namespace}/{app}/` - Application manifests

**Namespaces**: cert-manager, default, flux-system, kube-system, monitoring, rook-ceph, system-upgrade

**Patterns**:
- **Cluster**: Single homelab cluster, 1 control plane + 7 workers (Talos)
- **Primary**: OCIRepository + chartRef (exceptions: minecraft and emqx-operator use HelmRepository)
- **Ingress**: Envoy Gateway with HTTPRoute (NOT Traefik/Ingress)
- **Gateways**: `internal` (LAN + Tailscale, 10.0.6.151) and `public` (internet-facing, 10.0.6.150), both in `kube-system`
- **Storage**: Ceph block (default), NFS media mounts, VolSync+Kopia backups
- **Secrets**: ExternalSecret CRDs only (no plaintext)
- **Backups**: ResourceSet automation in kube-system/volsync/
- **CI**: PRs run `flux-local` diff/test (`.github/workflows/flux-local.yaml`); Renovate auto-bumps images per `.renovate/` rules

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
  interval: 1h
  values:
    defaultPodOptions:
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: OnRootMismatch
        runAsGroup: 1001
        runAsNonRoot: true
        runAsUser: 1001  # Check image docs; common values: 1001, 1000, 65534

    controllers:
      app-name:
        containers:
          app:
            image:
              repository: ghcr.io/org/image
              tag: 1.0.0@sha256:...  # Always pin SHA
            resources:
              requests:
                cpu: 10m
                memory: 128Mi
              limits:
                memory: 512Mi
            securityContext:
              allowPrivilegeEscalation: false
              capabilities: {drop: ["ALL"]}
              readOnlyRootFilesystem: true

    persistence:
      config:
        existingClaim: app-name-config

    route:
      app:
        parentRefs:
          - name: internal          # LAN/Tailscale only
            namespace: kube-system
          # - name: public          # Add for internet-facing apps
          #   namespace: kube-system
        hostnames:
          - "app.eviljungle.com"
        rules:
          - matches:
              - path: {type: PathPrefix, value: /}
            backendRefs:
              - name: app-name
                port: http

    service:
      app:
        controller: app-name
        ports:
          http:
            port: 8080
```

## Non-App-Template HelmReleases

For infrastructure charts (not using app-template), use this schema:
```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/helmrelease-helm-v2.json
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
    namespace: "default"   # omit if default
    runAsUser: "1001"      # omit to use default
    capacity: 1Gi          # omit to use default (1Gi)
    schedule: "0 4 * * *"  # omit to use default (0 * * * *, hourly)
    pvcSuffix: "config"    # omit to use default (config)
    cacheCapacity: 20Gi    # omit unless app needs large Kopia cache (e.g. plex)
```

**Schedule groups** (see `resourceset-inputprovider.yaml` header): pick `:00` (Group A, fast), `:15` (Group B, medium), or `:30` (Group C, heavy) when adding an app to spread NFS/Ceph load.

NFS repository (`nas.home:/mnt/ssdtank/kopia`) is configured via `moverVolumes` directly on each `ReplicationSource`/`ReplicationDestination`/`KopiaMaintenance` resource — no webhook injection.

## app-template ConfigMap Naming

App-template v4 names ConfigMaps as `<release-name>` (not `<release-name>-<key>`).

**Preferred**: Use `identifier` to cross-reference inline configMaps without depending on the naming convention:

```yaml
configMaps:
  config:
    data:
      config.yaml: |
        ...

persistence:
  config-file:
    type: configMap
    identifier: config   # references configMaps.config by key
```

**Alternative**: Reference by release name directly:

```yaml
persistence:
  config-file:
    type: configMap
    name: gatus           # correct: just the release name
    # name: gatus-config  # WRONG: do not append the configMap key
```

## Troubleshooting

**Stuck HelmRelease**: When a HelmRelease exhausts its upgrade retries (e.g. due to image pull failures or timeout), scale the deployment to 0 to unblock it, then force reconciliation:
```bash
kubectl scale deployment app-name --replicas=0 -n namespace
flux reconcile helmrelease app-name -n namespace --with-source
# Flux will scale it back up automatically on success
```

**Force ExternalSecret resync**: Bypass the secretStore cache when a 1Password value changed but the ExternalSecret hasn't picked it up:
```bash
kubectl annotate externalsecret <name> -n <ns> force-sync=$(date +%s) --overwrite
```

**HelmRelease upgrade recovery**: Before reconciling an upgrade, check for stuck pods from the prior revision and scale the workload to 0 if needed. If a HelmRelease is stuck, prefer `helm rollback` or suspend/resume the HR over retrying reconciliation:
```bash
flux suspend helmrelease app-name -n namespace
flux resume helmrelease app-name -n namespace
```
## Standards

- **Images**: Always pin with SHA256 digest
- **Security**: Non-root preferred (default UID 1001), read-only rootfs, drop all capabilities. Check image docs for required UID.
- **Naming**: kebab-case for all resources
- **Schemas**: Include yaml-language-server validation on all CRDs
- **No Kustomization**: Intentionally avoided throughout
