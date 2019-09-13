# HA cluster setup with rancher/rke

## Node setup

See the [rke VM setup instructions](https://github.com/billimek/homelab-infrastructure/blob/master/rke/README.md) in the [homelab-infrastructure](https://github.com/billimek/homelab-infrastructure) repo.

## kubernetes cluster orchestration

Using rke, followed [this documentation](https://rancher.com/docs/rke/v0.1.x/en/).  NOT deploying the full-blown rancher tool at this time.

```shell
rke up --config ./cluster.yml
```

Afterwards, edit the generated `kube_config_cluster.yaml` file and change the `server` definition from `"https://10.2.0.10:6443"` to `"https://10.0.7.30:6443"` in order to leverage the load balancer.

`export KUBECONFIG=$(pwd)/kube_config_cluster.yaml` to start using the new cluster immediatley.  This can also be copied to `~/.kub/config`

## helm

Install helm:

For a given kubernetes cluster, ensure that [helm is installed](https://docs.helm.sh/using_helm/),

```shell
kubectl -n kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller
```

## flux

* Install flux.  Where `git.url` should define the repo where the GitOps code lives:

```shell
helm repo add weaveworks https://weaveworks.github.io/flux
helm upgrade --install flux \
  --set helmOperator.create=true \
  --set git.url=git@github.com:billimek/k8s-gitops \
  --set additionalArgs="{--connect=ws://fluxcloud}" \
  --set prometheus.enabled=true \
  --set syncGarbageCollection.enabled=true \
  --set syncGarbageCollection.dry=true \
  --set helmOperator.createCRD=true \
  --set registry.rps=1 \
  --set registry.burst=1 \
  --namespace flux fluxcd/flux
```

* Once flux is installed, [get the SSH key and give it write access to the github repo](https://github.com/weaveworks/flux/blob/master/site/helm-get-started.md#giving-write-access):

```shell
kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '"' -f2
```

* Add the key to the repo as a deploy key with write access as [described in the instructions](https://github.com/weaveworks/flux/blob/master/site/helm-get-started.md#giving-write-access)

## bootstrapping traefik

See the [cert-manager backup/restore documentation](https://docs.cert-manager.io/en/latest/tasks/backup-restore-crds.html) for backing-up and restoring the data when migrating.
