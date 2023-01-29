#!/bin/bash

REPO_ROOT=$(git rev-parse --show-toplevel)

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "kubectl"
need "helm"
need "flux"
need "op"

message() {
  echo -e "\n######################################################################"
  echo "# $1"
  echo "######################################################################"
}

installFlux() {


  op whoami > /dev/null 2>&1
  OP_SIGNEDIN=$?
  if [ $OP_SIGNEDIN != 0 ]; then
    echo -e "1password (op CLI) is not signed-in, aborting!"
    exit 1
  fi

  message "fetching secrets from 1Password vault"
  GITHUB_TOKEN=$(op read "op://kubernetes/github PAT for flux/password")


  message "installing flux"
  flux check --pre > /dev/null
  FLUX_PRE=$?
  if [ $FLUX_PRE != 0 ]; then
    echo -e "flux prereqs not met:\n"
    flux check --pre
    exit 1
  fi
  if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN is not set! Check $REPO_ROOT/setup/.env or 1Password settings"
    exit 1
  fi
  flux bootstrap github \
    --owner=billimek \
    --repository=k8s-gitops \
    --branch master \
    --private=false \
    --personal \
    --network-policy=false

  FLUX_INSTALLED=$?
  if [ $FLUX_INSTALLED != 0 ]; then
    echo -e "flux did not install correctly, aborting!"
    exit 1
  fi
}

installFlux
"$REPO_ROOT"/setup/bootstrap-objects.sh

message "all done!"
kubectl get nodes -o=wide
