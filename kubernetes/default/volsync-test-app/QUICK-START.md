# PVC Migration Quick Start

## What This Tests

This validates the PVC migration approach for [issue #5125](https://github.com/billimek/k8s-gitops/issues/5125):
- Migrate from Helm dynamic PVC creation (`suffix: data`) to ResourceSet-managed PVCs
- Enable automatic bootstrap restore using `dataSourceRef` and volume populator
- Ensure zero data loss during migration

## Test App Details

- **Name**: volsync-test-app
- **Namespace**: default
- **PVC**: volsync-test-app-data (1Gi)
- **Backup**: Every 10 minutes (for testing)
- **Purpose**: Validates migration approach before applying to production apps

## Quick Start Commands

### 1. Deploy Initial App
```bash
flux reconcile kustomization cluster-apps --with-source
kubectl wait pod --for=condition=ready -l app.kubernetes.io/instance=volsync-test-app -n default --timeout=5m
kubectl exec -n default deploy/volsync-test-app -- cat /data/test.txt
```

### 2. Wait for First Backup
```bash
watch kubectl get replicationsource volsync-test-app -n default
# Wait until lastSyncTime shows a recent timestamp
```

### 3. Scale Down (CRITICAL - Do this FIRST!)
```bash
flux suspend helmrelease volsync-test-app -n default
kubectl scale deployment/volsync-test-app --replicas=0 -n default
kubectl wait pod --for=delete -l app.kubernetes.io/instance=volsync-test-app -n default --timeout=5m
```

### 4. Final Backup
```bash
kubectl patch replicationsource volsync-test-app -n default \
  --type merge -p '{"spec":{"trigger":{"manual":"migration-'$(date +%s)'"}}}'
watch kubectl get replicationsource volsync-test-app -n default
```

### 5. Delete Old PVC
```bash
kubectl delete pvc volsync-test-app-data -n default
```

### 6. Monitor Restore
```bash
watch kubectl get pvc,replicationdestination -n default | grep volsync-test
# Wait for PVC to show Bound status
```

### 7. Update HelmRelease

Edit `kubernetes/default/volsync-test-app/volsync-test-app.yaml`:

Change persistence from `suffix: data` to `existingClaim: volsync-test-app-data`, then:

```bash
git add kubernetes/default/volsync-test-app/volsync-test-app.yaml
git commit -m "test(volsync): migrate test app to existingClaim pattern"
git push
```

### 8. Resume App
```bash
flux resume helmrelease volsync-test-app -n default
flux reconcile helmrelease volsync-test-app -n default
kubectl wait pod --for=condition=ready -l app.kubernetes.io/instance=volsync-test-app -n default --timeout=5m
```

### 9. Verify
```bash
kubectl exec -n default deploy/volsync-test-app -- cat /data/test.txt
kubectl get pvc volsync-test-app-data -n default -o yaml | grep -A 5 dataSourceRef
```

## Files Created

1. `kubernetes/default/volsync-test-app/volsync-test-app.yaml` - HelmRelease with dynamic PVC (to be migrated)
2. `kubernetes/kube-system/volsync/resourceset-volsync-backups.yaml` - Updated with test app + new PVC/ReplicationDestination resources
3. `kubernetes/default/volsync-test-app/MIGRATION-TEST-PLAN.md` - Detailed test plan
4. `kubernetes/default/volsync-test-app/QUICK-START.md` - This file

## Key Changes in ResourceSet

The ResourceSet now generates 4 resources per app when `capacity` field is present:
1. ExternalSecret (Kopia credentials)
2. ReplicationSource (backup schedule)
3. **PVC with dataSourceRef** (NEW - points to bootstrap ReplicationDestination)
4. **ReplicationDestination** (NEW - handles bootstrap restore)

## Migration Order

The test validates this critical order:
1. **Scale down app** ← MUST BE FIRST
2. Take final backup
3. Delete old PVC
4. Volume populator restores to new PVC
5. Update HelmRelease to existingClaim
6. Scale app back up

## Success Indicators

✅ PVC shows `dataSourceRef` pointing to ReplicationDestination  
✅ All original test data intact after migration  
✅ Restart counter incremented (proves new pod using restored PVC)  
✅ Backup still works post-migration  
✅ Can delete PVC and it auto-restores (bootstrap pattern)

## Troubleshooting

**PVC stuck in Pending?**
```bash
kubectl describe pvc volsync-test-app-data -n default
kubectl get replicationdestination volsync-test-app-bootstrap -n default -o yaml
```

**Data missing?**
```bash
kubectl get replicationsource volsync-test-app -n default -o jsonpath='{.status.lastSyncTime}'
```

**Restore failed?**
```bash
kubectl logs -n default -l volsync.backube/replication-destination=volsync-test-app-bootstrap
```

## See Also

- Full test plan: `MIGRATION-TEST-PLAN.md`
- GitHub issue: https://github.com/billimek/k8s-gitops/issues/5125
- Parent issue: https://github.com/billimek/k8s-gitops/issues/5120
