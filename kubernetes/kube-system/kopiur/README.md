# Kopiur Backup & Restore System

Automated backup and restore for application PVCs using [kopiur](https://kopiur.home-operations.com),
a Kopia-native Kubernetes backup operator. Managed entirely through Flux Operator
ResourceSets, mirroring the pattern previously used for VolSync.

Kopiur was adopted onto the **existing** Kopia repository at
`nas.home:/mnt/ssdtank/kopia` (previously written by the
[volsync-perfectra1n](https://github.com/perfectra1n/volsync) fork's Kopia mover).
The `ClusterRepository` carries no `create` block and pins each app's snapshot
identity to the fork's recorded `<app>@<namespace>:/data`, so kopiur continued the
existing snapshot history in place rather than starting a new, empty repository.

## Architecture

```text
resourceset-inputprovider.yaml (apps defined, kopiur-apps)
    ├─→ resourceset-snapshots.yaml (SnapshotPolicy + SnapshotSchedule per app)
    └─→ resourceset-restores.yaml (Restore populator + PVC with bootstrap per app)
```

**Key features**:

- Hourly-by-default backups (staggered into three schedule groups) to
  `nas.home:/mnt/ssdtank/kopia`; 13 low-churn apps are trimmed to every 4h
  (see the frequency note in `resourceset-inputprovider.yaml`) to keep
  Snapshot CR volume and Kopia index-blob churn down
- Automatic cluster bootstrap via PVC `dataSourceRef`
- Retention: 24 hourly, 14 daily, 8 weekly, 6 monthly snapshots (GFS)
- Kopia deduplication + compression
- Default-managed repository maintenance: quick every 6h, full daily (replaces
  the old `KopiaMaintenance` CronJob); `clusterrepository.yaml` also sets
  `parameters.epoch.minDuration: 6h` to fix a pre-existing "too many index
  blobs" condition that a 24h epoch couldn't clear fast enough on its own
- `SnapshotSchedule.spec.schedule.jitter` staggers mover start times (replaces
  the old `volsync-mover-jitter` MutatingAdmissionPolicy)

## Components

| File | Purpose | Resources |
|------|---------|-----------|
| `kopiur.yaml` | Operator | OCIRepository + HelmRelease |
| `clusterrepository.yaml` | Shared repository | `ClusterRepository` |
| `externalsecret.yaml` | Repository password | `ExternalSecret` |
| `resourceset-inputprovider.yaml` | App definitions | `ResourceSetInputProvider` |
| `resourceset-snapshots.yaml` | Backup infrastructure | `SnapshotPolicy` + `SnapshotSchedule` |
| `resourceset-restores.yaml` | Bootstrap-capable PVCs | `Restore` + `PersistentVolumeClaim` |

## Adding a New Application

1. **Add to `resourceset-inputprovider.yaml`**:

   ```yaml
   - app: my-new-app
     capacity: 5Gi
     runAsUser: "1001"
     schedule: "0 8 * * *"
   ```

2. **Reference the PVC in the app's HelmRelease**:

   ```yaml
   persistence:
     config:
       existingClaim: my-new-app-config
   ```

New apps have no existing Kopia history, so the first backup starts an empty
series; the PVC is created empty (`onMissingSnapshot: Continue`) until then.

## Removing an Application

1. Delete the entry from `resourceset-inputprovider.yaml`.
2. Commit and reconcile.
3. The ResourceSet auto-deletes the generated `SnapshotPolicy`, `SnapshotSchedule`,
   and `Restore`.
4. **The PVC is not deleted** (it carries `fluxcd.controlplane.io/prune: disabled`
   deliberately). Remove it by hand once you no longer need it:
   `kubectl delete pvc <app>-config -n <namespace>`.

## Disaster Recovery

**Automatic bootstrap**: when the cluster/namespace is rebuilt, the PVC template in
`resourceset-restores.yaml` automatically restores from the latest snapshot via
`dataSourceRef`.

**Manual restore/snapshot**: see `.taskfiles/kopiur/Taskfile.yaml`
(`task kopiur:list`, `task kopiur:snapshot`, `task kopiur:snapshot-all`,
`task kopiur:restore`).

## Resizing a PVC

Kubernetes only supports PVC **expansion**, not shrinking. To shrink a PVC, use
the same backup/delete/restore workflow documented previously for VolSync:

1. Suspend the app and scale it to zero (pause any KEDA `ScaledObject` first).
2. `task kopiur:snapshot APP=<app>` with the app stopped, for a consistent backup.
3. Update `capacity` in `resourceset-inputprovider.yaml`.
4. `kubectl delete pvc <app>-config -n <namespace>` and delete the corresponding
   `restore/<app>-bootstrap`.
5. Reconcile the `kopiur-restores` ResourceSet (recreates the PVC at the new size
   from the restore populator) and wait for it to bind.
6. Resume the app; take a fresh backup at the new size.

## Monitoring

The chart ships its own `ServiceMonitor`, `PrometheusRule`, and (via
grafana-operator) a `GrafanaDashboard` in the `infrastructure` folder — enabled
under `monitoring.*` in `kopiur.yaml`.
