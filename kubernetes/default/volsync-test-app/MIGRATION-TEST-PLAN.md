# PVC Migration Test Plan

## Overview

This test validates the PVC migration approach for issue #5125, transitioning from Helm-managed dynamic PVC creation to ResourceSet-managed PVCs with `dataSourceRef` for automatic bootstrap restore.

## Test Application

**App**: `volsync-test-app`  
**Namespace**: `default`  
**PVC Name**: `volsync-test-app-data`  
**Size**: 1Gi  
**Backup Schedule**: Every 10 minutes (for testing)

The test app uses nginx with a startup script that:
- Writes timestamped test data to `/data/test.txt`
- Maintains a restart counter in `/data/restart_counter.txt`
- Keeps container running indefinitely

## Phase 1: Initial Deployment (Dynamic PVC)

### 1.1 Deploy Test App with Dynamic PVC

```bash
# Deploy the test app (currently configured with suffix: data)
flux reconcile kustomization cluster-apps --with-source
kubectl wait --for=condition=ready helmrelease/volsync-test-app -n default --timeout=5m
kubectl wait pod --for=condition=ready -l app.kubernetes.io/instance=volsync-test-app -n default --timeout=5m
```

### 1.2 Verify Initial Data

```bash
# Check that PVC was created dynamically by Helm
kubectl get pvc -n default | grep volsync-test-app

# Expected: volsync-test-app-data (created by Helm chart)
```

```bash
# Verify test data exists
kubectl exec -n default deploy/volsync-test-app -- cat /data/test.txt

# Expected output:
# VolSync PVC Migration Test - Initial deployment
# Timestamp: <timestamp>
# Pod: <pod-name>
# This data should persist after PVC migration
# Restart counter: 1
```

### 1.3 Write Additional Test Data

```bash
# Write unique test data to verify persistence
kubectl exec -n default deploy/volsync-test-app -- sh -c 'echo "PRE-MIGRATION DATA - $(date)" >> /data/test.txt'

# Verify it was written
kubectl exec -n default deploy/volsync-test-app -- cat /data/test.txt
```

### 1.4 Wait for Initial Backup

The test app is configured to backup every 10 minutes. Wait for at least one backup to complete.

```bash
# Monitor backup progress
watch kubectl get replicationsource volsync-test-app -n default

# Wait until lastSyncTime is populated
kubectl get replicationsource volsync-test-app -n default -o jsonpath='{.status.lastSyncTime}'

# Check backup status
kubectl get replicationsource volsync-test-app -n default -o yaml
```

Expected status:
- `lastSyncTime`: Recent timestamp
- `lastSyncDuration`: A few seconds/minutes depending on data size
- No errors in conditions

## Phase 2: Migration Preparation

### 2.1 Take Final Pre-Migration Backup

**CRITICAL**: Scale down app FIRST to ensure data consistency.

```bash
# Step 1: Scale down app (stop all writes)
flux suspend helmrelease volsync-test-app -n default
kubectl scale deployment/volsync-test-app --replicas=0 -n default
kubectl wait pod --for=delete -l app.kubernetes.io/instance=volsync-test-app -n default --timeout=5m

# Verify no pods are running
kubectl get pods -n default | grep volsync-test-app
```

```bash
# Step 2: Trigger final backup
kubectl patch replicationsource volsync-test-app -n default \
  --type merge -p '{"spec":{"trigger":{"manual":"migration-backup-'$(date +%s)'"}}}'

# Monitor backup completion
watch kubectl get replicationsource volsync-test-app -n default

# Wait for completion
kubectl wait --for=jsonpath='{.status.lastManualSync}'=migration-backup-* \
  replicationsource/volsync-test-app -n default --timeout=10m
```

### 2.2 Verify Backup Completed

```bash
# Check final backup status
kubectl get replicationsource volsync-test-app -n default -o jsonpath='{.status.lastSyncTime}'
kubectl get replicationsource volsync-test-app -n default -o jsonpath='{.status.lastManualSync}'

# Verify no errors
kubectl get replicationsource volsync-test-app -n default -o jsonpath='{.status.conditions}'
```

### 2.3 Document Pre-Migration State

```bash
# Capture PVC details before migration
kubectl get pvc volsync-test-app-data -n default -o yaml > /tmp/pvc-before-migration.yaml

# Capture test data checksum
kubectl exec -n default deploy/volsync-test-app -- md5sum /data/test.txt > /tmp/data-checksum-before.txt
```

## Phase 3: PVC Migration

### 3.1 Update ResourceSet (Already Done)

The ResourceSet has been updated to include:
- PVC resource with `dataSourceRef` pointing to `volsync-test-app-bootstrap` ReplicationDestination
- ReplicationDestination resource for bootstrap restore

This is already committed and will be applied in the next step.

### 3.2 Wait for ResourceSet Reconciliation

```bash
# Reconcile the cluster
flux reconcile kustomization cluster-apps --with-source

# Wait for ResourceSet to be ready
kubectl wait --for=condition=ready resourceset/volsync-backups -n kube-system --timeout=5m

# Verify ReplicationDestination was created
kubectl get replicationdestination volsync-test-app-bootstrap -n default
```

Expected output: ReplicationDestination exists but PVC is still the old Helm-managed one.

### 3.3 Delete Old Helm-Managed PVC

**CRITICAL**: App must be scaled down (done in step 2.1) before deleting PVC.

```bash
# Verify app is still scaled down
kubectl get pods -n default | grep volsync-test-app
# Should return no pods

# Delete the old PVC
kubectl delete pvc volsync-test-app-data -n default

# Verify deletion
kubectl get pvc -n default | grep volsync-test-app
# Should return no PVC (temporarily)
```

### 3.4 Monitor Volume Populator Restoration

After the PVC is deleted, Flux will create a new PVC with `dataSourceRef`. The volume populator controller will automatically restore data from the most recent backup.

```bash
# Watch PVC creation
watch kubectl get pvc volsync-test-app-data -n default

# Monitor volume populator progress
watch kubectl get replicationdestination volsync-test-app-bootstrap -n default

# Check events for populator activity
kubectl get events -n default --sort-by='.lastTimestamp' | grep -i "volsync\|populator"
```

**Expected timeline**:
1. PVC created with status `Pending` (dataSourceRef triggers volume populator)
2. Volume populator creates temporary PVC
3. ReplicationDestination restores data from Kopia backup
4. Volume snapshot taken from restored data
5. New PVC bound using the snapshot
6. Status changes to `Bound`

**Monitor detailed status**:

```bash
# Check PVC status
kubectl get pvc volsync-test-app-data -n default -o yaml

# Verify dataSourceRef is set
kubectl get pvc volsync-test-app-data -n default -o jsonpath='{.spec.dataSourceRef}'

# Check ReplicationDestination status
kubectl get replicationdestination volsync-test-app-bootstrap -n default -o yaml

# Look for:
# - status.lastSyncTime (when restore completed)
# - status.conditions (should show success)
# - status.latestImage (snapshot created from restore)
```

```bash
# Wait for PVC to be ready
kubectl wait --for=condition=ready pvc/volsync-test-app-data -n default --timeout=10m
```

## Phase 4: Update HelmRelease

### 4.1 Update HelmRelease to Use existingClaim

Edit `kubernetes/default/volsync-test-app/volsync-test-app.yaml`:

Change from:
```yaml
persistence:
  data:
    suffix: data
    storageClass: "ceph-block"
    accessMode: ReadWriteOnce
    size: "1Gi"
    globalMounts:
      - path: /data
```

To:
```yaml
persistence:
  data:
    existingClaim: volsync-test-app-data
    globalMounts:
      - path: /data
```

Commit and push this change.

### 4.2 Resume HelmRelease

```bash
# Resume the HelmRelease
flux resume helmrelease volsync-test-app -n default

# Reconcile to pick up the changes
flux reconcile helmrelease volsync-test-app -n default

# Wait for pod to be ready
kubectl wait pod --for=condition=ready -l app.kubernetes.io/instance=volsync-test-app -n default --timeout=5m
```

## Phase 5: Verification

### 5.1 Verify Data Integrity

```bash
# Check test data is intact
kubectl exec -n default deploy/volsync-test-app -- cat /data/test.txt

# Should contain:
# - Original "Initial deployment" message
# - Original timestamp
# - PRE-MIGRATION DATA message from step 1.3
# - Restart counter should have incremented (was 1, now 2+)
```

```bash
# Verify checksum matches (excluding restart counter which will change)
kubectl exec -n default deploy/volsync-test-app -- grep "PRE-MIGRATION DATA" /data/test.txt
```

### 5.2 Verify PVC Configuration

```bash
# Verify PVC has dataSourceRef
kubectl get pvc volsync-test-app-data -n default -o yaml | grep -A 5 dataSourceRef

# Expected:
# dataSourceRef:
#   apiGroup: volsync.backube
#   kind: ReplicationDestination
#   name: volsync-test-app-bootstrap
```

```bash
# Verify PVC is NOT managed by Helm anymore
kubectl get pvc volsync-test-app-data -n default -o jsonpath='{.metadata.labels}' | grep -i helm
# Should return nothing (no Helm labels)
```

### 5.3 Verify Backup Still Works

```bash
# Trigger manual backup
kubectl patch replicationsource volsync-test-app -n default \
  --type merge -p '{"spec":{"trigger":{"manual":"post-migration-test-'$(date +%s)'"}}}'

# Monitor backup
watch kubectl get replicationsource volsync-test-app -n default

# Verify completion
kubectl get replicationsource volsync-test-app -n default -o jsonpath='{.status.lastSyncTime}'
```

### 5.4 Test Bootstrap Restore Pattern

This validates the new bootstrap restore capability - the primary goal of this migration.

```bash
# Step 1: Write new test data
kubectl exec -n default deploy/volsync-test-app -- sh -c 'echo "POST-MIGRATION DATA - $(date)" >> /data/test.txt'

# Step 2: Trigger backup
kubectl patch replicationsource volsync-test-app -n default \
  --type merge -p '{"spec":{"trigger":{"manual":"before-bootstrap-test-'$(date +%s)'"}}}'

# Wait for backup to complete
kubectl wait --for=jsonpath='{.status.lastManualSync}'=before-bootstrap-test-* \
  replicationsource/volsync-test-app -n default --timeout=10m

# Step 3: Scale down app
kubectl scale deployment/volsync-test-app --replicas=0 -n default
kubectl wait pod --for=delete -l app.kubernetes.io/instance=volsync-test-app -n default --timeout=5m

# Step 4: Delete PVC (simulating fresh cluster bootstrap)
kubectl delete pvc volsync-test-app-data -n default

# Step 5: Trigger bootstrap restore
# Update the ReplicationDestination to trigger restore
kubectl patch replicationdestination volsync-test-app-bootstrap -n default \
  --type merge -p '{"spec":{"trigger":{"manual":"bootstrap-test-'$(date +%s)'"}}}'

# Step 6: Wait for PVC to be created and data restored
kubectl wait --for=condition=ready pvc/volsync-test-app-data -n default --timeout=10m

# Step 7: Scale app back up
kubectl scale deployment/volsync-test-app --replicas=1 -n default
kubectl wait pod --for=condition=ready -l app.kubernetes.io/instance=volsync-test-app -n default --timeout=5m

# Step 8: Verify data was restored
kubectl exec -n default deploy/volsync-test-app -- cat /data/test.txt | grep "POST-MIGRATION DATA"
# Should show the POST-MIGRATION DATA we wrote in step 1
```

## Success Criteria

- ✅ Initial deployment works with dynamic PVC
- ✅ Test data persists through migration
- ✅ Backup completes before migration
- ✅ Old PVC deleted without data loss
- ✅ New PVC created with dataSourceRef
- ✅ Volume populator restores data automatically
- ✅ HelmRelease updates to use existingClaim
- ✅ App runs successfully with migrated PVC
- ✅ All original test data intact after migration
- ✅ Backup continues to work post-migration
- ✅ Bootstrap restore pattern works (delete PVC, auto-restore)

## Cleanup

After successful testing:

```bash
# Option 1: Keep test app for future validation
# No action needed

# Option 2: Remove test app
flux suspend helmrelease volsync-test-app -n default
kubectl delete helmrelease volsync-test-app -n default
kubectl delete pvc volsync-test-app-data -n default
kubectl delete replicationsource volsync-test-app -n default
kubectl delete replicationdestination volsync-test-app-bootstrap -n default
kubectl delete externalsecret volsync-test-app-kopia -n default
kubectl delete secret volsync-test-app-kopia-secret -n default

# Remove from ResourceSet (edit kubernetes/kube-system/volsync/resourceset-volsync-backups.yaml)
# Remove test app directory
rm -rf kubernetes/default/volsync-test-app
```

## Troubleshooting

### PVC Stuck in Pending

```bash
# Check PVC events
kubectl describe pvc volsync-test-app-data -n default

# Check volume populator logs
kubectl logs -n volsync-system -l app.kubernetes.io/name=volsync

# Check ReplicationDestination status
kubectl get replicationdestination volsync-test-app-bootstrap -n default -o yaml
```

### Restore Failed

```bash
# Check ReplicationDestination events
kubectl describe replicationdestination volsync-test-app-bootstrap -n default

# Check mover pod logs
kubectl logs -n default -l volsync.backube/replication-destination=volsync-test-app-bootstrap

# Verify Kopia secret exists
kubectl get secret volsync-test-app-kopia-secret -n default
```

### Data Missing After Migration

```bash
# Check if backup was taken before deletion
kubectl get replicationsource volsync-test-app -n default -o jsonpath='{.status.lastSyncTime}'

# Check Kopia repository
kubectl exec -n default deploy/volsync-test-app -- ls -la /data/
```

## Next Steps

After successful test validation:

1. Document lessons learned
2. Refine migration steps based on test results
3. Begin migrating production apps (start with low-risk apps like recyclarr, tautulli)
4. Update issue #5125 with test results
5. Create migration tracking checklist for all 21 apps
