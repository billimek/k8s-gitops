# PVC Migration Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    BEFORE MIGRATION (Current State)                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  HelmRelease                                                              │
│  └─> persistence:                                                         │
│       └─> suffix: data          ┌──────────────────────┐                 │
│            ↓                     │  PVC (Helm-managed)  │                 │
│       Creates PVC ──────────────>│  volsync-test-app-   │                 │
│       dynamically                │  data                │                 │
│                                  └──────────┬───────────┘                 │
│                                             │                             │
│                                             │ Backed up                   │
│                                             ↓                             │
│                                  ┌──────────────────────┐                 │
│  ResourceSet                     │ ReplicationSource    │                 │
│  └─> ExternalSecret              │ (Kopia backup)       │                 │
│  └─> ReplicationSource ─────────>│ Schedule: */10 * * * │                 │
│                                  └──────────────────────┘                 │
│                                                                           │
│  ❌ Problem: Cannot auto-restore on bootstrap                             │
│             PVC has no dataSourceRef                                      │
└─────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                           MIGRATION PROCESS                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  Step 1: SCALE DOWN APP (Critical - prevents data loss!)                 │
│    kubectl scale deployment/volsync-test-app --replicas=0                │
│                                                                           │
│  Step 2: FINAL BACKUP                                                    │
│    Trigger manual backup with app stopped                                │
│                                                                           │
│  Step 3: DELETE OLD PVC                                                  │
│    kubectl delete pvc volsync-test-app-data                              │
│                                                                           │
│  Step 4: VOLUME POPULATOR AUTO-RESTORES                                  │
│    New PVC created with dataSourceRef                                    │
│    → Triggers ReplicationDestination                                     │
│    → Restores from Kopia backup                                          │
│    → Creates VolumeSnapshot                                              │
│    → New PVC bound with restored data                                    │
│                                                                           │
│  Step 5: UPDATE HELMRELEASE                                              │
│    Change: suffix: data  →  existingClaim: volsync-test-app-data         │
│                                                                           │
│  Step 6: SCALE UP APP                                                    │
│    App now uses ResourceSet-managed PVC with auto-restore                │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                    AFTER MIGRATION (New State)                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  HelmRelease                                                              │
│  └─> persistence:                                                         │
│       └─> existingClaim:         ┌──────────────────────┐                │
│           volsync-test-app-data  │ PVC (ResourceSet)    │                │
│            ↓                     │ volsync-test-app-    │                │
│       Uses existing PVC ────────>│ data                 │                │
│       (not created by Helm)      │                      │                │
│                                  │ dataSourceRef:       │                │
│                                  │  kind: RepDest       │                │
│                                  │  name: ...-bootstrap │                │
│                                  └──────────┬───────────┘                │
│                                             │                             │
│                                             │ Backed up                   │
│                                             ↓                             │
│                                  ┌──────────────────────┐                 │
│  ResourceSet                     │ ReplicationSource    │                 │
│  ├─> ExternalSecret              │ (Kopia backup)       │                 │
│  ├─> ReplicationSource ─────────>│ Schedule: */10 * * * │                 │
│  ├─> PVC (with dataSourceRef)    └──────────────────────┘                 │
│  │    └─> capacity: 1Gi                                                  │
│  │                                                                        │
│  └─> ReplicationDestination      ┌──────────────────────┐                 │
│       └─> Bootstrap restore ────>│ ReplicationDest      │                 │
│                                  │ ...-bootstrap        │                 │
│                                  │ (auto-restore)       │                 │
│                                  └──────────────────────┘                 │
│                                                                           │
│  ✅ Solution: Auto-restore on bootstrap via volume populator              │
│              PVC has dataSourceRef → triggers restore                     │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                     BOOTSTRAP RESTORE FLOW (NEW!)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  Scenario: Fresh cluster deployment or PVC deleted                       │
│                                                                           │
│  1. Flux applies ResourceSet                                             │
│      └─> Creates PVC with dataSourceRef                                  │
│                                                                           │
│  2. Volume Populator sees dataSourceRef                                  │
│      └─> Triggers ReplicationDestination (volsync-test-app-bootstrap)    │
│                                                                           │
│  3. ReplicationDestination restores from Kopia                           │
│      └─> Pulls latest backup from repository                             │
│      └─> Creates VolumeSnapshot from restored data                       │
│                                                                           │
│  4. PVC bound using restored snapshot                                    │
│      └─> Status: Bound                                                   │
│      └─> Contains all data from backup                                   │
│                                                                           │
│  5. HelmRelease deploys app                                              │
│      └─> Mounts restored PVC                                             │
│      └─> App starts with existing data ✅                                 │
│                                                                           │
│  🎉 RESULT: Automatic data restore with zero manual intervention!        │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                        RESOURCE GENERATION LOGIC                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ResourceSet inputs:                                                     │
│  ├─ app: volsync-test-app                                                │
│  ├─ pvcName: volsync-test-app-data                                       │
│  ├─ capacity: 1Gi              ← NEW (triggers PVC + RepDest)            │
│  ├─ runAsUser: "1001"                                                    │
│  ├─ cacheCapacity: 2Gi                                                   │
│  └─ schedule: "*/10 * * * *"                                             │
│                                                                           │
│  Generated resources:                                                    │
│  ├─ ExternalSecret (always)        → Kopia credentials                   │
│  ├─ ReplicationSource (always)     → Backup schedule                     │
│  ├─ PVC (when: capacity exists)    → With dataSourceRef ✨               │
│  └─ ReplicationDestination         → Bootstrap restore ✨                 │
│     (when: capacity exists)                                              │
│                                                                           │
│  Total for test app: 4 resources                                         │
│  Total for 21 existing apps: 42 resources (no capacity field yet)        │
│  Total when all migrated: 84 resources (21 apps × 4)                     │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Differences

| Aspect | Before | After |
|--------|--------|-------|
| **PVC Creation** | Helm chart (dynamic) | ResourceSet (declarative) |
| **PVC Lifecycle** | Tied to HelmRelease | Independent, Git-managed |
| **Bootstrap Restore** | Manual (Task command) | Automatic (volume populator) |
| **dataSourceRef** | None | Points to ReplicationDestination |
| **Disaster Recovery** | Manual restore steps | Redeploy to restore |
| **Configuration** | In HelmRelease values | In ResourceSet inputs |

## Testing Strategy

This test validates the entire flow:

1. ✅ **Phase 1**: Deploy with old pattern (dynamic PVC)
2. ✅ **Phase 2**: Write test data, verify backup works
3. ✅ **Phase 3**: Migration (scale down → backup → delete → auto-restore)
4. ✅ **Phase 4**: Verify data integrity, no data loss
5. ✅ **Phase 5**: Test bootstrap restore (delete PVC → auto-restore)

## Why This Matters

**Problem Solved**: In the old pattern, rebuilding a cluster required manual PVC restoration:
```bash
task volsync:restore APP=home-assistant WAIT=true  # Manual step for each app
```

**New Pattern**: Cluster rebuild is fully automated:
```bash
flux bootstrap  # All PVCs auto-restore via volume populator 🎉
```

This enables true "GitOps" disaster recovery - just point Flux at the repo and everything comes back automatically.
