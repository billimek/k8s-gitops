# flux-system

[Flux2](https://github.com/fluxcd/flux2) to automate cluster state using code residing in this repo

![](https://i.imgur.com/QcJ1Tx8.png)

* [discord-notifications/](discord-notifications/) - configure discord for notifications and alerts
* [flux-instance/](flux-instance/) - main entrypoint for flux
* [flux-operator/](flux-operator/) - helm chart to manage flux

There are additional components outside of this directory that are managed by flux.  See the following directories for more details:

* [../../setup/flux/cluster](../../setup/flux/cluster) - flux kustomization definition for this cluster & repo.
* [../../setup/flux/repositories](../../setup/flux/repositories) - all of the `HelmRepository` definitions used by various HelmReleases in the cluster. It is necessary to ensure that the Helm repositories are available before the HelmReleases are applied.
