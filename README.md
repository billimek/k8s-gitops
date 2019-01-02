# GitOps workflow for kubernetes cluster

Leverage [WeaveWorks Flux](https://github.com/weaveworks/flux) to automate cluster state based on code residing in this repo

## Setup

### Helm

For a given kubernetes cluster, ensure that [helm is installed](https://docs.helm.sh/using_helm/),

```shell
kubectl -n kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller
```

### Flux

Install flux.  Where `git.url` should define the repo where the GitOps code lives:

```shell
helm repo add weaveworks https://weaveworks.github.io/flux
helm upgrade --install flux --set rbac.create=true --set helmOperator.create=true --set helmOperator.updateChartDeps=false --set git.url=git@github.com:billimek/k8s-gitops --namespace flux weaveworks/flux
```

## Caveats

### New namespaces

If you are deploying a helm chart that needs to live in a new namespace, Flux seems to expect that the namespace is already created, or else the helm deployment will fail.  When deploying a helm chart in the traditional approach via the `helm` CLI, it would handle the namespace creation for you.  In Flx, you must explicitly create a helm chart (see [storage/rook/namespace.yaml](storage/rook/namespace.yaml) for an example of this)

### Deletions

[Flux doesn't handle deletions](https://github.com/weaveworks/flux/blob/master/site/faq.md#will-flux-delete-resources-that-are-no-longer-in-the-git-repository).  What this means is that if you remove something from the repo (or even change something to run in a different namespace), it will not clean-up the removed item.  This is a task that you must manually do.

To remove HelmRelease type entities from flux, you must manually delete the helmrelease object, e.g. to clean-up a helm release named `forwardauth`:

```shell
kubectl -n kube-system delete helmrelease/forwardauth
```

### Secrets & Sensitive information

* [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) works really well for encrypting secret and senstive information for certain situations:
  * Kubernetes `Secret` primitives
  * The usage of those primitives in _Deployments_ ENV variables and volume mounts
  * Helm chart `values.yaml` merging: You can leverage flux & sealed-secrets to automatically merge-in a secured set of values into the helm deployment
* Securing other sensitive things that don't fall into the above categories must be handled manually outside of Flux