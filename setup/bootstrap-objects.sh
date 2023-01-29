#!/bin/bash

REPO_ROOT=$(git rev-parse --show-toplevel)

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "kubectl"
need "op"

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
  # . "$REPO_ROOT"/setup/.env

  op whoami > /dev/null 2>&1
  OP_SIGNEDIN=$?
  if [ $OP_SIGNEDIN != 0 ]; then
    echo -e "1password (op CLI) is not signed-in, aborting!"
    exit 1
  fi

  message "fetching secrets from 1Password vault"

  OP_ACCESS_TOKEN=$(op read "op://Personal/bspprtu7bu7qlnodme2hbfuoh4/credential")
  OP_CREDENTIALS_JSON=$(op document get "homelab Credentials File" | base64 | tr '/+' '_-' | tr -d '=' | tr -d '\n')
  DOCKER_USERNAME=$(op read "op://kubernetes/docker/username")
  DOCKER_TOKEN=$(op read "op://kubernetes/docker/add more/DOCKER_TOKEN")
  DOCKER_EMAIL=$("op read op://kubernetes/docker/add more/email")

  message "installing manual secrets and objects"

  ##########
  # secrets
  ##########
  kubectl -n kube-system create secret docker-registry registry-creds-secret --namespace kube-system --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_TOKEN --docker-email=$DOCKER_EMAIL
  kubectl -n kube-system create secret generic op-credentials --from-literal=1password-credentials.json="$(echo $OP_CREDENTIALS_JSON)"
  kubectl -n kube-system create secret generic onepassword-token --from-literal=token="$(echo $OP_ACCESS_TOKEN)"

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
