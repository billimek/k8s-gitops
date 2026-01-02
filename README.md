# GitOps Workflow for Kubernetes Cluster

![kubefetch](https://i.imgur.com/J62ZnYF.png)

Leverages [flux](https://github.com/fluxcd/flux2) to automate cluster state using code residing in this repo

## :computer:&nbsp; Infrastructure

See the [talos cluster setup](setup/talos/README.md) for more detail about hardware and infrastructure

## :gear:&nbsp; Setup

See [setup](setup/README.md) for more detail about setup & bootstrapping a new cluster

## :wrench:&nbsp; Workloads (by namespace in kubernetes/)

* [cert-manager](kubernetes/cert-manager/)
* [default](kubernetes/default/)
* [flux-system](kubernetes/flux-system/)
* [kube-system](kubernetes/kube-system/)
* [monitoring](kubernetes/monitoring/)
* [rook-ceph](kubernetes/rook-ceph/)
* [system-upgrade](kubernetes/system-upgrade/)

## :robot:&nbsp; Automation

* [Renovate](https://github.com/renovatebot/renovate) keeps workloads up-to-date by scanning the repo and opening pull requests when it detects a new container image update or a new helm chart
* [tuppr](https://github.com/home-operations/tuppr/) automatically upgrades talos and kubernetes to new versions as they are released

## :handshake:&nbsp; Community

There is a k8s@home [Discord](https://discord.gg/7PbmHRK) for this community.
