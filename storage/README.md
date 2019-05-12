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

# minio

![](https://i.imgur.com/RF0aYAg.png)

S3-compatible bucket storage service

* [minio.yaml](minio.yaml)

# nfs-client-provisioner

Using the [nfs-client storage type](https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client)

* [nfs-client-provisioner](nfs-client-provisioner/)

# nfs-pv

nfs-based persistent mouts for various pod access (media mount & data mount)

* [nfs-pv](nfs-pv/)

# rook ceph

**CURRENTLY NOT USING see https://github.com/billimek/k8s-gitops/issues/3 for details**

Using the [rook](https://rook.io/) operator to provision a distributed storage cluster using [ceph](https://ceph.com/)

![](https://i.imgur.com/v3I5BX7.png)

This will use any un-partitioned block devices on the nodes to act as distributed disks for the ceph storage cluster

* [rook](rook/)

# external ceph

external ceph cluster provided by proxmox accessed using the [ceph rbd provisioner](https://github.com/kubernetes-incubator/external-storage/tree/master/ceph/rbd)

* [external-ceph](external-ceph/)

# stash

[stash](https://appscode.com/products/stash/) for backing-up persistent storage volumes and cluster data

* [stash](stash/)
