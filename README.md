# flux-get-started

We published a step-by-step run-through on how to use Flux and Helm Operator [over
here](https://github.com/weaveworks/flux/blob/master/site/helm-get-started.md).

### Workloads

podinfo
* Kubernetes deployment, ClusterIP service and Horizontal Pod Autoscaler
* init container automated image updates (regular expression filter)
* container automated image updates (semantic versioning filter)

### Helm releases

Mongodb
* Source: Helm repository (stable)
* Kubernetes deployment
* automated image updates (semantic versioning filter)

Redis
* Source: Helm repository (stable)
* Kubernetes stateful set 
* locked automated image updates (semantic versioning filter)

Ghost
* Source: Git repository
* disabled automated image updates (glob filter)
* has external dependency - mariadb (stable)

## <a name="help"></a>Getting Help

If you have any questions about, feedback for or problems with `flux-get-started`:

- Invite yourself to the <a href="https://slack.weave.works/" target="_blank">Weave community</a> slack.
- Ask a question on the [#flux](https://weave-community.slack.com/messages/flux/) slack channel.
- Send an email to <a href="mailto:weave-users@weave.works">weave-users@weave.works</a>
- <a href="https://github.com/weaveworks/flux-helm-test/issues/new">File an issue.</a>

Your feedback is always welcome!
