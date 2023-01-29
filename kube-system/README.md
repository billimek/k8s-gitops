# coredns

Using this specific [coredns](https://github.com/coredns/coredns) deployment to manage an internal DNS zone for support split-brain DNS for the home network (so that the same host will resolve properly for clients on the internal network as well as the external network).  [This issue](https://github.com/billimek/k8s-gitops/issues/153) explored the problem and landed on this solution.

* [coredns/coredns.yaml](coredns/coredns.yaml)

# descheduler

Leveraging [descheduler](https://github.com/kubernetes-sigs/descheduler) to automatically evict pods that no longer satisfy their NodeAffinity constraints.  This is used to work in concert with `node-feature-discovery` such that when USB devices are moved from one node to a different node, the pods requiring the USB devices will be properly forced to reschedule to the new location

* [descheduler/descheduler.yaml](descheduler/descheduler.yaml)

# external-secrets and 1Password connect

![](https://i.imgur.com/agGzYnK.png)

![](https://i.imgur.com/Z9h2dky.png)

Using [external-secrets](https://external-secrets.io) & [1Password connect](https://github.com/1Password/connect) to reference secrets housed in 1Password

* [external-secrets](external-secrets)

# Intel GPU Plugin

Leverage Intel-based iGPU via the [gpu plugin](https://github.com/intel/intel-device-plugins-for-kubernetes/tree/master/cmd/gpu_plugin) DaemonSet for serving-up GPU-based workloads (e.g. Plex) via the `gpu.intel.com/i915` node resource

* [intel-gpu_plugin/intel-gpu_plugin.yaml](intel-gpu_plugin/intel-gpu_plugin.yaml)

# kured

![](https://i.imgur.com/wYWTMGI.png)

Automatically drain and reboot nodes when a reboot is required (e.g. a kernel update was applied): https://github.com/weaveworks/kured

* [kured/kured.yaml](kured/kured.yaml)
* [kured/kured-helm-values.yaml](kured/kured-helm-values.yaml)

# metallb

[Run your own on-prem LoadBalancer](https://metallb.universe.tf/)

* [metallb/metallb.yaml](metallb/metallb.yaml)

# nfs-client-provisioner

Using the [nfs-client storage type](https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client)

* [nfs-client-provisioner/fs-client-provisioner.yaml](nfs-client-provisioner/nfs-client-provisioner.yaml)

# nfs-pv

nfs-based persistent mounts for various pod access (media mount & data mount)

* [nfs-pv/](nfs-pv/)

# nginx

![](https://i.imgur.com/b21MHEE.png)

[ingress-nginx](https://github.com/kubernetes/ingress-nginx) controller leveraging cert-manager as the central cert store for the wildcard certificate

* [nginx/](nginx/)

# node-feature-discovery

Using the USB feature of [node-feature-discovery](https://github.com/kubernetes-sigs/node-feature-discovery) to dynamically label nodes that contain specific USB devices we care about

* [node-feature-discovery](node-feature-discovery/)

# oauth2-proxy

[OAuth2 authenticating proxy](https://github.com/pusher/oauth2_proxy) leveraging Auth0

* [oauth2-proxy/](oauth2-proxy/)

# registry-creds

[registry-creds](https://github.com/alexellis/registry-creds): Automate Kubernetes registry credentials, to extend Docker Hub limits.  This is (sadly) necessary to have cluster-wide imagePulls use an authenticated Docker account so that the cluster doesn't get rate-limited and become unable to schedule workloads. This has already happened once.

* [registry-creds/](registry-creds)

# reloader

[reloader](https://github.com/stakater/Reloader): A Kubernetes controller to watch changes in ConfigMap and Secrets and do rolling upgrades on Pods with their associated Deployment, StatefulSet, DaemonSet and DeploymentConfig

* [reloader/](reloader/reloader.yaml)
