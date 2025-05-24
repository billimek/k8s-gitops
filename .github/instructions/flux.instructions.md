# GitHub Copilot Instructions for Flux Configuration

## When to Apply These Instructions

These instructions should be applied when working with FluxCD configuration files, including:
- Files in `/kubernetes/flux-system/` and `/setup/flux/` directories
- Kustomization resources with `kustomize.toolkit.fluxcd.io` API group
- GitRepository, HelmRepository, and OCIRepository resources
- Any file related to FluxCD reconciliation

## Flux Configuration Best Practices

1. Use the correct API versions:
   - `kustomize.toolkit.fluxcd.io/v1` for Kustomization resources
   - `helm.toolkit.fluxcd.io/v2` for HelmRelease resources
   - `source.toolkit.fluxcd.io/v1` for source controller resources
   - `source.toolkit.fluxcd.io/v1` for HelmRepository resources

2. Always specify reconciliation intervals:
   - 30m for cluster-level Kustomizations
   - 30m for application HelmReleases
   - 1h for external source repositories

3. Always implement proper remediation for HelmRelease resources:
```yaml
install:
   createNamespace: true
   remediation:
      retries: -1
upgrade:
   cleanupOnFail: true
   remediation:
      retries: 3
```

4. Use the following structure for sourcing Helm charts:
```yaml
chart:
   spec:
      chart: chart-name
      version: x.y.z  # Always pin versions
      sourceRef:
      kind: HelmRepository  # Or OCIRepository for OCI-based charts
      name: repository-name
      namespace: flux-system
```

5. For Kustomizations, always configure:
   - `prune: true` to enable garbage collection
   - `path: ./path/to/directory` pointing to the correct directory
   - `sourceRef` pointing to the GitRepository

6. Organize Flux resources:
   - Place sources in `/setup/flux/repositories/`
   - Place kustomizations in `/setup/flux/cluster/`
   - Group repositories by type (helm, git, oci)
