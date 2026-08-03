# Agent Instructions

> Edit either `AGENTS.md` or `CLAUDE.md` — they are the same file (symlink).

GitOps Kubernetes cluster on Talos + FluxCD. Infrastructure (`/setup`) separate from apps (`/kubernetes`).

## Key Commands

```bash
task                    # List all tasks
task k8s:sync-secrets   # Force sync ExternalSecrets
task k8s:cleanse-pods   # Delete Failed/Pending/Succeeded pods
task kopiur:snapshot APP=<name>   # Trigger immediate backup
task kopiur:list APP=<name>       # List snapshots for an app
task kopiur:restore APP=<name>    # Restore an app's PVC from latest backup
flux reconcile kustomization cluster-apps --with-source
```

## MCP Servers

Five MCP servers are available for this repo. Read-only tools run without prompting; any
tool that creates, updates, deletes, scales, execs, or pushes requires explicit confirmation
(same rule as destructive CLI commands).

- **flux** (`mcp__flux__*`) — Prefer over CLI `flux get` when you need structured output,
  reconciliation error details, or want to look up Flux API fields via `search_flux_docs`.
- **kubernetes** (`mcp__kubernetes__*`) — Prefer for structured resource/log/event/metric
  reads. Mutating tools (`resources_create_or_update`, `resources_delete`,
  `resources_scale`, `pods_delete`, `pods_exec`, `pods_run`) require confirmation. Because
  this cluster is GitOps-managed, persistent changes belong in git + Flux reconcile, not
  direct apply/scale.
- **grafana** (`mcp__grafana__*`) — Use read-only: `query_prometheus` against the
  VictoriaMetrics datasource, `search_dashboards`/`get_dashboard_by_uid` to inspect
  dashboards, `list_alert_rules` for alerting review. **Do NOT create or update
  dashboards/datasources via MCP** — they are GitOps-managed as `GrafanaDashboard` /
  `GrafanaDatasource` CRs (`kubernetes/monitoring/grafana/`); MCP-written resources cause
  drift and get reverted by Flux.
- **victorialogs** (`mcp__victorialogs__*`) — Preferred path for cluster log investigation.
  Use LogsQL queries here rather than scraping individual `kubectl logs` when searching
  across pods or time windows. All tools are read-only.
- **github** (`mcp__github__*`) — PR/issue/code reads; CLI `gh` (already allowlisted) is
  equally fine for quick checks.

## Architecture

**Patterns**:
- **Cluster**: Single homelab cluster, 1 control plane + 7 workers (Talos)
- **Primary**: OCIRepository + chartRef (exceptions: minecraft uses HelmRepository)
- **Ingress**: Envoy Gateway with HTTPRoute (NOT Traefik/Ingress)
- **Gateways**: `internal` (LAN + Tailscale, 10.0.6.151) and `public` (internet-facing, 10.0.6.150), both in `kube-system`
- **Storage**: Ceph block (default), NFS media mounts, kopiur+Kopia backups
- **Secrets**: ExternalSecret CRDs only (no plaintext)
- **Backups**: ResourceSet automation in kube-system/kopiur/ (Kopia-native backup operator)
- **CI**: PRs run `flate` diff/test (`.github/workflows/flate.yaml`); Renovate auto-bumps images per `.renovate/` rules; non-trivial Renovate version bumps are gated by a Claude review (`.github/workflows/renovate-review.yaml`, `claude/renovate-review` status — digest/github-action/grafana-dashboard updates are ungated); use `/review-renovate` to manually review and merge queued PRs and `/tune-renovate-review` to analyze recent CI runs for prompt/tier improvements
- **Grafana**: Managed by grafana-operator (`kubernetes/monitoring/grafana/`). Dashboards, folders, and datasources are `GrafanaDashboard`/`GrafanaFolder`/`GrafanaDatasource` CRs (`grafana.integreatly.org/v1beta1`). Instance selector label is `dashboards: grafana`. To add a dashboard, create a `GrafanaDashboard` CR next to the relevant app with `instanceSelector: {matchLabels: {dashboards: grafana}}`; add `allowCrossNamespaceImport: true` and a `folderRef` when outside the `monitoring` namespace. grafana.com dashboards use `spec.url`, chart-shipped ConfigMap dashboards use `spec.configMapRef`. Renovate tracks grafana.com revision URLs automatically via `.renovate/grafanaDashboards.json5`.

## Scaffolding a New App

The HelmRelease, ExternalSecret, and kopiur backup-registration templates (including the
`kubernetes/kube-system/kopiur/resourceset-inputprovider.yaml` entry format) live in the
`new-app` skill (`.claude/skills/new-app/SKILL.md`) — invoke it when adding a new app rather
than reproducing the YAML here.

## Backup Configuration

Schedules use kopiur's Jenkins-style `H` cron substitution (`H * * * *`) —
each app hashes to a stable, deterministic minute so load self-distributes
with no manual bucket bookkeeping. kopiur only hashes a bare `H` token (no
`H/N` step syntax — the admission webhook rejects it), so trim low-churn
apps with plain cron step syntax in the hour field, `H */4 * * *` (every 4h),
instead of hourly.

NFS repository (`nas.home:/mnt/ssdtank/kopia`) is configured on the single
`ClusterRepository "nas"` in `clusterrepository.yaml` — apps reference it by
name (`repository: {kind: ClusterRepository, name: nas}`), no per-app
volume/secret wiring needed.

## app-template ConfigMap Naming

App-template v4 names ConfigMaps as `<release-name>` (not `<release-name>-<key>`).

**Preferred**: Use `identifier` to cross-reference inline configMaps without depending on the naming convention:

```yaml
configMaps:
  config:
    data:
      config.yaml: |
        ...

persistence:
  config-file:
    type: configMap
    identifier: config   # references configMaps.config by key
```

**Alternative**: Reference by release name directly:

```yaml
persistence:
  config-file:
    type: configMap
    name: gatus           # correct: just the release name
    # name: gatus-config  # WRONG: do not append the configMap key
```

## Troubleshooting

Recovering a stuck HelmRelease, forcing an ExternalSecret resync, or unblocking a Flux
reconcile: see the `flux-recovery` skill (`.claude/skills/flux-recovery/SKILL.md`).

## Standards

- **Images**: Always pin with SHA256 digest
- **Security**: Non-root preferred (default UID 1001), read-only rootfs, drop all capabilities. Check image docs for required UID.
- **Naming**: kebab-case for all resources
- **Schemas**: Include yaml-language-server validation on all CRDs
- **No Kustomization**: Intentionally avoided throughout
