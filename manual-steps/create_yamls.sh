#!/bin/bash

if [[ -z "$DOMAIN" ]]; then
  echo ".env does not appear to be sourced, sourcing now"
  . ../.env
fi

kapply() {
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