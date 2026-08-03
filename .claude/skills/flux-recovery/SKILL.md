---
name: flux-recovery
description: Recover a stuck HelmRelease, force an ExternalSecret resync, or unblock a Flux reconcile. Use when a HelmRelease is stuck/failed, an ExternalSecret hasn't picked up a changed value, or a Flux reconciliation needs unblocking.
---

# Flux/HelmRelease Troubleshooting

**Stuck HelmRelease**: When a HelmRelease exhausts its upgrade retries (e.g. due to image pull failures or timeout), scale the deployment to 0 to unblock it, then force reconciliation:
```bash
kubectl scale deployment app-name --replicas=0 -n namespace
flux reconcile helmrelease app-name -n namespace --with-source
# Flux will scale it back up automatically on success
```

**Force ExternalSecret resync**: Bypass the secretStore cache when a 1Password value changed but the ExternalSecret hasn't picked it up:
```bash
kubectl annotate externalsecret <name> -n <ns> force-sync=$(date +%s) --overwrite
```

**HelmRelease upgrade recovery**: Before reconciling an upgrade, check for stuck pods from the prior revision and scale the workload to 0 if needed. If a HelmRelease is stuck, prefer `helm rollback` or suspend/resume the HR over retrying reconciliation:
```bash
flux suspend helmrelease app-name -n namespace
flux resume helmrelease app-name -n namespace
```
