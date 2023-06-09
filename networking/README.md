# coredns

Using this specific [coredns](https://github.com/coredns/coredns) deployment to manage an internal DNS zone for support split-brain DNS for the home network (so that the same host will resolve properly for clients on the internal network as well as the external network).  [This issue](https://github.com/billimek/k8s-gitops/issues/153) explored the problem and landed on this solution.

* [coredns/coredns.yaml](coredns/coredns.yaml)

# metallb

[Run your own on-prem LoadBalancer](https://metallb.universe.tf/)

* [metallb/metallb.yaml](metallb/metallb.yaml)
