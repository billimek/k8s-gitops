# Light-weight mixed-architecture cluster setup with k3s

## installation and teardown (one-time actions)

### k3s node installation

```shell
./bootstrap-cluster.sh
```

This [script](bootstrap-cluster.sh) does several things:

1. Installs k3s to the master node
1. Installs k3s workers to other nodes (mixed amd64 and arm64 architecture)
1. Retrieves the new kubeconfig file and places it in $REPO_ROOT/setup/kubeconfig
1. Installs helm
1. Installs flux
1. Retrieves the new flux public key and saves it to the GitHub repo as a repo key (see [add-repo-key.sh](add-repo-key.sh))
1. Bootstraps the vault-secret-operator with the auto-unwrap token
1. Bootstraps cert-manager with letsencrypt information
1. Bootstraps vault (see [bootstrap-vault.sh](bootstrap-vault.sh) for more detail)
   * Initializes vault if it has not already been initialized
   * Unseals vault
   * Configures vault to accept requests from vault-secrets-operator
   * Writes all secrets (held locally in the `.env` file) to vault for vault-secrets-operator to act on

(example of the entire process):
[![asciicast](https://asciinema.org/a/266944.png)](https://asciinema.org/a/266944?speed=2)

### k3s teardown (uninstall everything)

```shell
./teardown.sh
```

This [script](teardown.sh) will:

1. Remove all pods and pvcs
1. Uninstall k3s from all worker nodes
1. Uninstall k3s from the master node

(example of the entire process):
[![asciicast](https://asciinema.org/a/266949.png)](https://asciinema.org/a/266949?speed=2)

## cluster maintenance

After initial bootstrapping, it will be necessary to run scripts to apply manual changes that can't be natively handled via Flux.  This is for yaml files that need `envsubst` prior to application to the cluster.  This is also for updates to values stored in **vault**.

### `.env` file

There are references to the `.env` file in the below scripts. This file is automatically sourced in order to populate secrets and sensitive information used in the scripts at runtime. This file is also prevented from commits via `.gitignore`.

A sample [.env.sample](.env.sample) file is provided as reference. To use this, `cp .env.sample .env` and make the necessary modifications for the secrets for your particular configuration.

### objects

To apply necessary changes to kubernetes native objects, run [bootstrap-objects.sh](bootstrap-objects.sh):

```shell
./bootstrap-objects.sh
```

### vault updates

To apply new additions or updates to vault, run [bootstrap-vault.sh](bootstrap-vault.sh):

```shell
./bootstrap-vault.sh
```

### backup & restore

`velero` is used as the backup mechanism.  However, as an alternative for situations where it is, unfortunately, necessary to backup & restore a persistent volume (e.g. completely removing a chart that leverages a persistent volume), the [`backup.sh`](backup.sh) and [`restore.sh`](restore.sh) scripts may be used.  Examine to scripts to learn more.
