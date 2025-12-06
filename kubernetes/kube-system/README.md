# cilium

![](https://i.imgur.com/3fsHvXY.png)

Popular CNI system that also enables BGP-based cluster loadbalancer: https://github.com/cilium/cilium

Cilium also provides Gateway API support, which has replaced nginx as the primary ingress controller. Two gateways are configured for split-horizon DNS:
- `gateway-public.yaml` - For public/internet DNS records (Cloudflare) pointing to eviljungle.com
- `gateway-internal.yaml` - For internal/local DNS records (OpnSense) pointing to 10.0.6.150

* [cilium/](cilium/)

# coredns

[coredns](https://github.com/coredns/coredns) serves cluster DNS

* [coredns/coredns.yaml](coredns/coredns.yaml)

# csi-driver-nfs

[csi-driver-nfs](https://github.com/kubernetes-csi/csi-driver-nfs) allows accessing NFS shares as a CSI volume.  This is used to provide NFS-based persistent volumes for the cluster.

* [csi-driver-nfs/csi-driver-nfs.yaml](csi-driver-nfs/csi-driver-nfs.yaml)

# descheduler

Leveraging [descheduler](https://github.com/kubernetes-sigs/descheduler) to automatically evict pods that no longer satisfy their NodeAffinity constraints.  This is used to work in concert with `node-feature-discovery` such that when USB devices are moved from one node to a different node, the pods requiring the USB devices will be properly forced to reschedule to the new location

* [descheduler/descheduler.yaml](descheduler/descheduler.yaml)

# external-dns

[external-dns](https://github.com/kubernetes-sigs/external-dns) provides automated DNS management for Kubernetes ingresses and services with dual-provider setup for split-horizon DNS. Manages internal DNS records via OpnSense and external DNS records via Cloudflare for resilient service access.

* [external-dns/](external-dns/)

# external-secrets and 1Password connect

![](https://i.imgur.com/agGzYnK.png)

![](https://i.imgur.com/Z9h2dky.png)

Using [external-secrets](https://external-secrets.io) & [1Password connect](https://github.com/1Password/connect) to reference secrets housed in 1Password

* [external-secrets](external-secrets)

# intel GPU device plugin

Leverage Intel-based iGPU via the [gpu plugin](https://github.com/intel/intel-device-plugins-for-kubernetes/tree/master/cmd/gpu_plugin) DaemonSet for serving-up GPU-based workloads (e.g. Plex) via the `gpu.intel.com/i915` node resource

* [intel-device-plugins/gpu-plugin.yaml](intel-device-plugins/gpu-plugin.yaml)
* [intel-device-plugins/operator.yaml](intel-device-plugins/operator.yaml)

# metrics-server

[metrics-server](https://github.com/kubernetes-sigs/metrics-server) provides cluster-level metrics for things like `kubectl top nodes`, etc

* [metric-server/metric-server.yaml](metric-server/metric-server.yaml)

# node-feature-discovery

Using the USB feature of [node-feature-discovery](https://github.com/kubernetes-sigs/node-feature-discovery) to dynamically label nodes that contain specific USB devices we care about

* [node-feature-discovery](node-feature-discovery/)

# snapshot-controller

[snapshot-controller](https://github.com/kubernetes-csi/external-snapshotter): Sidecar container that watches Kubernetes Snapshot CRD objects and triggers CreateSnapshot/DeleteSnapshot against a CSI endpoint.  Used in conjunction with volsync.

* [snapshot-controller/snapshot-controller.yaml](snapshot-controller/snapshot-controller.yaml)

# spegel

[spegel](https://github.com/spegel-org/spegel): Makes managing and caching docker images much better!

* [spegel/spegel.yaml](spegel/spegel.yaml)

# tailscale operator

[Put things in kubernets on your tailnet!](https://tailscale.com/kb/1236/kubernetes-operator)

* [tailscale/tailscale-operator.yaml](tailscale/tailscale-operator.yaml)

# talos-backup

[talos-backup](https://github.com/siderolabs/talos-backup) is a tool to backup and restore Talos clusters.  It uses the Talos API to get the current state of the cluster and stores it in a backup file.  This is used to backup the Talos control plane nodes.

* [talos-backup/](talos-backup/)

# volsync

[volsync](https://github.com/backube/volsync): Asynchronous data replication for Kubernetes volumes.  Leveraging storage CSI snapshotting and restic, this enables the backing-up of persistent volumes to an S3 bucket.

* [volsync/](volsync/)