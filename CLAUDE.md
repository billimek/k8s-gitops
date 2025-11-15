# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository manages a GitOps-based Kubernetes deployment using FluxCD on Talos Linux. The Git repository is the source of truth for all cluster configuration. FluxCD continuously reconciles the cluster state to match what's defined in Git.

## Key Architecture Components

### Directory Structure

- `/kubernetes/` - All Kubernetes manifests organized by namespace
  - Each application lives in `/kubernetes/<namespace>/<app-name>/`
  - Application files are typically named `<app-name>.yaml` (HelmReleases) or separate resource files
  - No kustomization files within namespace directories (by design)

- `/setup/` - Cluster bootstrapping and initialization
  - `/setup/bootstrap/` - Helmfile for initial cluster bootstrap (CNI, CRDs, core components)
  - `/setup/crds/` - Custom Resource Definitions loaded before flux reconciles applications
  - `/setup/flux/` - Flux GitOps entrypoint and HelmRepository definitions
  - `/setup/talos/` - Talos OS configuration files (talconfig.yaml, patches, node configs)

### Flux GitOps Structure

The flux entrypoint is `/setup/flux/cluster/cluster.yaml` which defines three main Kustomizations:

1. **flux-repositories** - Loads HelmRepository definitions from `/setup/flux/repositories/`
2. **core-crds** - Loads CRDs from `/setup/crds/` (must wait: true)
3. **cluster-apps** - Loads all applications from `/kubernetes/` (depends on above two)

This ensures proper ordering: Helm repos → CRDs → Applications

### Talos Node Architecture

The cluster consists of mixed control plane and worker nodes running Talos Linux. We won't need to worry abouyt the talos configuration details for this purpose.

## Common Development Commands

All commands use Taskfile (go-task). Run from repository root. Use `task` to see all available tasks.

### Kubernetes Operations

```bash
# Browse/mount a PVC for debugging
task k8s:browse-pvc NS=default CLAIM=pvc-name

# Open shell to a node
task k8s:node-shell NODE=k8s-a

# Force sync all ExternalSecrets
task k8s:sync-secrets

# Clean up Failed/Pending/Succeeded pods
task k8s:cleanse-pods

# Suspend/resume flux reconciliation
task k8s:suspend-flux
task k8s:resume-flux
```

## HelmRelease Patterns

This repository uses bjw-s app-template (version 4.x) for most applications. Follow this pattern:

### Required Schema Declaration

Always include at top of HelmRelease files:
```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/helmrelease-helm-v2.json
```

### Standard HelmRelease Structure

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: app-name
  namespace: namespace
spec:
  interval: 1h  # or 15m for frequently updated apps
  chart:
    spec:
      chart: app-template
      version: 4.x.x  # Always pin exact version
      sourceRef:
        kind: HelmRepository
        name: bjw-s
        namespace: flux-system
  install:
    remediation:
      retries: -1  # Retry indefinitely on install
  upgrade:
    cleanupOnFail: true
    remediation:
      retries: 3
  values:
    controllers:
      app-name:
        pod:
          securityContext:
            runAsNonRoot: true
            runAsUser: 1001
            runAsGroup: 1001
            fsGroup: 1001
            fsGroupChangePolicy: OnRootMismatch
            seccompProfile: { type: RuntimeDefault }
        containers:
          app:
            image:
              repository: ghcr.io/org/image
              tag: version@sha256:digest
            env:
              TZ: "America/New_York"
            probes:
              liveness: &probes
                enabled: true
                custom: true
                spec:
                  httpGet:
                    path: /health
                    port: &port 80
                  initialDelaySeconds: 0
                  periodSeconds: 10
                  timeoutSeconds: 1
                  failureThreshold: 3
              readiness: *probes
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities: { drop: ["ALL"] }
            resources:
              requests:
                cpu: 50m
                memory: 128Mi
              limits:
                memory: 512Mi

    service:
      app:
        primary: true
        controller: app-name
        ports:
          http:
            port: *port

    ingress:
      app:
        enabled: true
        className: nginx
        annotations:
          external-dns.alpha.kubernetes.io/internal: "true"
          external-dns.alpha.kubernetes.io/target: "10.0.6.150"
        hosts:
          - host: &host app.eviljungle.com
            paths:
              - path: /
                pathType: Prefix
                service:
                  identifier: app
                  port: http
        tls:
          - hosts:
              - *host

    persistence:
      config:
        storageClass: "ceph-block"
        accessMode: ReadWriteOnce
        size: "1Gi"
        globalMounts:
          - path: /config
```

### Key Patterns

- **YAML anchors** (`&probes`, `*probes`, `&host`, `&port`) - Use extensively for DRY
- **Image tags** - Include both version and sha256 digest for reproducibility
- **Security contexts** - Always set pod and container security contexts
- **Resources** - Always define requests (for scheduling) and limits (for protection)
- **Probes** - Define liveness/readiness probes for all apps
- **Storage** - Use `ceph-block` for RWO, or `nfs` for shared media

## External Secrets with 1Password

Use ExternalSecret resources to retrieve secrets from 1Password:

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/external-secrets.io/externalsecret_v1.json
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-name
  namespace: namespace
spec:
  refreshInterval: 15m
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword-connect
  target:
    name: app-name-secret
    creationPolicy: Owner
    template:
      engineVersion: v2
      data:
        API_KEY: "{{ .API_KEY }}"
  dataFrom:
    - extract:
        key: app-item-name
```

Store secrets in 1Password under vault "kubernetes" with consistent paths.

## YAML Schema Validation

Always include schema references at the top of YAML files:

- **FluxCD HelmRelease**: `# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/helmrelease-helm-v2.json`
- **FluxCD Kustomization**: `# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/kustomization-kustomize-v1.json`
- **ExternalSecret**: `# yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/external-secrets.io/externalsecret_v1.json`
- **Namespace**: `# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/v1/namespace.json`
- **Kustomization (generic)**: `# yaml-language-server: $schema=https://json.schemastore.org/kustomization`

## FluxCD Best Practices

- **API versions**: Use `helm.toolkit.fluxcd.io/v2` for HelmRelease, `kustomize.toolkit.fluxcd.io/v1` for Kustomization, `source.toolkit.fluxcd.io/v1` for sources
- **Intervals**: 30m for cluster-level Kustomizations, 1h for stable apps, 15m for frequently updated apps
- **Prune**: Always set `prune: true` on Kustomizations for garbage collection
- **Dependencies**: Use `dependsOn` to ensure proper ordering (e.g., CRDs before apps)
- **Retries**: Install with `retries: -1` (indefinite), upgrade with `retries: 3`

## Secret Management

- Never commit plaintext secrets to Git
- Use 1Password via ExternalSecrets for all sensitive data
- Bootstrap secret (1Password Connect token) is manually created once
- All other secrets pulled from 1Password vault "kubernetes"

## VolSync for Backup/Restore

Applications with persistent storage should include VolSync ReplicationSource resources for backup to NFS. See existing apps for patterns.

## Automation

- **Renovate** - Automatically opens PRs for container image and Helm chart updates (configured in `.renovate/`)
- **System Upgrade Controller** - Automatically upgrades Talos and Kubernetes versions as released

## Naming Conventions

- Use kebab-case for all resource names (`media-browser`, `cluster-apps`)
- Use lowercase for namespace names
- Use descriptive names that indicate function rather than implementation

## Environment Variables

- `KUBECONFIG`: Points to `./kubeconfig` in repo root
- `TALOSCONFIG`: Points to `./setup/talos/clusterconfig/talosconfig`
- Tasks automatically set these from root `Taskfile.yaml`

## Important Notes

- This repo avoids kustomization files within app directories (by design)
- CRDs live in `/setup/crds/` to ensure they exist before apps reference them
- All HelmRepository definitions are in `/setup/flux/repositories/`
- Applications are simple YAML files, minimal abstraction
- Use talhelper to generate talos configs, never edit generated configs directly
- The cluster uses `eviljungle.com` domain with split internal/external DNS
