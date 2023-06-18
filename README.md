### GitOps Workflow for Kubernetes Cluster
![Kubernetes](https://i.imgur.com/p1RzXjQ.png)

## :book:&nbsp; Overview
![](https://i.imgur.com/KHFP4uR.png)

Leverage [Flux2](https://github.com/fluxcd/flux2) to automate cluster state using code residing in this repo

## :computer:&nbsp; Infrastructure

See the [k3s setup](https://github.com/billimek/homelab-infrastructure/tree/master/k3s) in the [homelab-infrastructure repo](https://github.com/billimek/homelab-infrastructure) for more detail about hardware and infrastructure

## :gear:&nbsp; Setup

See [setup](setup/README.md) for more detail about setup & bootstrapping a new cluster

## :wrench:&nbsp; Workloads (by namespace)

* [cert-manager](cert-manager/)
* [default](default/)
* [flux-system-extra](flux-system-extra/)
* [kube-system](kube-system/)
* [logs](logs/)
* [monitoring](monitoring/)
* [networking](networking/)
* [rook-ceph](rook-ceph/)
* [system-upgrade](system-upgrade/)

## :robot:&nbsp; Automation

* [Renovate](https://github.com/renovatebot/renovate) keeps workloads up-to-date by scanning the repo and opening pull requests when it detects a new container image update or a new helm chart
- [Kured](https://github.com/weaveworks/kured) automatically drains & reboots nodes when OS patches are applied requiring a reboot
- [System Upgrade Controller](https://github.com/rancher/system-upgrade-controller) automatically upgrades k3s to new versions as they are released

## :handshake:&nbsp; Community

There is a k8s@home [Discord](https://discord.gg/7PbmHRK) for this community.
