#!/bin/bash

# trap "exit" INT TERM
# trap "kill 0" EXIT

export REPO_ROOT=$(git rev-parse --show-toplevel)
export REPLIACS="0 1 2"

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "vault"
need "kubectl"
need "sed"
need "jq"

. "$REPO_ROOT"/setup/.env

message() {
  echo -e "\n######################################################################"
  echo "# $1"
  echo "######################################################################"
}

initVault() {
  message "initializing and unsealing vault-transit (if necesary)"
  VAULT_READY=1
  while [ $VAULT_READY != 0 ]; do
    kubectl -n kube-system wait --for condition=Initialized pod/vault-transit-0 > /dev/null 2>&1
    VAULT_READY="$?"
    if [ $VAULT_READY != 0 ]; then 
      echo "waiting for vault pod to be somewhat ready..."
      sleep 10; 
    fi
  done
  sleep 2

  VAULT_READY=1
  while [ $VAULT_READY != 0 ]; do
    init_status=$(kubectl -n kube-system exec "vault-transit-0" -- vault status -format=json 2>/dev/null | jq -r '.initialized')
    if [ "$init_status" == "false" ] || [ "$init_status" == "true" ]; then
      VAULT_READY=0
    else
      echo "vault pod is almost ready, waiting for it to report status"
      sleep 5
    fi
  done

  sealed_status=$(kubectl -n kube-system exec "vault-transit-0" -- vault status -format=json 2>/dev/null | jq -r '.sealed')
  init_status=$(kubectl -n kube-system exec "vault-transit-0" -- vault status -format=json 2>/dev/null | jq -r '.initialized')

  if [ "$init_status" == "false" ]; then
    echo "initializing vault"
    vault_init=$(kubectl -n kube-system exec "vault-transit-0" -- vault operator init -format json -key-shares=1 -key-threshold=1) || exit 1
    export VAULT_TRANSIT_RECOVERY_TOKEN=$(echo $vault_init | jq -r '.unseal_keys_b64[0]')
    export VAULT_TRANSIT_ROOT_TOKEN=$(echo $vault_init | jq -r '.root_token')
    echo "VAULT_TRANSIT_RECOVERY_TOKEN is: $VAULT_TRANSIT_RECOVERY_TOKEN"
    echo "VAULT_TRANSIT_ROOT_TOKEN is: $VAULT_TRANSIT_ROOT_TOKEN"

    # sed -i operates differently in OSX vs linux
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "darwin system"
        sed -i '' "s~VAULT_TRANSIT_ROOT_TOKEN=\".*\"~VAULT_TRANSIT_ROOT_TOKEN=\"$VAULT_TRANSIT_ROOT_TOKEN\"~" "$REPO_ROOT"/setup/.env
        sed -i '' "s~VAULT_TRANSIT_RECOVERY_TOKEN=\".*\"~VAULT_TRANSIT_RECOVERY_TOKEN=\"$VAULT_TRANSIT_RECOVERY_TOKEN\"~" "$REPO_ROOT"/setup/.env
    else
        echo "non-darwin (linux?) system"
        sed -i'' "s~VAULT_TRANSIT_ROOT_TOKEN=\".*\"~VAULT_TRANSIT_ROOT_TOKEN=\"$VAULT_TRANSIT_ROOT_TOKEN\"~" "$REPO_ROOT"/setup/.env
        sed -i'' "s~VAULT_TRANSIT_RECOVERY_TOKEN=\".*\"~VAULT_TRANSIT_RECOVERY_TOKEN=\"$VAULT_TRANSIT_RECOVERY_TOKEN\"~" "$REPO_ROOT"/setup/.env
    fi
    echo "SAVE THESE VALUES!"

    FIRST_RUN=0
  fi

  if [ "$sealed_status" == "true" ]; then
    echo "unsealing vault"
    for replica in $REPLIACS; do
      echo "unsealing vault-transit-${replica}"
      kubectl -n kube-system exec "vault-transit-${replica}" -- vault operator unseal "$VAULT_TRANSIT_RECOVERY_TOKEN" || exit 1
    done
  fi
}

portForwardVault() {
  message "port-forwarding vault"
  kubectl -n kube-system port-forward svc/vault-transit 8200:8200 >/dev/null 2>&1 &
  VAULT_FWD_PID=$!
  sleep 5
}

loginVault() {
  message "logging into vault"
  if [ -z "$VAULT_TRANSIT_ROOT_TOKEN" ]; then
    echo "VAULT_TRANSIT_ROOT_TOKEN is not set! Check $REPO_ROOT/setup/.env"
    exit 1
  fi

  vault login -no-print "$VAULT_TRANSIT_ROOT_TOKEN" || exit 1

  vault auth list >/dev/null 2>&1
  if [[ "$?" -ne 0 ]]; then
    echo "not logged into vault!"
    echo "1. port-forward the vault service (e.g. 'kubectl -n kube-system port-forward svc/vault-transit 8200:8200 &')"
    echo "2. set VAULT_ADDR (e.g. 'export VAULT_ADDR=http://localhost:8200')"
    echo "3. login: (e.g. 'vault login <some token>')"
    exit 1
  fi
}

setupVaultTransitServer() {
  message "configuring vault-transit for transit operation"
  vault secrets enable transit
  vault write -f transit/keys/autounseal

  # Create an 'autounseal' policy
  cat <<EOF | vault policy write autounseal -
  path "transit/encrypt/autounseal" {
    capabilities = [ "update" ]
  }

  path "transit/decrypt/autounseal" {
    capabilities = [ "update" ]
  }
EOF
}

createVaultUnsealToken() {
  message "generating unseal token"

  # Create a client token with autounseal policy attached and response wrap it with TTL of 600 seconds.
  export WRAPPING_TOKEN=$(vault token create -policy="autounseal" -wrap-ttl=600 -format json | jq -r '.wrap_info.token') || exit 1

  # unwrap the autounseal token and capture the client token
  export VAULT_UNSEAL_TOKEN=$(VAULT_TOKEN="$WRAPPING_TOKEN" vault unwrap -format json | jq -r '.auth.client_token') || exit 1

  # persist the VAULT_UNSEAL_TOKEN in the .env file
  # sed -i operates differently in OSX vs linux
  if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "darwin system"
      sed -i '' "s~VAULT_UNSEAL_TOKEN=\".*\"~VAULT_UNSEAL_TOKEN=\"$VAULT_UNSEAL_TOKEN\"~" "$REPO_ROOT"/setup/.env
  else
      echo "non-darwin (linux?) system"
      sed -i'' "s~VAULT_UNSEAL_TOKEN=\".*\"~VAULT_UNSEAL_TOKEN=\"$VAULT_UNSEAL_TOKEN\"~" "$REPO_ROOT"/setup/.env
  fi

  kubectl --namespace kube-system delete secret vault > /dev/null 2>&1
  kubectl --namespace kube-system create secret generic vault --from-literal=vault-unwrap-token="$VAULT_UNSEAL_TOKEN"
}

FIRST_RUN=1
export KUBECONFIG="$REPO_ROOT/setup/kubeconfig"
export VAULT_ADDR='http://127.0.0.1:8200'
initVault
portForwardVault
loginVault
if [ $FIRST_RUN == 0 ]; then 
  setupVaultTransitServer
fi
createVaultUnsealToken

kill $VAULT_FWD_PID
