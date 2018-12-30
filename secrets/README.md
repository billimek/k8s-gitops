```shell
kubectl create secret generic fluxcloud --from-literal=slack_url="$SLACK_WEBHOOK_URL" --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem >! fluxcloud.yaml
```