# VolSync Test App - PVC Migration Validation

This test application validates the PVC migration approach for [issue #5125](https://github.com/billimek/k8s-gitops/issues/5125).

## Purpose

Validate transitioning from Helm dynamic PVC creation to ResourceSet-managed PVCs with automatic bootstrap restore capability via `dataSourceRef` and volume populator.

## Current State

**Phase**: ⏸️ Ready to Deploy

The test infrastructure is in place but not yet deployed. This allows you to start from Phase 1 of the migration test.

## Quick Links

- **[QUICK-START.md](./QUICK-START.md)** - Fast track commands for running the test
- **[MIGRATION-TEST-PLAN.md](./MIGRATION-TEST-PLAN.md)** - Comprehensive step-by-step test plan with monitoring and verification

## What Gets Tested

1. ✅ Helm dynamic PVC creation (current pattern)
2. ✅ Data persistence through migration
3. ✅ Volume populator automatic restore
4. ✅ ResourceSet PVC management with dataSourceRef
5. ✅ Bootstrap restore pattern (delete PVC → auto-restore from backup)
6. ✅ Zero data loss verification

## Architecture

### Before Migration
```
HelmRelease (app-template)
  └─> Creates PVC dynamically (suffix: data)
      └─> ReplicationSource backs up to Kopia
          └─> Manual restore only (Task command)
```

### After Migration
```
ResourceSet
  ├─> PVC with dataSourceRef → ReplicationDestination
  ├─> ReplicationSource (backup schedule)
  └─> ReplicationDestination (bootstrap restore)

HelmRelease (app-template)
  └─> Uses existingClaim (PVC managed by ResourceSet)
      └─> Automatic restore on fresh cluster bootstrap
```

## Key Features

- **Test data generation**: Writes timestamped data and restart counters
- **Frequent backups**: Every 10 minutes (vs production 4-7 AM schedule)
- **Small footprint**: 1Gi PVC, minimal resource usage
- **Validation hooks**: Built-in data integrity checks

## Files

```
kubernetes/default/volsync-test-app/
├── README.md                    # This file
├── QUICK-START.md              # Fast track commands
├── MIGRATION-TEST-PLAN.md      # Detailed test procedures
└── volsync-test-app.yaml       # HelmRelease (starts with dynamic PVC)
```

## ResourceSet Changes

Modified `kubernetes/kube-system/volsync/resourceset-volsync-backups.yaml`:
- Added volsync-test-app to inputs (with `capacity` field)
- Added PVC resource template (uses `dataSourceRef`)
- Added ReplicationDestination resource template (bootstrap restore)
- Resources only generated when `capacity` field exists (opt-in for migration)

## Getting Started

### Option 1: Quick Test
Follow [QUICK-START.md](./QUICK-START.md) for condensed commands.

### Option 2: Comprehensive Test
Follow [MIGRATION-TEST-PLAN.md](./MIGRATION-TEST-PLAN.md) for detailed monitoring and verification.

## Migration Phases

| Phase | Status | Description |
|-------|--------|-------------|
| 1 | ⏸️ Ready | Deploy with dynamic PVC, write test data |
| 2 | 🔜 Pending | Scale down, take final backup |
| 3 | 🔜 Pending | Delete PVC, monitor volume populator restore |
| 4 | 🔜 Pending | Update HelmRelease to existingClaim |
| 5 | 🔜 Pending | Verify data integrity and bootstrap restore |

## Expected Timeline

- **Setup**: 5 minutes
- **Initial backup wait**: 10 minutes (first scheduled backup)
- **Migration**: 15-20 minutes (includes monitoring)
- **Verification**: 10 minutes
- **Total**: ~45 minutes

## Success Criteria

All criteria must pass before migrating production apps:

- [ ] Dynamic PVC created by Helm initially
- [ ] Test data persists through migration
- [ ] Volume populator restores data automatically
- [ ] New PVC has dataSourceRef configured
- [ ] App runs successfully with migrated PVC
- [ ] Backup continues to work post-migration
- [ ] Bootstrap restore works (delete PVC → auto-restore)

## Next Steps After Successful Test

1. Document lessons learned and timing data
2. Update migration procedure based on findings
3. Begin migrating low-risk production apps (recyclarr, tautulli, qui)
4. Track progress in issue #5125

## Troubleshooting

See [MIGRATION-TEST-PLAN.md](./MIGRATION-TEST-PLAN.md) troubleshooting section.

Common issues:
- PVC stuck pending → Check volume populator logs
- Data missing → Verify backup completed before deletion
- Restore failed → Check ReplicationDestination events

## Related Issues

- [#5125](https://github.com/billimek/k8s-gitops/issues/5125) - PVC migration to ResourceSet with dataSourceRef
- [#5120](https://github.com/billimek/k8s-gitops/issues/5120) - Parent issue: Automated restore pattern

## Resources

- [VolSync Volume Populator Docs](https://volsync.readthedocs.io/en/stable/usage/volume-populator/index.html)
- [bjw-s home-ops reference](https://github.com/bjw-s-labs/home-ops/tree/main/kubernetes/components/volsync)
