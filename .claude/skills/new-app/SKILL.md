---
name: new-app
description: Scaffold a new app in this cluster - HelmRelease (app-template or non-app-template), ExternalSecret, and kopiur backup registration. Use when adding a new application to kubernetes/{namespace}/{app}/.
---

# Scaffolding a New App

## Application Template (app-template chart)

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s-labs/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v2.schema.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: &app app-name
  namespace: target-namespace
spec:
  chartRef:
    kind: OCIRepository
    name: app-template
    namespace: flux-system
  interval: 1h
  values:
    defaultPodOptions:
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: OnRootMismatch
        runAsGroup: 1001
        runAsNonRoot: true
        runAsUser: 1001  # Check image docs; common values: 1001, 1000, 65534

    controllers:
      app-name:
        containers:
          app:
            image:
              repository: ghcr.io/org/image
              tag: 1.0.0@sha256:...  # Always pin SHA
            resources:
              requests:
                cpu: 10m
                memory: 128Mi
              limits:
                memory: 512Mi
            securityContext:
              allowPrivilegeEscalation: false
              capabilities: {drop: ["ALL"]}
              readOnlyRootFilesystem: true

    persistence:
      config:
        existingClaim: app-name-config

    route:
      app:
        parentRefs:
          - name: internal          # LAN/Tailscale only
            namespace: kube-system
          # - name: public          # Add for internet-facing apps
          #   namespace: kube-system
        hostnames:
          - "app.eviljungle.com"
        rules:
          - matches:
              - path: {type: PathPrefix, value: /}
            backendRefs:
              - name: app-name
                port: http

    service:
      app:
        controller: app-name
        ports:
          http:
            port: 8080
```

## Non-App-Template HelmReleases

For infrastructure charts (not using app-template), use this schema:
```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/helmrelease-helm-v2.json
```

## ExternalSecret Template

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/external-secrets.io/externalsecret_v1.json
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-name-secret
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword-connect
  target:
    name: app-name-secret
    template:
      engineVersion: v2
      data:
        API_KEY: "{{ .api_key }}"
  dataFrom:
    - extract:
        key: app-name
```

## Backup Configuration

Add to `kubernetes/kube-system/kopiur/resourceset-inputprovider.yaml`:

```yaml
apps:
  - app: app-name
    namespace: "default"    # omit if default
    runAsUser: "1001"       # omit to use default
    capacity: 1Gi           # omit to use default (1Gi)
    schedule: "H */4 * * *" # omit to use default (H * * * *, hourly)
    pvcSuffix: "config"     # omit to use default (config)
    cacheCapacity: 20Gi     # omit unless app needs large Kopia cache (e.g. plex)
```

Schedules use kopiur's Jenkins-style `H` cron substitution (`H * * * *`) — each app hashes to
a stable, deterministic minute so load self-distributes with no manual bucket bookkeeping.
kopiur only hashes a bare `H` token (no `H/N` step syntax — the admission webhook rejects
it), so trim low-churn apps with plain cron step syntax in the hour field, `H */4 * * *`
(every 4h), instead of hourly.

NFS repository (`nas.home:/mnt/ssdtank/kopia`) is configured on the single
`ClusterRepository "nas"` in `clusterrepository.yaml` — apps reference it by name
(`repository: {kind: ClusterRepository, name: nas}`), no per-app volume/secret wiring
needed.
