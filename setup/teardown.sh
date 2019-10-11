#!/bin/bash

K3S_MASTER="k3s-0"
K3S_WORKERS_AMD64="k3s-1 k3s-2"
K3S_WORKERS_RPI="pi4-a pi4-b pi4-c"

REPO_ROOT=$(git rev-parse --show-toplevel)
export KUBECONFIG="$REPO_ROOT/setup/kubeconfig"

server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
echo "This is a desructive action that will delete everything and remove the kubernetes cluster served by $server"
while true; do
    read -p "Are you SURE you want to run this? (y/n) " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

message() {
  echo -e "\n######################################################################"
  echo "# $1"
  echo "######################################################################"
}

# Attempt to delete all namespaces and pvcs prior to tearing-down the cluster. The reason for this is to allow the nfs-client provisioner a change to 'archive' the storage directories
message "Deleting all pods & pvcs"
for ns in $(kubectl get ns --field-selector="status.phase==Active" --no-headers -o "custom-columns=:metadata.name"); do
  kubectl delete namespace "$ns" --wait=false
done
kubectl -n default delete deployments,statefulsets,daemonsets --force --grace-period=0 --all
kubectl -n kube-system delete statefulsets,daemonsets --force --grace-period=0 --all
# kubectl -n default delete pvc --force --grace-period=0 --all
# kubectl -n kube-system delete pvc --force --grace-period=0 --all
sleep 10
kubectl -n kube-system delete deployments --all

# raspberry pi4 worker nodes
for node in $K3S_WORKERS_RPI; do
  message "tearing-down rpi $node"
  ssh -o "StrictHostKeyChecking=no" pi@"$node" "k3s-agent-uninstall.sh && sudo rm -rf /mnt/usb/var/lib/rancher"
done

# amd64 worker nodes
for node in $K3S_WORKERS_AMD64; do
  message "tearing-down amd64 $node"
  ssh -o "StrictHostKeyChecking=no" ubuntu@"$node" "k3s-agent-uninstall.sh && sudo rm -rf /var/lib/rook"
done

# k3s master node
message "removing k3s from $K3S_MASTER"
ssh -o "StrictHostKeyChecking=no" ubuntu@"$K3S_MASTER" "/usr/local/bin/k3s-uninstall.sh && sudo rm -rf /var/lib/rook"

message "all done - everything is removed!"
