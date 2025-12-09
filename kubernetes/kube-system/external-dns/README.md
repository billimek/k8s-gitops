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
    annotations:
      external-dns.alpha.kubernetes.io/internal: "true"
      external-dns.alpha.kubernetes.io/target: "10.0.6.151"
    parentRefs:
      - name: internal
        namespace: kube-system
    hostnames:
      - "app.eviljungle.com"
```

**Note**: Tailscale users access via App Connector which routes to the internal gateway.

#### Split-Horizon Service (Public + Internal + Tailscale)

```yaml
route:
  # External/Public Access
  public:
    annotations:
      external-dns.alpha.kubernetes.io/external: "true"
    parentRefs:
      - name: public
        namespace: kube-system
    hostnames:
      - "app.eviljungle.com"
  
  # Internal/LAN Access + Tailscale VPN Access
  internal:
    annotations:
      external-dns.alpha.kubernetes.io/internal: "true"
      external-dns.alpha.kubernetes.io/target: "10.0.6.151"
    parentRefs:
      - name: internal
        namespace: kube-system
    hostnames:
      - "app.eviljungle.com"
```

**Result**: 
- **Cloudflare**: `app.eviljungle.com` -> Public IP (via Envoy Gateway Public)
- **OpnSense**: `app.eviljungle.com` -> `10.0.6.151` (LAN IP - via Envoy Gateway Internal)
- **Tailscale**: `app.eviljungle.com` -> `10.0.6.151` (via App Connector routing)

This ensures that during an ISP outage, local devices can still access the service via the LAN IP, while remote devices use either the public gateway (from internet) or Tailscale VPN (via App Connector).

## Components

### 1. External-DNS OpnSense (`external-dns-opnsense.yaml`)

- Manages internal DNS records in OpnSense Unbound as **host overrides**
- Watches for `HTTPRoute` with `external-dns.alpha.kubernetes.io/internal=true`
- Creates A records pointing to `10.0.6.151` (Envoy Gateway Internal)
- Uses webhook provider with `crutonjohn/external-dns-opnsense-webhook`

### 2. External-DNS Cloudflare (`external-dns-cloudflare.yaml`)

- Manages external DNS records in Cloudflare
- Watches for `HTTPRoute` with `external-dns.alpha.kubernetes.io/external=true`
- Uses native Cloudflare provider
- **Registry**: `txt` with `txtOwnerId: k8s-external` for proper record lifecycle management

### 3. Credentials

- `opnsense-credentials.yaml`: OpnSense API credentials from 1Password
- `cloudflare-credentials.yaml`: Cloudflare API token from 1Password

## ISP Outage Resilience

### Services That Will Work During Internet Outages

Any service with `external-dns.alpha.kubernetes.io/internal=true` annotation will remain accessible because:

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
