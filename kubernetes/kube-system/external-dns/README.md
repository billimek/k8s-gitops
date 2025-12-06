# External-DNS Setup

This directory contains the dual External-DNS setup for automatic DNS management of `eviljungle.com` domain, replacing the static CoreDNS zone configuration with automated DNS management.

## Architecture

The External-DNS setup provides a resilient split-horizon DNS architecture with three ingress pathways:

```text
External Users:
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Query DNS     │───►│   Cloudflare     │───►│  Cilium Gateway │
│                 │    │   (1.1.1.1)      │    │  (Public IP)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘

Tailscale Users:
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Query DNS     │───►│   Cloudflare     │───►│  Envoy Gateway  │
│                 │    │   (specific A)   │    │  (Tailscale IP) │
└─────────────────┘    └──────────────────┘    └─────────────────┘

Internal Users:
┌─────────────────┐    ┌──────────────────┐    ┌───────────────────────┐
│   Query DNS     │───►│   OpnSense       │───►│  Local Services       │
│                 │    │   (10.0.7.1)     │    │  Cilium: 10.0.6.151   │
└─────────────────┘    └──────────────────┘    └───────────────────────┘
                                │
                                ▼ (if no override)
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

- **Specific Records**: Created by External-DNS for external services (pointing to Envoy Gateway Tailscale IP)
- **Public Records**: Created by External-DNS for public services (pointing to Cilium Gateway Public IP)

### Resolution Flow

1. **Internal users** query `app.eviljungle.com` → OpnSense
   - If host override exists → Returns local IP (`10.0.6.151`)
   - If no override → Forwards to Cloudflare → Returns Tailscale IP (accessible via VPN) or Public IP
2. **External users** query `app.eviljungle.com` → Cloudflare directly
   - Returns configured target (Tailscale IP or Public IP)

## Gateway Architecture

### Three Gateways

1. **`public` (Cilium)** - Public-facing services on `10.0.6.150` (Router forwards ports 80/443 here)
2. **`internal` (Cilium)** - LAN-only services on `10.0.6.151` (OpnSense points here)
3. **`tailscale-gateway` (Envoy)** - Tailnet-only services on Tailscale IP (e.g., `100.85.60.114`)

### Service Exposure Patterns

#### Standard Public Service (Cilium)

```yaml
route:
  app:
    parentRefs:
      - name: public
        namespace: kube-system
    hostnames:
      - "app.eviljungle.com"
```

#### Tailnet-Only Service (Envoy Gateway)

```yaml
route:
  main:
    annotations:
      external-dns.alpha.kubernetes.io/external: "true"
      external-dns.alpha.kubernetes.io/target: "envoy-tailscale.drake-eel.ts.net"
    parentRefs:
      - name: tailscale-gateway
        namespace: kube-system
    hostnames:
      - "app.eviljungle.com"
```

#### Tailnet Service with ISP Outage Resilience (Split-Horizon)

```yaml
route:
  # External/VPN Access (via Envoy Gateway)
  main:
    annotations:
      external-dns.alpha.kubernetes.io/external: "true"
      external-dns.alpha.kubernetes.io/target: "envoy-tailscale.drake-eel.ts.net"
    parentRefs:
      - name: tailscale-gateway
        namespace: kube-system
    hostnames:
      - "app.eviljungle.com"
  
  # Internal/LAN Access (via Cilium Gateway)
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
- **Cloudflare**: `app.eviljungle.com` -> `100.85.60.114` (Tailscale IP)
- **OpnSense**: `app.eviljungle.com` -> `10.0.6.151` (LAN IP)

This ensures that during an ISP outage, local devices can still access the service via the LAN IP, while remote devices use the Tailscale VPN.

## Components

### 1. External-DNS OpnSense (`external-dns-opnsense.yaml`)

- Manages internal DNS records in OpnSense Unbound as **host overrides**
- Watches for `HTTPRoute` with `external-dns.alpha.kubernetes.io/internal=true`
- Creates A records pointing to `10.0.6.151` (Cilium Internal Gateway)
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
4. Connection made entirely within local network via Cilium Gateway

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

- All internal services → `10.0.6.151` (Cilium Internal Gateway)

### External DNS (Cloudflare Records)

- Public services → `eviljungle.com` (CNAME) or Public IP
- Tailscale services → `100.85.60.114` (Envoy Gateway Tailscale IP)

This architecture provides maximum flexibility: external users get proper public access, internal users get optimized local routing, tailnet users get secure access, and critical services remain available during internet outages.
