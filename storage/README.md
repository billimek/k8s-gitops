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

Using the [rook](https://rook.io/) operator to provision a distributed storage cluster using [ceph](https://ceph.com/)

![](https://i.imgur.com/v3I5BX7.png)

This will use any un-partitioned block devices on the nodes to act as distributed disks for the ceph storage cluster

* [rook](rook/)

# stash

[stash](https://appscode.com/products/stash/) for backing-up persistent storage volumes and cluster data

* [stash](stash/)
