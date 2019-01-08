
Function to handle variable subsitution on the fly:

```shell
kseal() {
    name=$(basename -s .txt "$@")
    envsubst < "$@" > values.yaml | kubectl -n kube-system create secret generic "$name" --from-file=values.yaml --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem && rm  values.yaml
}
```

Create all of the secret files - should be a one-time activity unless there is a specific change:

```shell
./create_secrets.sh
```

Manually apply the various yaml files that need env variable subsitition:

**NOTA BENE: Wait to run this until _after_ traefik has completed obtaining wildcard certs**

```shell
./create_yamls.sh
```