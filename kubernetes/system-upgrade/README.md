# System Upgrade Controller

This handles the automatic upgrade of the talos system and kubernetes cluster.  See [system-upgrade-controller](https://github.com/rancher/system-upgrade-controller) for more details on the operation of this component.

* [system-upgrade-controller.yaml](system-upgrade-controller.yaml) - This is the foundational YAML to deploy the controller to make this capability work
* [talos-plan.yaml](talos-plan.yaml) - This Plan will automatically upgrade to the talos system to the defined version which is managed by renovate.
* [kubernetes-plan.yaml](kubernetes-plan.yaml) - This Plan will automatically upgrade to the kubernetes system to the defined version which is managed by renovate.
