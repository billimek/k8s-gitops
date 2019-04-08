#!/bin/bash

if [[ -z "$DOMAIN" ]]; then
  echo ".env does not appear to be sourced, sourcing now"
  . ../.env
fi

kapply() {
  # if [[ -z "$NS" ]]; then
  #   NS=default
  # fi
  # envsubst < "$@" | kubectl -n "$NS" apply -f -
  envsubst < "$@" | kubectl apply -f -
}


###################
# traefik-external
###################
for i in yamls/traefik-external/*.txt
do
  kapply $i
done

kapply yamls/rook-dashboard-ingress.txt

kapply yamls/cert-manager-letsencrypt.txt
