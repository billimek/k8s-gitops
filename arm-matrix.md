# ARM-based CPU/OS support for workloads in this repository

(mostly) only workloads with some form of multi-arch image are considered below.  Assuming everything else is amd64 only.

| workload                | armhf (32-bit) | arm64 (64-bit) | image | notes |
|-------------------------|----------------|----------------|-------|-------|
| cert-manager            | X | X | `quay.io/jetstack/cert-manager-controller` | This shipped with release v0.12 |
| consul                  | X | X | `consul` | |
| home-assistant          | X | X | `homeassistant/home-assistant` | The vscode sudecard container is amd64 only |
| minio                   | X | X | `jessestuart/minio` | |
| node-red                | X | X | `nodered/node-red` | |
| nzbget                  | X | X | `linuxserver/nzbget` | |
| pihole                  | X | X | `pihole/pihole` | |
| rabbitmq                | X | X | `rabbitmq` | |
| ser2sock                | X | X | `tenstartups/ser2sock` | Seems to work on arm64 ¯\\\_(ツ)_/¯  |
| radarr                  | X | X | `linuxserver/radarr` | Not running on arm now due to no ceph-csi container support for arm |
| sonarr                  | X | X | `linuxserver/sonarr` | Not running on arm now due to no ceph-csi container support for arm |
| unifi                   | X | X | `linuxserver/unifi-controller` | Not running this image right now - instead running `jacobalberty/unifi` which is amd64-only |
| kured                   | X | X | `billimek/kured` |  |
| metallb                 | X | X | `metallb/speaker` & `metallb/controller` |  |
| metrics-server          |  |  | TBD | [this issue](https://github.com/kubernetes-incubator/metrics-server/issues/181) should enable multi-arch at some point |
| nginx                   |  |  | TBD | [this PR](https://github.com/kubernetes/ingress-nginx/pull/4271) should enable support |
| vault                   | X | X | `vault` |  |
| loki                    | X | X | `grafana/loki` & `grafana/promtail` |  |
| chronograf              | X | X | `chronograf` |  |
| influxdb                | X | X | `influxdb` | Not running on arm now due to memory resource needs |
| prometheus-server       | X | X | `quay.io/prometheus/prometheus` | Can't run on arm because init/sidecard containres are not arm-capable |
| prometheus-alertmanager | X | X | `quay.io/prometheus/alertmanager` | Can't run on arm because init/sidecard containres are not arm-capable |
| grafana                 | X | X | `grafana/grafana` | Can't run on arm because init/sidecard containres are not arm-capable |
| rook                    |  |  |  | No support yet - will be necesary for `csi-rbdplugin` to support arm/arm64 for ceph client workloads to run on arm |
| velero                  | X | X | TBD | [this PR](https://github.com/vmware-tanzu/velero/pull/1768) should enable support |
