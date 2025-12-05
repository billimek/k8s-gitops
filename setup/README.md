# cluster setup with talos

## Setup Directory Structure

The `/setup` directory contains all the components needed to bootstrap the Kubernetes cluster:

### `/setup/bootstrap`

Contains Helmfile configurations for initial cluster bootstrapping:

- `helmfile.d/00-crds.yaml` - Extracts CRDs from Helm charts before Flux starts
- `helmfile.d/01-apps.yaml` - Core apps (Cilium CNI, CoreDNS, cert-manager, Flux)

### `/setup/crds`

Vendored CRDs for components without Helm chart support. Most CRDs are now managed via HelmReleases (belt-and-suspenders approach: bootstrap installs, HelmRelease maintains). Only these remain vendored:

- `rook-ceph` - Safety backup (also installed via helmfile)
- `system-upgrade-controller` - No Helm chart available

### `/setup/flux`

Flux GitOps configuration files which are the entrypoint for flux operating the cluster from this repo. It also contains all of the `HelmRepository` definitions used by various HelmReleases in the cluster. It is necessary to ensure that the Helm repositories are available before the HelmReleases are applied.

### `/setup/talos`

Talos Linux configuration for all cluster nodes.  See [talos/](talos/README.md) for details on the nodes and talos configuration

## talos setup & bootstrapping

(run from the repo root)

Use talhelper to generate the config files in the `clusterconfig` directory.

```shell
task talos:generate-clusterconfig
```

Bootstrap the talos nodes. It may take some time for the cluster to be ready.

```shell
task k8s-bootstrap:talos
```

## kubernetes setup & bootstrapping

Bootstrap the kubernetes cluster with required prerequisites (cilium CNI, CRDs, flux, etc).

```shell
task k8s-bootstrap:apps
```
