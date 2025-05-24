# GitHub Copilot Instructions for VolSync Integration

## When to Apply These Instructions

These instructions should be applied when working with persistent storage in applications, including:
- Any application that requires persistent storage
- When creating new PVCs that should be backed up
- When integrating with the VolSync operator for data backup and recovery
- When working with both application-specific and shared PVCs

## VolSync Integration Pattern

1. Reference the VolSync-backed PVC in the HelmRelease:
  ```yaml
  # In <app-name>.yaml
  persistence:
    config:
      storageClass: "ceph-block"
      accessMode: ReadWriteOnce
      size: "2Gi" # or appropriate size
  ```

## Common VolSync Configuration Patterns

### Configuration with Multiple PVCs

When an application needs multiple PVCs:
1. Create the main config PVC using VolSync (handled automatically)
2. Reference both PVCs in the HelmRelease:


# In <app-name>/<app-name>.yaml
```yaml
persistence:
  config:
    storageClass: "ceph-block"
    accessMode: ReadWriteOnce
    size: "2Gi" # or appropriate size
  cache:
    storageClass: "ceph-block"
    accessMode: ReadWriteOnce
    size: "2Gi" # or appropriate size
    globalMounts:
      - path: /config/cache
```

## Working with Shared PVCs

For applications that need access to shared data (media files, etc.), combine VolSync-backed PVCs with shared PVCs:

# In <app-name>/<app-name>.yaml
```yaml
persistence:
  config:
    storageClass: "ceph-block"
    accessMode: ReadWriteOnce
    size: "2Gi" # or appropriate size
  media:
    existingClaim: media-nfs-share-pvc  # Shared PVC
    globalMounts:
      - path: /media
```

## Best Practices

1. Use VolSync for all application configuration data that needs to be persisted
2. Use the default naming pattern where the PVC name matches the app name
3. Keep cache and temporary data in separate PVCs to avoid unnecessary backups
4. Use `ceph-block` and ReadWriteOnce for most application config volumes
