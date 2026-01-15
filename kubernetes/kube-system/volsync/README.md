# VolSync Backup & Restore System

Automated backup and restore for application PVCs using VolSync with Kopia backend and NFS storage. Managed entirely through Flux Operator ResourceSets.

## Architecture

```text
resourceset-inputprovider.yaml (apps defined)
    ├─→ resourceset-volsync-backups.yaml (ExternalSecret + ReplicationSource per app)
    └─→ resourceset-pvcs.yaml (ReplicationDestination + PVC with bootstrap per app)
            ↓
mutatingadmissionpolicy.yaml (auto-inject NFS mount + jitter)
```

**Key Features**:

- Nightly backups to `nas.home:/mnt/ssdtank/kopia`
- Automatic cluster bootstrap via PVC `dataSourceRef`
- Retention: 24 hourly, 10 daily, 4 weekly snapshots
- Kopia deduplication + zstd compression
- Weekly repository maintenance (Sunday 3 AM)

## Components

| File | Purpose | Resources |
|------|---------|-----------|
| `resourceset-inputprovider.yaml` | App definitions | - |
| `resourceset-volsync-backups.yaml` | Backup infrastructure | ExternalSecrets + ReplicationSources |
| `resourceset-pvcs.yaml` | Bootstrap-capable PVCs | ReplicationDestinations + PVCs |
| `mutatingadmissionpolicy.yaml` | NFS injection + jitter | Runtime mutations |
| `maintenance-kopiamaintenance.yaml` | Repository optimization | Weekly CronJob |
| `volsync.yaml` | VolSync controller | HelmRelease |
| `prometheusrule.yaml` | Monitoring alerts | 5 alerts |

## Adding a New Application

1. **Add to `resourceset-inputprovider.yaml`**:

   ```yaml
   - app: my-new-app
     capacity: 5Gi
     runAsUser: "1001"
     schedule: "0 8 * * *"
   ```

2. **Reference PVC in app's HelmRelease**:

   ```yaml
   persistence:
     config:
       existingClaim: my-new-app-config
   ```

**Note**: VolSync handles missing backups gracefully. When a new app is added, the PVC will be created empty on first deploy unless there is already a backup, then subsequent backups will be stored. If the PVC is deleted/restored later, it will automatically restore from the backup.

## Removing an Application

1. Delete entry from `resourceset-inputprovider.yaml`
2. Commit and reconcile
3. ResourceSet auto-deletes: ExternalSecret, ReplicationSource, ReplicationDestination
4. **PVC may not be auto-deleted** (manual: `kubectl delete pvc <app>-config`)

## Disaster Recovery

**Automatic Bootstrap**: When cluster is rebuilt, PVCs automatically restore from latest backup via `dataSourceRef`.

**Manual Restore**:

```bash
# List available snapshots
task volsync:list APP=<app>

# Restore from specific snapshot (PREVIOUS=0 is latest, PREVIOUS=1 is previous, etc.)
task volsync:restore APP=<app> PREVIOUS=0

# Restore to specific timestamp (RFC3339 format)
task volsync:restore APP=<app> PREVIOUS=0 RESTORE_AS_OF="2026-01-14T12:00:00Z"
```

### MutatingAdmissionPolicies

1. **volsync-mover-nfs**: Auto-injects NFS mount into VolSync jobs
   - Matches: Jobs starting with `volsync-`
   - Injects: `nas.home:/mnt/ssdtank/kopia` mounted at `/repository`

2. **volsync-mover-jitter**: Adds 0-30s random delay to backup jobs
   - Matches: Jobs starting with `volsync-src-`
   - Prevents: Thundering herd (all apps backing up simultaneously)

## Monitoring

### PrometheusRule Alerts

- `VolSyncComponentAbsent`: VolSync metrics missing (15m, critical)
- `VolSyncVolumeOutOfSync`: Backup out of sync (15m, critical)
- `KopiaMaintenanceFailure`: Maintenance job failed (5m, critical)
- `KopiaMaintenanceMissing`: No maintenance >8 days (1h, warning)
- `KopiaMaintenanceTimeout`: Job running >4 hours (15m, warning)
