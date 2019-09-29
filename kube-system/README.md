# cert-manager

[cert-manager](https://github.com/jetstack/cert-manager) for natively automatically obtaining and renewing LetsEncrypt certificates

* [cert-manager-crds.yaml](cert-manager/cert-manager-crds.yaml)
* [cert-manager-chart.yaml](cert-manager/cert-manager-chart.yaml)
* [cert-sync.yaml](cert-manager/cert-sync.yaml)
* [cert-manager-letsencrypt.txt](../setup/manual-steps/yamls/cert-manager-letsencrypt.txt)

# descheduler

Automatically re-distribute pods based on node resource availability. See [this]( https://github.com/kubernetes-incubator/descheduler) and [this](https://akomljen.com/meet-a-kubernetes-descheduler/)

* [descheduler.yaml](descheduler/descheduler.yaml)

# external ceph

external ceph cluster provided by proxmox accessed using the [ceph rbd provisioner](https://github.com/kubernetes-incubator/external-storage/tree/master/ceph/rbd)

* [external-ceph](external-ceph/)

# Heapster

Metrics that actually works for kubernetes-dashboard. This may stop working in kubernetes 1.13

* [heapster.yaml](heapster/heapster.yaml)

# Intel GPU Plugin

Leverage Intel-based iGPU via the [gpu plugin](https://github.com/intel/intel-device-plugins-for-kubernetes/tree/master/cmd/gpu_plugin) DaemonSet for serving-up GPU-based workloads (e.g. Plex) via the `gpu.intel.com/i915` node resource

* [intel-gpu_plugin.yaml](intel-gpu_plugin/intel-gpu_plugin.yaml)

# kured

![](https://i.imgur.com/wYWTMGI.png)

Automatically drain and reboot nodes when a reboot is required (e.g. a kernel update was applied): https://github.com/weaveworks/kured

* [kured.yaml](kured/kured.yaml)

# local-storage-provisioner

Using the [local volume static storage provisioner](https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner)

* [local-storage-provisioner](local-storage-provisioner/)

Setup requires some manual steps:

1. Attach 'disks' as needed to the k8s nodes.  In proxmox, it was something like this per node to add a 100GB drive: `scsi1: zfs-prox:vm-204-disk-1,discard=on,size=100G,ssd=1`
1. Ensure that [`cluster.yaml`](https://github.com/billimek/k8s-gitops/blob/master/cluster/cluster.yml) has the following setting for the `/mnt` directory and `rke up ...` to apply the change to the cluster:

   ```yaml
   services:
    kubelet:
        extra_binds:
        - "/mnt:/mnt:rshared"
   ```

1. Basically follow [this guide](https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner/blob/master/docs/operations.md#sharing-a-disk-filesystem-by-multiple-filesystem-pvs) for each node (assuming new disk is `/dev/sdb`):

   ```bash
   sudo mkfs.ext4 /dev/sdb

   DISK_UUID=$(sudo blkid -s UUID -o value /dev/sdb)

   sudo mkdir /mnt/$DISK_UUID

   sudo mount -t ext4 /dev/sdb /mnt/$DISK_UUID

   echo UUID=`sudo blkid -s UUID -o value /dev/sdb` /mnt/$DISK_UUID ext4 defaults 0 2 | sudo tee -a /etc/fstab

   for i in $(seq 1 10); do
     sudo mkdir -p /mnt/${DISK_UUID}/vol${i} /mnt/local-disks/${DISK_UUID}_vol${i}; 
     sudo mount --bind /mnt/${DISK_UUID}/vol${i} /mnt/local-disks/${DISK_UUID}_vol${i}; 
   done

   for i in $(seq 1 10); do 
     echo /mnt/${DISK_UUID}/vol${i} /mnt/local-disks/${DISK_UUID}_vol${i} none bind 0 0 | sudo tee -a /etc/fstab
   done
   ```

**Important Note:** The way the local storage provisioner works is such that each PersistentVolume will 'take' one of the `/mnt/local-disks/<uuid>_voln` 'mounts' and create a PV named something like `local-pv-9e858361` which is then consumed by the workload.  If it is necessary to run more than 10 local volume PVs, more 'mounts' will need to be created on the nodes.

# metallb

[Run your own on-prem LoadBalancer](https://metallb.universe.tf/)

* [metallb.yaml](metallb/metallb.yaml)

# nfs-client-provisioner

Using the [nfs-client storage type](https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client)

* [nfs-client-provisioner](nfs-client-provisioner/)

# nfs-pv

nfs-based persistent mouts for various pod access (media mount & data mount)

* [nfs-pv](nfs-pv/)

# traefik

![](https://i.imgur.com/gwienvX.png)

traefik in HA-mode (multiple replicas) leveraging cert-manager as the central cert store

* [traefik.yaml](traefik/traefik.yaml)

# vault

[vault-helm chart](https://github.com/hashicorp/vault-helm)

* [vault/vault.yaml](vault/vault.yaml)

TODO: Implement vault in HA mode ?

## Setup

After deployment, initialize vault via:

```shell
kubectl -n kube-system port-forward svc/vault 8200:8200 &
export VAULT_ADDR='http://127.0.0.1:8200'
vault operator init -recovery-shares=1 -recovery-threshold=1
```

Make note of the unseal key and root token and keep in a very safe place

```shell
vault operator unseal <unseal key from above>
vault login <root token from above>
```

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
