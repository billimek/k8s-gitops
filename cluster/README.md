# HA cluster setup with rancher/rke

![](https://i.imgur.com/Qd7f8lx.png)

## VMs

See [proxmox instruction](proxmox/README.md)

## loadbalancer (haproxy)

Configure haproxy to use the new k8s nodes with the following in the configuration:

```
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

(10.0.7.30 (lb-ha) is a VIP that floats between 10.0.7.10 and 10.0.7.16 via keepalived)

## kubernetes cluster orchestration

Using rke, followed [this documentation](https://rancher.com/docs/rke/v0.1.x/en/).  NOT deploying the full-blown rancher tool at this time.

```shell
rke up --config ./cluster.yml
```

Afterwards, edit the generated `kube_config_cluster.yaml` file and change the `server` definition from `"https://10.2.0.10:6443"` to `"https://10.0.7.30:6443"` in order to leverage the load balancer.

`export KUBECONFIG=$(pwd)/kube_config_cluster.yaml` to start using the new cluster immediatley.  This can also be copied to `~/.kub/config`

Install helm:

```shell
kubectl -n kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller
```

Install flux (for gitops):

```shell
helm upgrade --install flux --set rbac.create=true --set helmOperator.create=true --set helmOperator.updateChartDeps=false --set git.url=git@github.com:billimek/k8s-gitops --namespace flux weaveworks/flux
```
