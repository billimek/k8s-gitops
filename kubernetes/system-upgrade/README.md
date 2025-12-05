# Tuppr - Talos Upgrade Controller

This handles automated upgrades of the Talos OS and Kubernetes cluster using [tuppr](https://github.com/home-operations/tuppr), a Talos-native upgrade controller with CEL-based health checks.

## Components

* [tuppr.yaml](tuppr.yaml) - HelmRelease for the tuppr controller
* [talos-upgrade.yaml](talos-upgrade.yaml) - TalosUpgrade CR that automatically upgrades Talos OS to the defined version (managed by Renovate)
* [kubernetes-upgrade.yaml](kubernetes-upgrade.yaml) - KubernetesUpgrade CR that automatically upgrades Kubernetes to the defined version (managed by Renovate)

## Health Checks

Both upgrade resources include CEL-based health checks that verify:

1. **VolSync ReplicationSource** - All sync jobs must have `Synchronizing=False` to prevent upgrades during active PVC backups
2. **CephCluster** - Must report `HEALTH_OK` to prevent upgrades during degraded storage
