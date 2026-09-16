# External-DNS Setup

This directory contains the dual External-DNS setup for automatic DNS management of `eviljungle.com` domain, replacing the static CoreDNS zone configuration with automated DNS management.

## Architecture

The External-DNS setup provides a resilient split-horizon DNS architecture with three access pathways:

```text
External Users:
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Query DNS     │───►│   Cloudflare     │───►│ Public Gateway  │
│                 │    │   (1.1.1.1)      │    │  10.0.6.150     │
└─────────────────┘    └──────────────────┘    └─────────────────┘

Tailscale Users:
┌─────────────────┐    ┌──────────────────┐    ┌───────────────────────┐
│   Query DNS     │───►│  Tailscale DNS   │───►│  App Connector Pod    │
│                 │    │ (100.100.100.100)│    │  (uses cluster DNS)   │
└─────────────────┘    └──────────────────┘    └───────────┬───────────┘
                                                           │
                                                           ▼
                                                   ┌─────────────────┐
                                                   │Internal Gateway │
                                                   │   10.0.6.151    │
                                                   └─────────────────┘

Internal Users (LAN):
┌─────────────────┐    ┌──────────────────┐    ┌───────────────────────┐
│   Query DNS     │───►│   OpnSense       │───►│ Internal Gateway      │
│                 │    │   (10.0.7.1)     │    │   10.0.6.151          │
└─────────────────┘    └──────────────────┘    └───────────────────────┘
                                 │
                                 ▼ (if no host override)
                        ┌──────────────────┐
                        │   Cloudflare     │
                        │   (fallback)     │
                        └──────────────────┘
```

## DNS Resolution Strategy

### OpnSense Configuration

- **Domain Forward**: `eviljungle.com` → Forward to Cloudflare (1.1.1.1)
- **Host Overrides**: Created by External-DNS for internal services (overrides the domain forward)

### Cloudflare Configuration

- **Public Records**: Created by External-DNS for public services (pointing to Public Gateway or external IPs)

### Resolution Flow

1. **Internal users** query `app.eviljungle.com` → OpnSense
   - If host override exists → Returns local IP (`10.0.6.151` - Envoy Gateway internal)
   - If no override → Forwards to Cloudflare → Returns Public IP
2. **External users** query `app.eviljungle.com` → Cloudflare directly
   - Returns configured target (Public Gateway IP)
3. **Tailscale users** query `app.eviljungle.com` → Tailscale DNS
   - App Connector resolves via cluster DNS → `10.0.6.151`
   - Routes traffic through connector pod to internal gateway

## Gateway Architecture

### Two Gateways (All Envoy Gateway)

1. **`public`** - Public-facing services on `10.0.6.150` (Router forwards ports 80/443 here)
2. **`internal`** - LAN-only services on `10.0.6.151` (OpnSense points here, Tailscale routes here via App Connector)

### Service Exposure Patterns

Which of the two `gateway-httproute` external-dns instances (cloudflare or opnsense) manages a route's DNS record is determined entirely by which Gateway (`public` or `internal`) the route's `parentRefs` points to - `external-dns-cloudflare` runs with `--gateway-name=public`, `external-dns-opnsense` with `--gateway-name=internal`. No DNS annotation is needed on HTTPRoutes.

#### Standard Public Service (Envoy Gateway)

```yaml
route:
  app:
    parentRefs:
      - name: public
        namespace: kube-system
    hostnames:
      - "app.eviljungle.com"
```

#### Tailnet-Only Service (Internal Gateway + App Connector)

```yaml
route:
  main:
    parentRefs:
      - name: internal
        namespace: kube-system
    hostnames:
      - "app.eviljungle.com"
```

**Note**: Tailscale users access via App Connector which routes to the internal gateway. The target (`10.0.6.151`) comes from the `internal` Gateway object's own `external-dns.kubernetes.io/target` annotation, not a per-route annotation - external-dns's gateway-httproute source only reads target overrides off the Gateway/ListenerSet, never off individual routes.

#### Split-Horizon Service (Public + Internal + Tailscale)

```yaml
route:
  # External/Public Access
  public:
    parentRefs:
      - name: public
        namespace: kube-system
    hostnames:
      - "app.eviljungle.com"
  
  # Internal/LAN Access + Tailscale VPN Access
  internal:
    parentRefs:
      - name: internal
        namespace: kube-system
    hostnames:
      - "app.eviljungle.com"
```

#### Service-Sourced Record (no Gateway parentRef)

A bare `Service` (LoadBalancer/ExternalName) has no Gateway to filter on, so `--gateway-name` can't scope it. These are handled by two small dedicated instances (`external-dns-cloudflare-services` / `external-dns-opnsense-services`, `sources: [service]` only) gated by a `dns.eviljungle.com/visibility` annotation - see [external-dns's own FAQ](https://kubernetes-sigs.github.io/external-dns/latest/faq/#how-do-i-specify-multiple-dns-sources) on why annotation-filter can't be scoped to one source within a shared instance. Currently only `minecraft-router`'s two Services use this:

```yaml
service:
  internal-lb:
    annotations:
      dns.eviljungle.com/visibility: internal
      external-dns.kubernetes.io/hostname: mc.eviljungle.com
      external-dns.kubernetes.io/target: "10.0.6.106"
  external-cname:
    annotations:
      dns.eviljungle.com/visibility: external
      external-dns.kubernetes.io/hostname: mc.eviljungle.com
      external-dns.kubernetes.io/target: direct.eviljungle.com
```

**Result**: 
- **Cloudflare**: `app.eviljungle.com` -> Public IP (via Envoy Gateway Public)
- **OpnSense**: `app.eviljungle.com` -> `10.0.6.151` (LAN IP - via Envoy Gateway Internal)
- **Tailscale**: `app.eviljungle.com` -> `10.0.6.151` (via App Connector routing)

This ensures that during an ISP outage, local devices can still access the service via the LAN IP, while remote devices use either the public gateway (from internet) or Tailscale VPN (via App Connector).

## Components

### 1. External-DNS OpnSense (`external-dns-opnsense.yaml`)

- Manages internal DNS records in OpnSense Unbound as **host overrides**
- `sources: [gateway-httproute]`, scoped via `--gateway-name=internal`
- Creates A records pointing to `10.0.6.151` (Envoy Gateway Internal)
- Uses webhook provider with `crutonjohn/external-dns-opnsense-webhook`

### 2. External-DNS Cloudflare (`external-dns-cloudflare.yaml`)

- Manages external DNS records in Cloudflare
- `sources: [gateway-httproute]`, scoped via `--gateway-name=public`
- Uses native Cloudflare provider
- **Registry**: `txt` with `txtOwnerId: k8s-external` for proper record lifecycle management

### 3. External-DNS OpnSense/Cloudflare Services (`external-dns-{opnsense,cloudflare}-services.yaml`)

- Same providers as above, but `sources: [service]` only, for the handful of
  bare Services (LoadBalancer/ExternalName) that need DNS records and have no
  Gateway parentRef to scope by - see "Service-Sourced Record" above
- Gated by `--annotation-filter=dns.eviljungle.com/visibility=<internal|external>`
- **Registry**: `txt` with `txtOwnerId: k8s-internal-svc` / `k8s-external-svc`

### 4. Credentials

- `opnsense-credentials.yaml`: OpnSense API credentials from 1Password
- `cloudflare-credentials.yaml`: Cloudflare API token from 1Password

## ISP Outage Resilience

### Services That Will Work During Internet Outages

Any app with a `route` block attached to the `internal` Gateway will remain accessible because:

1. DNS query goes to OpnSense (local)
2. OpnSense finds the host override (created by External-DNS)
3. Returns local IP (`10.0.6.151`)
4. Connection made entirely within local network via Envoy Gateway

**Critical services configured for internal access:**

- `plex.eviljungle.com`
- `hass.eviljungle.com` (Home Assistant)
- `request.eviljungle.com` (Jellyseerr)
- `abs.eviljungle.com` (Audiobookshelf)
- All monitoring dashboards (Grafana, VictoriaMetrics, etc.)
- Media management (Radarr, Sonarr, Prowlarr, etc.)
- Home automation (Node-RED, Z-Wave JS UI, EMQX)
- Infrastructure (UniFi, Rook-Ceph, Proxmox, MinIO)

### Services That Will Fail During Outages

Services without internal DNS records will fail because:

1. DNS query goes to OpnSense (local)
2. No host override found
3. OpnSense tries to forward to Cloudflare (fails - no internet)
4. DNS resolution fails

## Services Currently Managed by External-DNS

### Internal DNS (OpnSense Host Overrides)

- All internal services → `10.0.6.151` (Envoy Gateway Internal)

### External DNS (Cloudflare Records)

- Public services → `eviljungle.com` (CNAME) or Public IP (via Envoy Gateway Public)

This architecture provides maximum flexibility: external users get proper public access, internal users get optimized local routing, tailnet users get secure access via App Connector, and critical services remain available during internet outages.
