#!/bin/bash

REPO_ROOT=$(git rev-parse --show-toplevel)

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "kubectl"
need "helm"
need "flux"

message() {
  echo -e "\n######################################################################"
  echo "# $1"
  echo "######################################################################"
}

installFlux() {
  message "installing fluxv2"
  flux check --pre > /dev/null
  FLUX_PRE=$?
  if [ $FLUX_PRE != 0 ]; then 
    echo -e "flux prereqs not met:\n"
    flux check --pre
    exit 1
  fi
  if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN is not set! Check $REPO_ROOT/setup/.env"
    exit 1
  fi
  flux bootstrap github \
    --owner=billimek \
    --repository=k8s-gitops \
    --branch master \
    --personal

  # install flux
  # kubectl apply -f "$REPO_ROOT"/flux/namespace.yaml
  # kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/v1.2.0/deploy/crds.yaml
  # helm repo add fluxcd https://charts.fluxcd.io
  # helm upgrade --install flux --values "$REPO_ROOT"/flux/flux/flux-values.yaml --namespace flux fluxcd/flux
  # helm upgrade --install helm-operator --values "$REPO_ROOT"/flux/helm-operator/flux-helm-operator-values.yaml --namespace flux fluxcd/helm-operator

  FLUX_READY=1
  while [ $FLUX_READY != 0 ]; do
    echo "waiting for flux pod to be fully ready..."
    # kubectl -n flux wait --for condition=available deployment/flux
    kubectl -n flux-system wait --for condition=available deployment/source-controller
    FLUX_READY="$?"
    sleep 5
  done

  # grab output the key
  # FLUX_KEY=$(kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '"' -f2)

  # message "adding the key to github automatically"
  # "$REPO_ROOT"/setup/add-repo-key.sh "$FLUX_KEY"
}

installFlux
# "$REPO_ROOT"/setup/bootstrap-objects.sh
# "$REPO_ROOT"/setup/bootstrap-vault.sh

message "all done!"
kubectl get nodes -o=wide
