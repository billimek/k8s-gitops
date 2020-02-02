#!/bin/bash

# the purpose of this script is to backup source persistent volumes housed in external ceph rbd and restore them in a rook-provisioned cephfs storage solution holding the corresponding persistent volume

# PREREQUISITES & ASSUMPTIONS:
#   1. rook toolbox must be present and the 'shared filesystem tools' must be mounted to /tmp/registry (see https://rook.io/docs/rook/v1.1/direct-tools.html)
#   2. this script needs to be executed as sudo due to permission issues with some of the files being handled
#   3. (reccomended) key-based ssh-access without interactive password
#   4. (HIGHLY RECCOMENDED) source and destination workloads are scaled-to-zero prior to running this

# PVCS_TO_BACKUP="prometheus-prometheus-operator-prometheus-db-prometheus-prometheus-operator-prometheus-0 data-hass-postgresql-postgresql-0 home-assistant unifi prometheus-operator-grafana mcsv-minecraft-datadir mc-minecraft-datadir rtorrent-flood-config radarr-config sonarr-config plex-kube-plex-config"
PVCS_TO_BACKUP=""
BACKUP_LOCATION="/mnt/backups/cluster"

#### backup the stuff from ceph rbd
export KUBECONFIG="$HOME/.kube/config"
for pvc in $PVCS_TO_BACKUP
do
  PV=$(kubectl get pv --all-namespaces | grep "$pvc" | awk '{print $1}')
  CEPH_CSI_THING=$(kubectl describe pv "$PV" | grep VolumeHandle | awk '{print $2}' | sed 's/[0-9]*-[0-9]*-rook-ceph-[0-9]*-\(.*\)/\1/g')
  echo "Backing up $pvc ($CEPH_CSI_THING) to $BACKUP_LOCATION/$pvc"
  tools="$(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')"
  echo "     ----- mapping, mounting, saving contents of $pvc from $CEPH_CSI_THING to /tmp/${pvc}.tar.gz"
  kubectl -n rook-ceph exec -it "$tools" -- sh -c "DEV=\$(rbd map replicapool/csi-vol-$CEPH_CSI_THING) && mkdir -p /tmp/rbd && mount \$DEV /tmp/rbd && cd /tmp/rbd && tar cfz /tmp/${pvc}.tar.gz . && cd /tmp; umount /tmp/rbd && rbd unmap \$DEV"
  echo "     ----- copying $tools:/tmp/${pvc}.tar.gz to $BACKUP_LOCATION/${pvc}.tar.gz"
  kubectl -n rook-ceph cp "$tools:/tmp/${pvc}.tar.gz" "$BACKUP_LOCATION/${pvc}.tar.gz"
  echo "     ----- deleting $tools:/tmp/${pvc}.tar.gz"
  kubectl -n rook-ceph exec -it "$tools" -- sh -c "rm /tmp/${pvc}.tar.gz"
done
