# velero

![](https://i.imgur.com/feo6EpE.png)

[Velero](https://velero.io/) is a cluster backup & restore solution.  I can also leverage restic to backup persistent volumes to S3 storage buckets.

* [velero](velero/)
* [rules/velero.yaml](rules/velero.yaml) - Prometheus alertmanager rules for Velero
* [change-storage-class-config.yaml](change-storage-class-config.yaml) - (disabled) example ConfigMap demonstrating how to restore from one storage class type to a different storage class type
