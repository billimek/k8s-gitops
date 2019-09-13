#!/bin/bash

REPO_ROOT=$(git rev-parse --show-toplevel)

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "curl"
need "ssh"
need "kubectl"
need "helm"

message() {
  echo -e "\n######################################################################"
  echo "# $1"
  echo "######################################################################"
}

# installHelm() {
#   message "installing helm (tiller)"

#   kubectl -n kube-system create sa tiller
#   kubectl create clusterrolebinding tiller-cluster-rule \
#       --clusterrole=cluster-admin \
#       --serviceaccount=kube-system:tiller
#   helm init --wait --service-account tiller

#   HELM_SUCCESS="$?"
#   if [ "$HELM_SUCCESS" != 0 ]; then
#     echo "helm init failed - no bueno!"
#     exit 1
#   fi
# }

# installFlux() {
#   message "installing flux"
#   # install flux
#   helm repo add fluxcd https://charts.fluxcd.io
#   helm upgrade --install flux --values "$REPO_ROOT"/setup/flux-values.yaml --namespace flux fluxcd/flux

#   FLUX_READY=1
#   while [ $FLUX_READY != 0 ]; do
#     echo "waiting for flux pod to be fully ready..."
#     kubectl -n flux wait --for condition=available deployment/flux
#     FLUX_READY="$?"
#     sleep 5
#   done

#   # grab output the key
#   FLUX_KEY=$(kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '"' -f2)

#   message "adding the key to github automatically"
#   "$REPO_ROOT"/setup/add-repo-key.sh "$FLUX_KEY"
# }

kapply() {
  if output=$(envsubst < "$@"); then
    printf '%s' "$output" | kubectl apply -f -
  fi
}

installManualObjects(){
  . "$REPO_ROOT"/setup/.env

  message "installing manual secrets and objects"
  ##########
  # secrets
  ##########
  kubectl --namespace kube-system delete secret vault > /dev/null 2>&1
  kubectl --namespace kube-system create secret generic vault --from-literal=vault-unwrap-token="$VAULT_UNSEAL_TOKEN"

  #########################
  # cert-manager bootstrap
  #########################
  CERT_MANAGER_READY=1
  while [ $CERT_MANAGER_READY != 0 ]; do
    echo "waiting for cert-manager to be fully ready..."
    kubectl -n kube-system wait --for condition=Available deployment/cert-manager > /dev/null 2>&1
    CERT_MANAGER_READY="$?"
    sleep 5
  done
  kapply "$REPO_ROOT"/kube-system/cert-manager/cert-manager-letsencrypt.txt

  ###################
  # traefik-external
  ###################
  for i in "$REPO_ROOT"/kube-system/traefik/traefik-external/*.txt
  do
    kapply "$i"
  done

}

# installHelm
# installFlux
installManualObjects

# bootstrap vault
"$REPO_ROOT"/setup/bootstrap-vault.sh

message "all done!"
kubectl get nodes -o=wide
