**DEPRECATION:** This was used originally to help 'migrate' from an rke-provisioned cluster to the (now) k3s-provisioned cluster. Keeping it here for history.

(for context see https://github.com/billimek/k8s-gitops/issues/54)

## pre-flight

1. Pull-request a 'merge/replace' of the k8s-gitops repo with contents from the k3s-gitops repo
1. update k3s-gitops to k8s-gitops pull request to:
   * use 'real' domain name in the .env file
   * 'real' metalLB loadbalancer IPs for nginx
   * configure flux to point to k8s-gitops repo

## cutover

### on rke cluster

1. scale-down flux so that it is not running
1. shut-down (scale to 0) workloads that need to be backed-up - see [scale.sh](scale.sh)
1. backup all necessary workloads - see [backup.sh](backup.sh)
1. drain k8s-4 (odroid-h2 node where the google coral usb device is installed)
1. remove k8s-4 from rke k8s cluster (via editing `cluster.yml` and `rke up`)
1. 'shut down' all cluster nodes
1. merge the k3s-gitops -> k8s-gitops pull request for the cluster migration

### on new k3s cluster

1. bootstrap new k3s cluster - see [bootstrap-cluster.sh](../bootstrap-cluster.sh)
1. ensure that the k8s-4 node is added to the new cluster
1. wait for new cluster to fully-come online (about 15 minutes)
1. shut-down (scale to 0) workloads that need to be restored - see [scale.sh](scale.sh)
1. restore-from-backup necessary workloads - see [backup.sh](backup.sh)
1. scale-up workloads from step 1

