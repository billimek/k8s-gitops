# flux2

[Flux2](https://github.com/fluxcd/flux2) to automate cluster state using code residing in this repo

![](https://i.imgur.com/QcJ1Tx8.png)

All of these operate in the `flux-system` namespace, but the files cannot be located in the `flux-system` directory because kustomize reasons.

* [discord-notifications/](discord-notifications/) - configure discord for notifications and alerts
* [helm-chart-repositories/](helm-chart-repositories/) - configure all needed helm repositories for use by `HelmReleases`
* [monitoring/](monitoring/) - configure `PodMonitors` to expose flux metrics to prometheus
