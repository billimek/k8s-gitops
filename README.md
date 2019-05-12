# GitOps workflow for kubernetes cluster

![](https://i.imgur.com/qBbjyNx.png)

Leverage [WeaveWorks Flux](https://github.com/weaveworks/flux) to automate cluster state using code residing in this repo

## Setup

See [cluster bootstrap instructions](cluster/) for bootstrapping a kubernetes cluster for using this repo

## Deep-Dive

### System-level configuration

See [kube-system](kube-system/) for details on system-level configurations (cert-manager, traefik, decsheduler, fluxcloud, forwardauth OAuth, heapster, dashboard, kured, metallb, sealed-secrets)

### Storage

See [storage](storage/) for details on storage type services (local storage provider, minio, nfs-client, external NFS mounts, external ceph, stash)

### Deployments

See [deployments](deployments/) for details on regular workloads (chronograf, comcast usage, grafana, home-assistant, hubot, influxdb, minecraft, cable modem stats, node-red, nzbget, plex, prometheus, rabbitmq, radarr, rtorrent-flood, sonarr, speedtest results, unifi, uptimerobot agent)

### Logging

See [logging](logging/) for details on logging solutions (loki, EFK Stack (elasticSearch, fluentd, kibana), elasticsearch-curator)

## Caveats

### Manual actions

See [manual-steps](manual-steps/) for instructions things that cannot be handled by flux

### New namespaces

If deploying a helm chart that needs to live in a new namespace, Flux seems to expect that the namespace is already created, or else the helm deployment will fail.  When deploying a helm chart in the traditional approach via the `helm` CLI, it would handle the namespace creation for you.  In Flx, you must explicitly create a helm chart (see [storage/rook/namespace.yaml](storage/rook/namespace.yaml) for an example of this)

### Deletions

[Flux doesn't handle deletions](https://github.com/weaveworks/flux/blob/master/site/faq.md#will-flux-delete-resources-that-are-no-longer-in-the-git-repository).  What this means is that if you remove something from the repo (or even change something to run in a different namespace), it will not clean-up the removed item.  This is a task that you must manually do.

To remove HelmRelease type entities from flux, you must manually delete the helmrelease object, e.g. to clean-up a helm release named `forwardauth`.  This should properly remove the helm chart and associated objects

```shell
kubectl -n kube-system delete helmrelease/forwardauth
```

### Secrets & Sensitive information

* [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) works really well for encrypting secret and sensitive information for certain situations:
  * Kubernetes `Secret` primitives
  * The usage of those primitives in _Deployments_ ENV variables and volume mounts
  * Helm chart `values.yaml` merging: You can leverage flux & sealed-secrets to automatically merge-in a secured set of values into the helm deployment
* Securing other sensitive things that don't fall into the above categories must be handled manually outside of Flux
