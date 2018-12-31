```shell
kubectl create secret generic fluxcloud --from-literal=slack_url="$SLACK_WEBHOOK_URL" --namespace flux --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem >! fluxcloud.yaml

kubectl create secret generic traefik-basic-auth-jeff --from-literal=jeff="$JEFF_AUTH" --namespace kube-system --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem >! basic-auth-jeff-kube-system.yaml

kubectl create secret generic traefik-basic-auth-jeff --from-literal=jeff="$JEFF_AUTH" --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem >! basic-auth-jeff-.yaml
```