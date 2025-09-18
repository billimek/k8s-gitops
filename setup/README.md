# cluster setup with talos

## Setup Directory Structure

The `/setup` directory contains all the components needed to bootstrap the Kubernetes cluster:

### `/setup/bootstrap`

Contains Helmfile configurations for initial cluster bootstrapping, including CNI, CRDs, and other essential components required to get the cluster up and running with flux.

- `helmfile.yaml` - Main bootstrap helmfile for cluster components
- `crds-helmfile.yaml` - CRDs-only helmfile for one-time CRD application during bootstrap
- `templates/` - Helmfile template files for various components

### `/setup/flux`

Flux GitOps configuration files which are the entrypoint for flux operating the cluster from this repo. It also contains all of the `HelmRepository` definitions used by various HelmReleases in the cluster. It is necessary to ensure that the Helm repositories are available before the HelmReleases are applied.

**Note:** CRDs are now handled during the bootstrap phase via `setup/bootstrap/crds-helmfile.yaml` rather than through a separate flux kustomization. This ensures all required CRDs are available before flux begins managing cluster applications.

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
