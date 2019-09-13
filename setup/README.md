
Function to handle variable subsitution on the fly:

```shell
kseal() {
    name=$(basename -s .txt "$@")
    envsubst < "$@" > values.yaml | kubectl -n kube-system create secret generic "$name" --from-file=values.yaml --dry-run -o json | kubeseal --format=yaml --cert=/../pub-cert.pem && rm values.yaml
}
```

## Bootstrap the gitops cluster

This will automatically create the limited number of manual `kubectl apply` steps and invoke the `bootstrap-vault.sh` script (see below)

```shell
./bootstrap.sh
```

## Bootstrap just vault

This will:

* Initial setup of vault
* Configure vault (if needed) to work with the vault-secrets-operator
* Write all necessary secrets into vault

```shell
./bootstrap-vault.sh
```
