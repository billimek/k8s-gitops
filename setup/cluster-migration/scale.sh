#!/bin/bash

# the purpose of this script is to scale-down certain workloads for eventual backup & restore

SOURCE_DEPLOYMENTS_TO_SCALE="hass-home-assistant mc-minecraft mcsv-minecraft node-red plex-kube-plex radarr rtorrent-flood sonarr unifi"
DEST_DEPLOYMENTS_TO_SCALE="home-assistant mc-minecraft mcsv-minecraft node-red plex-kube-plex radarr rtorrent-flood sonarr unifi"

#### scale-down source things
export KUBECONFIG=$HOME/.kube/config
for deployment in $SOURCE_DEPLOYMENTS_TO_SCALE
do
  echo "scaling-down $deployment"
  kubectl scale deployment "$deployment" --replicas=0
done
kubectl -n monitoring scale deployment influxdb --replicas=0
kubectl -n monitoring scale deployment prometheus-operator-grafana --replicas=0


#### scale-down destination things
export KUBECONFIG=/home/jeff/src/k3s-gitops/setup/kubeconfig
for deployment in $DEST_DEPLOYMENTS_TO_SCALE
do
  echo "scaling-down $deployment"
  kubectl scale deployment "$deployment" --replicas=0
done
kubectl -n monitoring scale deployment influxdb --replicas=0
kubectl -n monitoring scale deployment prometheus-operator-grafana --replicas=0
