
Function to handle variable subsitution on the fly:

```shell
kseal() {
    name=$(basename -s .txt "$@")
    envsubst < "$@" >! values.yaml | kubectl -n kube-system create secret generic "$name" --from-file=values.yaml --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem >! "$name".yaml && rm values.yaml
}
```

Create all of the secret files:

```shell
kubectl create secret generic fluxcloud --from-literal=slack_url="$SLACK_WEBHOOK_URL" --namespace flux --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem >! fluxcloud.yaml

kubectl create secret generic traefik-basic-auth-jeff --from-literal=auth="$TRAEFIK_AUTH" --namespace kube-system --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem >! basic-auth-jeff-kube-system.yaml

kubectl create secret generic traefik-basic-auth-jeff --from-literal=auth="$TRAEFIK_AUTH" --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem >! basic-auth-jeff.yaml

kseal values-to-encrypt/consul-values.txt

kseal values-to-encrypt/traefik-values.txt

kseal values-to-encrypt/kubernetes-dashboard-values.txt
```