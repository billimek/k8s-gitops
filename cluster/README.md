# HA cluster setup with rancher/rke

## VMs

See [proxmox instruction](proxmox/README.md) for creating the nodes.  Eventually this should be handled by terraform.

## loadbalancer (haproxy)

Configure haproxy to use the new k8s nodes with the following in the configuration:

```haproxy
frontend k8s-ha-api
 bind 10.0.7.30:6443
 mode tcp
 option tcplog
 default_backend k8s-ha-api

backend k8s-ha-api
 mode tcp
 option tcp-check
 balance roundrobin
 server k8s-a 10.2.0.10:6443 check fall 3 rise 2
 server k8s-b 10.2.0.11:6443 check fall 3 rise 2
 server k8s-c 10.2.0.12:6443 check fall 3 rise 2
```

* 10.0.7.30 (lb-ha) is a VIP that floats between 10.0.7.10 and 10.0.7.16 via keepalived
* 10.2.0.10. 10.2.0.11, 10.2.0.12 are the master nodes where the kube-apiserver runs

Configure haproxy to route http and https to traefik:

```haproxy
frontend https_frontend
    bind 10.0.7.30:443
    option tcplog
    mode tcp
    option clitcpka
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }
    use_backend https_k8s_traefik if { req_ssl_sni -m end .mydomain.com }

backend https_k8s_traefik
    option tcp-check
    balance source
    server     metallb-150 10.2.0.150:443 check

frontend http_frontend
    bind 10.0.7.30:1080
    mode http
    default_backend http_k8s_backend

backend http_k8s_backend
    mode http
    balance source
    server      metallb-150 10.2.0.150:80 check
```

* 10.2.0.150 is the metallb-assigned IP for traefik


## kubernetes cluster orchestration

Using rke, followed [this documentation](https://rancher.com/docs/rke/v0.1.x/en/).  NOT deploying the full-blown rancher tool at this time.

```shell
rke up --config ./cluster.yml
```

Afterwards, edit the generated `kube_config_cluster.yaml` file and change the `server` definition from `"https://10.2.0.10:6443"` to `"https://10.0.7.30:6443"` in order to leverage the load balancer.

`export KUBECONFIG=$(pwd)/kube_config_cluster.yaml` to start using the new cluster immediatley.  This can also be copied to `~/.kub/config`

## helm

Install helm:

For a given kubernetes cluster, ensure that [helm is installed](https://docs.helm.sh/using_helm/),

```shell
kubectl -n kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller
```

## flux

* Install flux.  Where `git.url` should define the repo where the GitOps code lives:

```shell
helm repo add weaveworks https://weaveworks.github.io/flux
helm upgrade --install flux --set rbac.create=true --set helmOperator.create=true --set helmOperator.updateChartDeps=false --set git.url=git@github.com:billimek/k8s-gitops --set additionalArgs="{--connect=ws://fluxcloud}" --namespace flux weaveworks/flux
```

* Once flux is installed, [get the SSH key and give it write access to the github repo](https://github.com/weaveworks/flux/blob/master/site/helm-get-started.md#giving-write-access):

```shell
kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '"' -f2
```

* Add the key to the repo as a deploy key with write access as [described in the instructions](https://github.com/weaveworks/flux/blob/master/site/helm-get-started.md#giving-write-access)

## kubeseal

### brand-new cluster

If this is brand-new, get the new public cert via,

```shell
kubeseal --fetch-cert \
--controller-namespace=kube-system \
--controller-name=sealed-secrets \
>! pub-cert.pem
```

### restoring existing key

If desiring to restore the existing kubeseal key,

```shell
kubectl replace -f master.key --force
kubectl delete pod -n kube-system -l name=sealed-secrets-controller
```

## bootstrapping traefik

See the [cert-manager backup/restore documentation](https://docs.cert-manager.io/en/latest/tasks/backup-restore-crds.html) for backing-up and restoring the data when migrating.
