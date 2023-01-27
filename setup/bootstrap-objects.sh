#!/bin/bash

REPO_ROOT=$(git rev-parse --show-toplevel)

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "kubectl"

message() {
  echo -e "\n######################################################################"
  echo "# $1"
  echo "######################################################################"
}

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
  kubectl -n kube-system create secret generic kms-vault --from-literal=account.json="$(echo $VAULT_KMS_ACCOUNT_JSON | base64 --decode)"
  kubectl -n kube-system create secret docker-registry registry-creds-secret --namespace kube-system --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_TOKEN --docker-email=$EMAIL
  kubectl -n kube-system create secret generic op-credentials --from-literal=1password-credentials.json="$(echo $OP_CREDENTIALS_JSON)"
  kubectl -n kube-system create secret generic onepassword-token --from-literal=token="$(echo $OP_ACCESS_TOKEN)"


  ###################
  # nginx
  ###################
  # for i in "$REPO_ROOT"/kube-system/nginx/nginx-external/*.txt
  # do
  #   kapply "$i"
  # done

  ###################
  # rook
  ###################
  ROOK_NAMESPACE_READY=1
  while [ $ROOK_NAMESPACE_READY != 0 ]; do
    echo "waiting for rook-ceph namespace to be fully ready..."
    # this is a hack to check for the namespace
    kubectl -n rook-ceph wait --for condition=Established crd/volumes.rook.io > /dev/null 2>&1
    ROOK_NAMESPACE_READY="$?"
    sleep 5
  done
  kapply "$REPO_ROOT"/rook-ceph/dashboard/ingress.txt

}

export KUBECONFIG="$REPO_ROOT/setup/kubeconfig"
installManualObjects

message "all done!"
