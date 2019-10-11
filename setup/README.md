# Light-weight mixed-architecture cluster setup with k3s

## k3s node installation

```shell
./bootstrap-k3s.sh
```

This [script](bootstrap-k3s.sh) does several things:

1. Installs k3s to the master node
1. Installs k3s workers to other nodes (mixed amd64 and arm architecture)
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

## k3s teardown (uninstall everything)

```shell
./teardown-k3s.sh
```

This [script](teardown-k3s.sh) will:

1. Remove all pods and pvcs
1. Uninstall k3s from all worker nodes
1. Uninstall k3s from the master node

(example of the entire process):
[![asciicast](https://asciinema.org/a/266949.png)](https://asciinema.org/a/266949?speed=2)
