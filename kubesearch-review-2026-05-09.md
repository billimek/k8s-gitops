# kubesearch.dev review of `default`-namespace HelmReleases

**Date:** 2026-05-09
**Scope:** all 29 HelmReleases under `kubernetes/default/`
**Axes:** security hardening, reliability/probes, observability (backups & image-pinning out of scope)
**Method:** sampled community deployments via https://kubesearch.dev/ per app, diffed against this repo, kept findings only where ≥50% peer adoption, a clear gap, or meaningful operational benefit.

Tag legend: `[H]` high-value/low-risk · `[M]` medium · `[L]` nice-to-have · `[!]` security gap.

---

## 1. Executive summary — top findings

1. **`runAsNonRoot: true` is missing at pod level on most *arr/media apps** (prowlarr, qbittorrent, radarr, sabnzbd, sonarr, tautulli, readarr) yet appears across the majority of peers. Single biggest consistent gap.
2. **`seccompProfile: { type: RuntimeDefault }` applied inconsistently.** Set on audiobookshelf/seerr/shelfmark/mosquitto/teslamate but missing from plex, the *arr stack, home-assistant, node-red, frigate, zwave2mqtt, ser2sock. Apply uniformly via `defaultPodOptions.securityContext`.
3. **cloudnative-pg operator chart is under-instrumented.** 60–75% of 80 sampled peers enable `monitoring.podMonitorEnabled: true` and `monitoring.grafanaDashboard.create: true` on the operator HelmRelease — you set neither.
4. **EMQX exposes Prometheus at `:18083/api/v5/prometheus/stats` but no ServiceMonitor exists.** Operator already creates the Service.
5. **Several apps still rely on app-template's default TCP probes when better HTTP endpoints exist:** continuwuity (`/_matrix/federation/v1/version`), echo-server (`/healthz`), unifi (HTTPS `:8443/status`), qbittorrent (`/api/v2/app/version`). TCP probes won't catch hung processes. **home-assistant deliberately excluded** — see §3 for the IP-ban / frontend-readiness rationale; TCP is the right call there.
6. **Three apps have no probes at all:** unifi, ser2sock, node-red, teslamate, mousetrap, minecraft-proxy. Each has a known endpoint and silent-hang failure mode.
7. **Native Prometheus endpoints unscraped.** TeslaMate (`:4000/metrics`), Frigate (`/metrics`), Home Assistant (`/api/prometheus`), zwave-js-ui (`/metrics`), EMQX, and CNPG-operator all expose metrics natively but lack ServiceMonitors. Peer adoption is low (0–40%) but operational value is high — these are the apps where silent degradation matters most.
8. **`exportarr` is *not* a real cross-cutting gap.** Despite community lore, sampled adoption across radarr/sonarr/prowlarr peers is ~1–2%. Skip.
9. **Container-level `securityContext` missing on non-app-template charts:** unifi (also no pod-level), emqx CR `coreTemplate`, minecraft-proxy, the four itzg minecraft servers. App-template apps already have this baseline — bring others up to parity.
10. **mousetrap runs as root with writable rootfs and `SETUID/SETGID/CHOWN` capability adds.** Outlier in the fleet. Verify whether the upstream image still requires this in current versions.

---

## 2. Cross-cutting recommendations

### A. Lift `defaultPodOptions.securityContext` to a uniform baseline
Patch every app-template HelmRelease that currently lacks them with:
```yaml
defaultPodOptions:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
```
(Keep existing `runAsUser`/`runAsGroup`/`fsGroup` lines.) Affects ≥10 apps and is the single highest-volume / lowest-risk change.

### B. Replace default TCP probes with explicit HTTP probes where endpoints exist
| App | Endpoint |
|---|---|
| continuwuity | `httpGet /_matrix/federation/v1/version` on 8080 |
| echo-server | `httpGet /healthz` on http port |
| qbittorrent | `httpGet /api/v2/app/version` on WebUI port |
| unifi | `httpGet /status` (scheme: HTTPS) on 8443 |

### C. Fill the ServiceMonitor gaps where the app already exposes metrics
- **cloudnative-pg operator** — toggle `monitoring.podMonitorEnabled` + `monitoring.grafanaDashboard.create` (peer-validated, drop-in)
- **EMQX** — Service already exists; add ServiceMonitor on `:18083/api/v5/prometheus/stats`
- **TeslaMate** — `:4000/metrics`, native, no extra config
- **Home Assistant** — enable `prometheus:` integration in `configuration.yaml`, then ServiceMonitor on `:8123/api/prometheus` with bearer token
- **Frigate** — `:5000/metrics` (0.13+); high signal for camera FPS / GPU latency
- **zwave-js-ui** — `:8091/metrics` via Gateway > Prometheus settings
- **mosquitto** — needs `mosquitto-exporter` sidecar, then ServiceMonitor

### D. Add probes to the apps that have none
| App | Recommended probe |
|---|---|
| unifi | startup + liveness + readiness, HTTPS `/status` :8443, generous startup (Java boot ~60–120s) |
| node-red | HTTP `/` :1880 |
| ser2sock | TCP :10000 |
| teslamate | HTTP `/` :4000 |
| mousetrap | TCP :39842 |
| minecraft-proxy | TCP :25577 |

---

## 3. Per-app findings

### Media / *arr stack

#### audiobookshelf
- Peers sampled: 18 (2 detailed)
- **Security:** aligned; already includes `seccompProfile: RuntimeDefault` (uncommon among peers).
- **Reliability:** [L] startup probe occasionally added by peers; current `/healthcheck` setup matches dominant pattern.
- **Observability:** no peer adoption; no gap.

#### plex
- Peers sampled: 62
- **Security:** [!] missing pod-level `seccompProfile: RuntimeDefault`.
- **Reliability:** aligned — `/identity` is the dominant probe path; startup probe present.
- **Observability:** [L] no clear ServiceMonitor adoption; existing `gatus.home-operations.com/endpoint` annotation already provides external check.

#### prowlarr
- Peers sampled: 97
- **Security:** [M] add `runAsNonRoot: true` at pod level. [L] add `seccompProfile: RuntimeDefault`.
- **Reliability:** aligned (`/ping`).
- **Observability:** exportarr adoption ~1.3% — not a meaningful gap.

#### qbittorrent
- Peers sampled: 81
- **Security:** [!] missing pod-level `runAsNonRoot: true` and `seccompProfile: RuntimeDefault`.
- **Reliability:** [M] ~24 peers use HTTP probe `/api/v2/app/version`; current setup uses default TCP.
- **Observability:** [L] qbittorrent-exporter adoption <5%; not a clear gap.

#### radarr
- Peers sampled: 101
- **Security:** [!] add pod-level `runAsNonRoot: true` and `seccompProfile: RuntimeDefault`.
- **Reliability:** aligned.
- **Observability:** exportarr adoption <2% — no real gap.

#### readarr
- Peers sampled: 16 (2 detailed)
- **Security:** [M] `readOnlyRootFilesystem` currently commented out; ~6/11 peers enable it. The `CHOWN` capability + chown init-container is a workaround peers typically don't need — re-evaluate whether the upstream image still needs it. [L] add `seccompProfile`.
- **Reliability:** aligned (`/ping`).
- **Observability:** no peer adoption; no gap.

#### recyclarr
- Peers sampled: 64
- **Security:** aligned (peers use UID 1000; you use 1001 — fine).
- **Reliability:** aligned (`@daily` + Forbid concurrency). [L] peers commonly set `ttlSecondsAfterFinished: 86400`.
- **Observability:** no peer adoption.

#### sabnzbd
- Peers sampled: 57
- **Security:** [!] add pod-level `runAsNonRoot: true` and `seccompProfile: RuntimeDefault`.
- **Reliability:** [L] ~22 peers add a startup probe (`failureThreshold: 30`).
- **Observability:** zero peer adoption.

#### seerr
- Peers sampled: 24 jellyseerr / 11 overseerr (closest analogues — no direct seerr peer page)
- **Security:** aligned — already uses seccompProfile, runAsNonRoot, readOnlyRootFilesystem.
- **Reliability:** aligned (`/api/v1/status`).
- **Observability:** no peer adoption.

#### shelfmark
- Peers sampled: 15 (you're one of the top peers)
- **Security:** aligned — you set the standard.
- **Reliability:** aligned (`/api/health` :8084).
- **Observability:** no peer adoption.

#### sonarr
- Peers sampled: ~100
- **Security:** [!] add pod-level `runAsNonRoot: true` and `seccompProfile: RuntimeDefault`.
- **Reliability:** aligned (`/ping`).
- **Observability:** exportarr adoption ~1% — no gap.

#### tautulli
- Peers sampled: 50
- **Security:** [!] add pod-level `runAsNonRoot: true` and `seccompProfile: RuntimeDefault`.
- **Reliability:** aligned (`/status` matches 37 peers).
- **Observability:** zero peer adoption.

### Home / IoT

#### home-assistant
- Peers sampled: ~72
- **Security:** matches high-adoption baseline (RO rootfs, drop ALL, non-root 1000). [L] add explicit `seccompProfile: RuntimeDefault` and `runAsNonRoot: true`. [L] ~25% of peers use `hostNetwork: true` for mDNS/HomeKit/Cast — only relevant if you use those integrations.
- **Reliability:** **Keep current TCP probes** (initial recommendation reversed after second pass). Current setup at `home-assistant.yaml:35-44` — TCP on 8123 with `startup: periodSeconds: 10, failureThreshold: 60` (10-min ceiling) — is the right call for HA specifically. Reasons:
  - Re-querying kubesearch shows **22 peers explicitly disable HA probes** (`probes.liveness.enabled: false`) — operators have hit something painful enough to opt out. No clean majority pattern; "60% use HTTP /" from the first pass was overstated.
  - **`http.ip_ban_enabled` footgun:** repeated probes returning 401 (e.g. `/api/`) feed HA's failed-attempt counter and can ban the kubelet source IP, causing cascading restart loops. Especially relevant with the `public` gateway in play.
  - **`/` is not cheap and not stable:** serves the frontend; can take minutes to return 200 during frontend rebuild, recorder migration, or integration init. A liveness probe on `/` with peers' default `failureThreshold: 3, periodSeconds: 10` gives only 30s before kubelet kills the pod — classic restart-loop trigger.
  - **TCP catches the realistic failures:** crash, OOM, port unbound. HA going non-responsive while still listening on 8123 is uncommon, and existing alerting (Gatus, etc.) catches that case anyway.
  - If HTTP is ever wanted later, the safer recipe is `httpGet /manifest.json` (avoids IP-ban path) with `periodSeconds: 30, failureThreshold: 5` — but marginal value over TCP is low.
- **Observability:** [M] ~40% of peers expose the `prometheus:` integration and add a ServiceMonitor on `/api/prometheus` with a long-lived bearer token. Clear gap; high operational value (entity-level metrics, automation latency).

#### node-red
- Peers sampled: ~10
- **Security:** [!] you exceed peer baseline (only ~40% set RO-rootfs/drop-ALL/non-root). Positive outlier. [L] add `seccompProfile: RuntimeDefault` for consistency.
- **Reliability:** [M] no probes; only ~30% of peers add them but for a flow engine that hangs silently this is a clear gap. Suggest `httpGet /` on 1880.
- **Observability:** [L] negligible peer adoption; optional.

#### frigate
- Peers sampled: ~26
- **Security:** [!] you're a positive outlier — 77% of peers run privileged, ~5% have RO-rootfs. You use `PERFMON` cap only. [L] consider adding `readOnlyRootFilesystem: true` with tmpfs `/tmp`. [L] explicit `runAsNonRoot`/UID instead of relying on image default.
- **Reliability:** aligned — `/api/version` matches 80% peer pattern; cache via `emptyDir medium: Memory` matches 92%.
- **Observability:** [M] ServiceMonitor adoption is ~0% in peers, but Frigate exposes Prometheus metrics natively (0.13+). High value (camera FPS, detection latency, GPU inference). Worth filling regardless of low peer adoption.

#### mosquitto
- Peers sampled: ~32
- **Security:** [!] positive outlier — RO-rootfs, drop ALL, non-root 1001, seccomp RuntimeDefault. [L] peers commonly use UID 1883; 1001 works because you control chown via fsGroup.
- **Reliability:** TCP :1883 matches dominant pattern. [L] also probe 9001 (websockets listener).
- **Observability:** [M] `mosquitto-exporter` (sphenlee or junglas) sidecar — peer adoption <5% but standard MQTT metrics path. Clear gap.

#### zwave2mqtt (zwave-js-ui)
- Peers sampled: ~8
- **Security:** [!] positive outlier overall (peers are 62% privileged) but the container has **no `securityContext` block at all**. [M] add `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `readOnlyRootFilesystem: true`. zwave-js-ui only writes to `/usr/src/app/store` (already PVC-mounted) and `/tmp`. The generic-device-plugin avoids any need for privileged.
- **Reliability:** `/health` matches 87% of peers.
- **Observability:** [M] zwave-js-ui exposes Prometheus via Gateway > Prometheus; ~12% of peers add a ServiceMonitor. Easy win for mesh health visibility.

#### ser2sock
- Peers sampled: 0
- **Security:** [M] no `securityContext` at all on the container; `tenstartups/ser2sock` runs as root by default. Add `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `readOnlyRootFilesystem: true`.
- **Reliability:** [M] no probes; add TCP :10000 — silent-die is the failure mode that needs catching.
- **Observability:** no metrics endpoint; nothing actionable.

#### teslamate
- Peers sampled: ~9
- **Security:** [!] positive outlier — non-root 10000, seccomp RuntimeDefault, RO-rootfs, drop ALL.
- **Reliability:** [M] no probes; only ~25–30% of peers add them, but TeslaMate is Phoenix on :4000 and can hang on Tesla API auth. `httpGet /` works for both.
- **Observability:** [H] TeslaMate exposes Prometheus natively at `:4000/metrics` (since v1.27). 0% peer adoption but high value — VIN-level drive/charge stats, API errors. Add ServiceMonitor.

### Infra / network / misc

#### unifi
- Peers sampled: 11 (2 detailed)
- **Security:** [M] peers commonly set `runAsUser/runAsGroup: 999` at pod level; you only set `UNIFI_UID/GID=999` env vars while the pod itself runs default (effectively root). Add `defaultPodOptions.securityContext` with `runAsUser/runAsGroup/fsGroup: 999, runAsNonRoot: true`. RO-rootfs is fine left off (jacobalberty image writes to `/var`).
- **Reliability:** [H] **no probes defined.** Add HTTPS `/status` :8443 liveness+readiness, plus a generous startup probe (60–120s).
- **Observability:** [L] you already run unpoller separately (per recent commit) — that's the standard pattern. No change.

#### emqx (operator + cluster)
- Peers sampled: 4 (operator); cluster CR data thin
- **Security:** [M] operator chart values match peers, but on the EMQX CR `coreTemplate.spec` you set neither `podSecurityContext` nor container `securityContext` nor `resources`. Add `podSecurityContext: { runAsNonRoot: true, fsGroup: 1000 }` and a container `securityContext` (`allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`).
- **Reliability:** [M] set explicit `resources` on `coreTemplate.spec` — operator default is none; a runaway broker can OOM the node.
- **Observability:** [H] EMQX exposes Prometheus at `:18083/api/v5/prometheus/stats`. Add a ServiceMonitor — operator already creates the Service.

#### cloudnative-pg (operator chart)
- Peers sampled: 80
- **Security:** operator defaults sane; no gap.
- **Reliability:** [L] 17/80 peers run `replicaCount: 2`; 19/80 set explicit operator resources (`cpu: 15m`, `mem: 128Mi req / 256Mi lim`). Optional.
- **Observability:** [H] 60/80 peers (75%) set `monitoring.podMonitorEnabled: true`; 55/80 (69%) set `monitoring.grafanaDashboard.create: true`. You set neither at the operator level (only on the Cluster CR). Drop-in fix:
  ```yaml
  monitoring:
    podMonitorEnabled: true
    grafanaDashboard:
      create: true
  ```

#### cloudnative-pg (Cluster CR)
- **Security:** N/A — operator-managed.
- **Reliability:** `enablePDB: false` is intentional (linked rationale) — leave. [L] consider `topologySpreadConstraints` or `affinity.podAntiAffinity` to spread the 2 instances across nodes.
- **Observability:** `monitoring.enablePodMonitor: true` + custom PrometheusRule already in place. Good.

#### continuwuity
- Peers sampled: 7 (3 detailed)
- **Security:** matches peer pattern (UID 1001 vs peers' 1000 — fine).
- **Reliability:** [H] peers use `httpGet /_matrix/federation/v1/version` :8080 + a startup probe (`failureThreshold: 30, periodSeconds: 5`). TCP-only probes won't catch a hung Matrix process.
- **Observability:** [L] continuwuity exposes `/_synapse/metrics`-style Prometheus if `metrics_enabled` is on; optional.

#### echo-server
- Peers sampled: 59 (5 detailed)
- **Security:** [L] 39/59 peers (66%) run `runAsUser: 65534` (nobody); you use 1001. Either is fine. `seccompProfile: RuntimeDefault` you already have.
- **Reliability:** [H] 49/59 peers (83%) use `httpGet /healthz` — and your `LOG_IGNORE_PATH: /healthz` env hints you intended this. Currently the probe is default TCP. Switch to explicit `httpGet /healthz`.
- **Observability:** [L] 9/59 peers run `replicas: 2` for HA on a public endpoint. Since this is on the `public` gateway, consider `replicas: 2` + a PDB.

#### mousetrap
- Peers sampled: 0
- **Security:** [!] runs `runAsUser: 0` (root), `readOnlyRootFilesystem: false`, with `SETUID/SETGID/CHOWN` capability adds — most-privileged app in the fleet. Verify whether current upstream image still requires this; document if so.
- **Reliability:** [M] no probes; add TCP :39842.
- **Observability:** no known metrics endpoint.

#### kei
- Peers sampled: 0
- **Security:** already hardened (1001, drop ALL, RO rootfs).
- **Reliability:** custom TCP probes on 9090 — good.
- **Observability:** ServiceMonitor + custom PrometheusRule already configured. Best-in-class. No change.

#### qui
- Peers sampled: 26 (5 detailed)
- **Security:** matches peers.
- **Reliability:** `/health` matches peer pattern.
- **Observability:** no metrics endpoint; skip.

#### chaptarr
- Peers sampled: 0 (image uses `develop` tag, niche)
- **Security:** hardened (1001, drop ALL, RO rootfs); the `chown-run` init container is a reasonable workaround for RO rootfs needing `/run` writable.
- **Reliability:** `/ping` probe reasonable.
- **Observability:** no known metrics; skip.

### Game servers

#### minecraft (lobby / creative / survival / survival2)
- Peers sampled: 0 (kubesearch chart pages 404 for itzg)
- **Security:** pod-level set (UID 1000, runAsNonRoot). itzg image won't tolerate `readOnlyRootFilesystem` — no improvement viable.
- **Reliability:** all four currently `replicaCount: 0`. Only `creative` has explicit liveness/readiness/startup. [M] when running lobby/survival/survival2, mirror creative's `startupProbe.enabled: true` (`failureThreshold: 30, periodSeconds: 10`) — Minecraft startup with mod downloads exceeds default windows and crash-loops.
- **Observability:** [M] no minecraft-exporter sidecar / ServiceMonitor. itzg chart has no native exporter support — would need `extraDeploy` or a sidecar pattern. Optional, only worth it when servers are active.

#### minecraft-proxy
- Peers sampled: 0
- **Security:** pod-level set; no container-level `securityContext`. [L] add `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`. bungeecord/waterfall needs no caps.
- **Reliability:** [M] no explicit probes (chart default behavior unclear). Add `tcpSocket: 25577`.
- **Observability:** no widely-used bungeecord exporter; skip.

---

## 4. Apps with no useful peer data

| App | Reason |
|---|---|
| chaptarr | Niche; image uses `develop` tag |
| kei | Custom internal app |
| mousetrap | Niche project, no kubesearch entry |
| ser2sock | No kubesearch entry |
| minecraft (itzg) | Chart pages 404 on kubesearch |
| minecraft-proxy | No kubesearch entry |

For these, recommendations are based on app-template conventions and our existing fleet baseline rather than peer evidence.

---

## 5. Prioritized backlog (`[H]` and `[!]` only)

### Security gaps (`[!]`)
1. **mousetrap** — runs as root with writable rootfs and capability adds. Audit upstream for non-root option.
2. **plex / prowlarr / qbittorrent / radarr / sabnzbd / sonarr / tautulli** — add pod-level `runAsNonRoot: true` and `seccompProfile: RuntimeDefault`. (Bulk patch via `defaultPodOptions.securityContext`.)
3. **home-assistant / node-red / frigate / mosquitto / zwave2mqtt / teslamate** — already-hardened (positive outliers); only missing `seccompProfile: RuntimeDefault` for fleet uniformity.

### High-value low-risk (`[H]`)
1. **unifi** — add probes (HTTPS `/status` :8443) + startup (60–120s). No probes today is a clear reliability gap.
2. **continuwuity** — switch from default TCP probe to `httpGet /_matrix/federation/v1/version` + startup probe.
3. **echo-server** — switch from default TCP to `httpGet /healthz` (your env vars already hint at this).
4. **cloudnative-pg operator** — enable `monitoring.podMonitorEnabled: true` + `monitoring.grafanaDashboard.create: true`. Drop-in, peer-validated.
5. **EMQX** — add ServiceMonitor on `:18083/api/v5/prometheus/stats`.
6. **TeslaMate** — add ServiceMonitor on `:4000/metrics` (native).

---

## 6. Notes / out of scope

- Backups & VolSync coverage: not analyzed (only known gap is `minecraft-proxy`, intentional).
- Image pinning / Renovate hygiene: already automated.
- This report is research-only; YAML patches are deferred to follow-up PRs the user will scope.
