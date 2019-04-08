# cert-manager

[cert-manager](https://github.com/jetstack/cert-manager) for natively automatically obtaining and renewing LetsEncrypt certificates

* [cert-manager.yaml](cert-manager.yaml)
* [cert-manager-chart.yaml](cert-manager-chart.yaml)
* [cert-sync.yaml](cert-sync.yaml)
* [cert-manager-letsencrypt.txt](../manual-steps/yamls/cert-manager-letsencrypt.txt)

# traefik

![](https://i.imgur.com/gwienvX.png)

traefik in HA-mode (multiple replicas) leveraging cert-manager as the central cert store

* [traefik.yaml](traefik.yaml)

# descheduler

Automatically re-distribute pods based on node resource availability. See [this]( https://github.com/kubernetes-incubator/descheduler) and [this](https://akomljen.com/meet-a-kubernetes-descheduler/)

* [descheduler.yaml](descheduler.yaml)

# fluxcloud

![](https://i.imgur.com/yixxNm9.png)

Send messages to slack for flux events

* [fluxcloud.yaml](fluxcloud.yaml)

# OAuth

oAuth using [forwardauth for Auth0](https://github.com/dniel/traefik-forward-auth0)

* [forwardauth.yaml](forwardauth.yaml)

# Heapster

Metrics that actually works for kubernetes-dashboard. This may stop working in kubernetes 1.13

* [heapster.yaml](heapster.yaml)

# kubernetes dashboard

![](https://i.imgur.com/Jl1blwE.png)

* [kubernetes-dashboard.yaml](kubernetes-dashboard.yaml)

# kured

![](https://i.imgur.com/wYWTMGI.png)

Automatically drain and reboot nodes when a reboot is required (e.g. a kernel update was applied): https://github.com/weaveworks/kured

* [kured.yaml](kured.yaml)

# metallb

[Run your own on-prem LoadBalancer](https://metallb.universe.tf/)

* [metallb.yaml](metallb.yaml)

# sealed-secrets

[Handle encryption of secrets for GitOps workflows](https://github.com/bitnami-labs/sealed-secrets)

* [sealed-secrets.yaml](sealed-secrets.yaml)