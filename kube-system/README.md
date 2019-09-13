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

# OAuth

oAuth using [forwardauth for Auth0](https://github.com/dniel/traefik-forward-auth0)

* [forwardauth.yaml](forwardauth/forwardauth.yaml)

# Heapster

Metrics that actually works for kubernetes-dashboard. This may stop working in kubernetes 1.13

* [heapster.yaml](heapster/heapster.yaml)

# Intel GPU Plugin

Leverage Intel-based iGPU via the [gpu plugin](https://github.com/intel/intel-device-plugins-for-kubernetes/tree/master/cmd/gpu_plugin) DaemonSet for serving-up GPU-based workloads (e.g. Plex) via the `gpu.intel.com/i915` node resource

* [intel-gpu_plugin.yaml](intel-gpu_plugin/intel-gpu_plugin.yaml)

# kubernetes dashboard

![](https://i.imgur.com/Jl1blwE.png)

* [kubernetes-dashboard.yaml](kubernetes-dashboard/kubernetes-dashboard.yaml)

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

# minio

![](https://i.imgur.com/RF0aYAg.png)

S3-compatible bucket storage service

* [minio.yaml](minio/minio.yaml)

# nfs-client-provisioner

Using the [nfs-client storage type](https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client)

* [nfs-client-provisioner](nfs-client-provisioner/)

# nfs-pv

nfs-based persistent mouts for various pod access (media mount & data mount)

* [nfs-pv](nfs-pv/)

# sealed-secrets

[Handle encryption of secrets for GitOps workflows](https://github.com/bitnami-labs/sealed-secrets)

* [sealed-secrets.yaml](sealed-secrets/sealed-secrets.yaml)

# traefik

![](https://i.imgur.com/gwienvX.png)

traefik in HA-mode (multiple replicas) leveraging cert-manager as the central cert store

* [traefik.yaml](traefik/traefik.yaml)
