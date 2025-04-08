### GitOps Workflow for Kubernetes Cluster

![](https://i.imgur.com/KHFP4uR.png)

Leverages [flux](https://github.com/fluxcd/flux2) to automate cluster state using code residing in this repo

## :computer:&nbsp; Infrastructure

See the [talos cluster setup](setup/talos/README.md) for more detail about hardware and infrastructure

## :gear:&nbsp; Setup

See [setup](setup/README.md) for more detail about setup & bootstrapping a new cluster

## :wrench:&nbsp; Workloads (by namespace in kubernets/)

* [cert-manager](kubernets/cert-manager/)
* [default](kubernets/default/)
* [flux-system](kubernets/flux-system/)
* [kube-system](kubernets/kube-system/)
* [monitoring](kubernets/monitoring/)
* [rook-ceph](kubernets/rook-ceph/)
* [system-upgrade](kubernets/system-upgrade/)

## :robot:&nbsp; Automation

* [Renovate](https://github.com/renovatebot/renovate) keeps workloads up-to-date by scanning the repo and opening pull requests when it detects a new container image update or a new helm chart
- [System Upgrade Controller](https://github.com/rancher/system-upgrade-controller) automatically upgrades talos and kubernetes to new versions as they are released

## :handshake:&nbsp; Community

There is a k8s@home [Discord](https://discord.gg/7PbmHRK) for this community.
