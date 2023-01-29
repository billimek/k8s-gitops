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

`velero` is used as the backup mechanism.  However, as an alternative for situations where it is, unfortunately, necessary to backup & restore a persistent volume (e.g. completely removing a chart that leverages a persistent volume), the [`backup.sh`](backup.sh) and [`restore.sh`](restore.sh) scripts may be used.  Examine to scripts to learn more.
