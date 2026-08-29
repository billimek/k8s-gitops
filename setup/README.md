# cluster setup with talos

## Setup Directory Structure

The `/setup` directory contains all the components needed to bootstrap the Kubernetes cluster:

### `/setup/bootstrap`

Contains Helmfile configurations for initial cluster bootstrapping:

- `helmfile.d/00-crds.yaml` - Extracts CRDs from Helm charts before Flux starts (uses postRenderer to automatically filter CRDs)
- `helmfile.d/01-apps.yaml` - Core apps (Cilium CNI, CoreDNS, cert-manager, Flux)

### `/setup/flux`

Flux GitOps configuration files which are the entrypoint for flux operating the cluster from this repo. It also contains all of the _shared_ `OCIRepository` and `HelmRepository` definitions used by various HelmReleases in the cluster. It is necessary to ensure that the Helm repositories are available before the HelmReleases are applied.

### `/setup/talos`

Talos Linux configuration for all cluster nodes.  See [talos/](talos/README.md) for details on the nodes and talos configuration

## full cluster bootstrap

(run from the repo root)

For a fresh cluster, this runs the entire flow below in order (secrets ->
render/validate -> Talos bootstrap -> apps), prompting once before starting:

```shell
task k8s-bootstrap:cluster
```

## talos setup & bootstrapping

The individual steps, useful for recovery/re-running a single stage:

Generate the secrets bundle and render the machine configs locally for validation.

```shell
task talos:generate-secrets
task talos:render-clusterconfig
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
