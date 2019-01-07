#!/bin/bash

if [[ -z "$DOMAIN" ]]; then
  echo ".env does not appear to be sourced, sourcing now"
  . ../.env
fi

kseal() {
    name=$(basename -s .txt "$@")
    if [[ -z "$NS" ]]; then
      NS=default
    fi
    envsubst < "$@" > values.yaml | kubectl -n "$NS" create secret generic "$name" --from-file=values.yaml --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem && rm values.yaml
}

#################
# secrets
#################
kubectl create secret generic fluxcloud --from-literal=slack_url="$SLACK_WEBHOOK_URL" --namespace flux --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem > ../secrets/fluxcloud.yaml
kubectl create secret generic traefik-basic-auth-jeff --from-literal=auth="$JEFF_AUTH" --namespace kube-system --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem > ../secrets/basic-auth-jeff-kube-system.yaml
kubectl create secret generic traefik-basic-auth-jeff --from-literal=auth="$JEFF_AUTH" --dry-run -o json | kubeseal --format=yaml --cert=../pub-cert.pem > ../secrets/basic-auth-jeff.yaml

###################
# helm chart values
###################

NS=kube-system kseal values-to-encrypt/consul-values.txt > ../secrets/consul-values.yaml
NS=kube-system kseal values-to-encrypt/traefik-values.txt > ../secrets/traefik-values.yaml
NS=kube-system kseal values-to-encrypt/kubernetes-dashboard-values.txt > ../secrets/kubernetes-dashboard-values.yaml
NS=kube-system kseal values-to-encrypt/kured-values.txt > ../secrets/kured-values.yaml
NS=kube-system kseal values-to-encrypt/forwardauth-values.txt > ../secrets/forwardauth-values.yaml

kseal values-to-encrypt/influxdb-values.txt > ../secrets/influxdb-values.yaml
kseal values-to-encrypt/chronograf-values.txt > ../secrets/chronograf-values.yaml
kseal values-to-encrypt/prometheus-values.txt > ../secrets/prometheus-values.yaml
kseal values-to-encrypt/hubot-values.txt > ../secrets/hubot-values.yaml
kseal values-to-encrypt/comcast-values.txt > ../secrets/comcast-values.yaml
kseal values-to-encrypt/uptimerobot-values.txt > ../secrets/uptimerobot-values.yaml
kseal values-to-encrypt/grafana-values.txt > ../secrets/grafana-values.yaml
kseal values-to-encrypt/minio-values.txt > ../secrets/minio-values.yaml
kseal values-to-encrypt/deluge-values.txt > ../secrets/deluge-values.yaml

