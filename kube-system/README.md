# consul

Deployed in support of running vault in HA mode.  Will likely deprecate whenever the [vault raft storage](https://www.vaultproject.io/docs/configuration/storage/raft.html) support is baked-in to the vault chart.

* [consul/consul.yaml](consul/consul.yaml)

# Intel GPU Plugin

Leverage Intel-based iGPU via the [gpu plugin](https://github.com/intel/intel-device-plugins-for-kubernetes/tree/master/cmd/gpu_plugin) DaemonSet for serving-up GPU-based workloads (e.g. Plex) via the `gpu.intel.com/i915` node resource

* [intel-gpu_plugin/intel-gpu_plugin.yaml](intel-gpu_plugin/intel-gpu_plugin.yaml)

# kured

![](https://i.imgur.com/wYWTMGI.png)

Automatically drain and reboot nodes when a reboot is required (e.g. a kernel update was applied): https://github.com/weaveworks/kured

* [kured/kured.yaml](kured/kured.yaml)
* [kured/kured-helm-values.yaml](kured/kured-helm-values.yaml)

# metallb

[Run your own on-prem LoadBalancer](https://metallb.universe.tf/)

* [metallb/metallb.yaml](metallb/metallb.yaml)

# nfs-client-provisioner

Using the [nfs-client storage type](https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client)

* [nfs-client-provisioner/fs-client-provisioner.yaml](nfs-client-provisioner/nfs-client-provisioner.yaml)

# nfs-pv

nfs-based persistent mounts for various pod access (media mount & data mount)

* [nfs-pv/](nfs-pv/)

# nginx

![](https://i.imgur.com/b21MHEE.png)

nginx-ingress controller leveraging cert-manager as the central cert store for the wildcard certificate

* [nginx/](nginx/)

# oauth2-proxy

[OAuth2 authenticating proxy](https://github.com/pusher/oauth2_proxy) leveraging Auth0

* [oauth2-proxy/](oauth2-proxy/)

# vault

[vault-helm chart](https://github.com/hashicorp/vault-helm) deployed in HA mode leveraging consul as the storage backend

* [vault/vault-ha.yaml](vault/vault-ha.yaml)

## Vault transit unseal server

* [vault/vault-transit.yaml](vault/vault-transit.yaml)

Vault is implemented with a [transit seal type](https://www.vaultproject.io/docs/configuration/seal/transit.html) with a dedicated 'transit' vault server also running in kubernetes cluster.  This is not ideal and is only done to help automate the unsealing of the 'real' vault server.

TODO: explore alternative vault unseal approaches (sidecar to auto unseal, selfhosted KMS server, etc)

Automation inspired from [auto unseal with transit guide](https://learn.hashicorp.com/vault/operations/autounseal-transit).  The [vault/vault-transit.yaml](vault/vault-transit.yaml) chart will deploy an HA vault server whos only purpose is to act as a transit server for the `vault-ha` server with the actual data.  See [../setup/bootstrap-vault-transit.sh](../setup/bootstrap-vault-transit.sh) for how the transit server configuration is automated.

## Vault HA server

* [vault/vault-ha.yaml](vault/vault-ha.yaml)

See the [vault/vault-ha.yaml](vault/vault-ha.yaml) & [../setup/bootstrap-vault.sh](../setup/bootstrap-vault.sh) files for reference on how these are implemented in this cluster.  The server leverages the vault-transit server to automatically unseal as needed.

# vault-secrets-operator

[vault-secrets-operator](https://github.com/ricoberger/vault-secrets-operator)

* [vault-secrets-operator/vault-secrets-operator.yaml](vault-secrets-operator/vault-secrets-operator.yaml)

## Setup

The setup is automatically handled during cluster bootstrapping.  See [bootstrap-vault.sh](../setup/bootstrap-vault.sh) for more detail.

If configuring manually, follow the [vault-secrets-operator guide](https://github.com/ricoberger/vault-secrets-operator/blob/master/README.md) which is mostly the following:

```shell
# if not logged in to vault already:
kubectl -n kube-system port-forward svc/vault 8200:8200 &
export VAULT_ADDR='http://127.0.0.1:8200'
vault login <root token>

# enable kv secrets type
vault secrets enable -path=secrets -version=1 kv

# create read-only policy for kubernetes
cat <<EOF | vault policy write vault-secrets-operator -
path "secrets/*" {
  capabilities = ["read"]
}
EOF

export VAULT_SECRETS_OPERATOR_NAMESPACE=$(kubectl -n kube-system get sa vault-secrets-operator -o jsonpath="{.metadata.namespace}")
export VAULT_SECRET_NAME=$(kubectl -n kube-system get sa vault-secrets-operator -o jsonpath="{.secrets[*]['name']}")
export SA_JWT_TOKEN=$(kubectl -n kube-system get secret $VAULT_SECRET_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
export SA_CA_CRT=$(kubectl -n kube-system get secret $VAULT_SECRET_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
export K8S_HOST=$(kubectl -n kube-system config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Verify the environment variables
env | grep -E 'VAULT_SECRETS_OPERATOR_NAMESPACE|VAULT_SECRET_NAME|SA_JWT_TOKEN|SA_CA_CRT|K8S_HOST'

vault auth enable kubernetes

# Tell Vault how to communicate with the Kubernetes cluster
vault write auth/kubernetes/config \
  token_reviewer_jwt="$SA_JWT_TOKEN" \
  kubernetes_host="$K8S_HOST" \
  kubernetes_ca_cert="$SA_CA_CRT"

# Create a role named, 'vault-secrets-operator' to map Kubernetes Service Account to Vault policies and default token TTL
vault write auth/kubernetes/role/vault-secrets-operator \
  bound_service_account_names="vault-secrets-operator" \
  bound_service_account_namespaces="$VAULT_SECRETS_OPERATOR_NAMESPACE" \
  policies=vault-secrets-operator \
  ttl=24h
```
