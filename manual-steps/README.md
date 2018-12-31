
Function to handle variable subsitution on the fly:

```shell
kseal() {
    name=$(basename -s .txt "$@")
    envsubst < "$@" > values.yaml | kubectl -n kube-system create secret generic "$name" --from-file=values.yaml --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem && rm  values.yaml
}
```

Create all of the secret files:

```shell
./create_secrets.sh
```