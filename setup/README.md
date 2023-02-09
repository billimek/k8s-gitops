# Light-weight mixed-architecture cluster setup with k3s

## installation (one-time actions)

### k3s node installation

See [k3s bootstrapping](https://github.com/billimek/homelab-infrastructure/tree/master/k3s) for details on creating the k3s cluster itself

Once a cluster is in-place, ensure that the `$KUBECONFIG` environment variable is set properly, or the target cluster is set in the `~/.kube/config` file.

```shell
./bootstrap-cluster.sh
```

This [script](bootstrap-cluster.sh) does several things:

1. Installs flux2
1. Stages the 1Password connect credentials into secrets for later use
1. Stages the Docker registry access information into secrets for later use

## cluster maintenance

### `.env` file

<deprecateed>

### objects

To apply necessary changes to kubernetes native objects, run [bootstrap-objects.sh](bootstrap-objects.sh):

```shell
./bootstrap-objects.sh
```

### secrets updates

Leverages a 1Paswsword vault to persist secrets that are read dynamically via [external-secrets](https://external-secrets.io) & [1Password connect](https://github.com/1Password/connect)

### backup & restore

`volsync` is used as the backup mechanism.  See the `Taskfile.yml` at the root of the repo for a scripted way to manually backup and restore workloads.
