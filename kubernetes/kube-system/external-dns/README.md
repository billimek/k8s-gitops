# External-DNS Setup

This directory contains the dual External-DNS setup for automatic DNS management of `eviljungle.com` domain, replacing the static CoreDNS zone configuration with automated DNS management.

## Architecture

The External-DNS setup provides a resilient split-horizon DNS architecture with three ingress pathways:

```text
External Users:
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Query DNS     │───►│   Cloudflare     │───►│  nginx/nginx-   │
│                 │    │   (1.1.1.1)      │    │  tailscale      │
└─────────────────┘    └──────────────────┘    └─────────────────┘

Internal Users:
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Query DNS     │───►│   OpnSense       │───►│  Local Services │
│                 │    │   (10.0.7.1)     │    │  (10.0.6.150)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
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

- **Wildcard Record**: `*.eviljungle.com` → `100.65.132.11` (nginx-tailscale IP - fallback for undefined services)
- **Specific Records**: Created by External-DNS for external services
- **Manual Record**: `nginx-tailscale.eviljungle.com` → `100.65.132.11` (target for tailscale ingresses)

### Resolution Flow

1. **Internal users** query `app.eviljungle.com` → OpnSense
   - If host override exists → Returns local IP (`10.0.6.150`)
   - If no override → Forwards to Cloudflare → Returns wildcard (`100.65.132.11`)
2. **External users** query `app.eviljungle.com` → Cloudflare directly
   - If specific record exists → Returns configured target
   - If no record → Returns wildcard (`100.65.132.11`)

## Ingress Architecture

### Three Ingress Controllers

1. **`nginx`** - Public-facing services on `10.0.6.150`
2. **`nginx-tailscale`** - Tailnet-only services on `100.65.132.11`
3. **`tailscale`** - Native Tailscale ingress (not used in this setup)

### Service Exposure Patterns

#### Standard Public Service (nginx)

```yaml
# External record: app.eviljungle.com → eviljungle.com (public IP)
# Internal record: app.eviljungle.com → 10.0.6.150 (nginx)
ingress:
  external:
    className: nginx
    annotations:
      external-dns.alpha.kubernetes.io/external: "true"
      external-dns.alpha.kubernetes.io/target: "eviljungle.com"
  internal:
    className: nginx
    annotations:
      external-dns.alpha.kubernetes.io/internal: "true"
      external-dns.alpha.kubernetes.io/target: "10.0.6.150"
```

#### Tailnet-Only Service (nginx-tailscale)

```yaml
# External record: app.eviljungle.com → nginx-tailscale.eviljungle.com → 100.65.132.11
ingress:
  tailscale:
    className: nginx-tailscale
    annotations:
      external-dns.alpha.kubernetes.io/external: "true"
      external-dns.alpha.kubernetes.io/target: "nginx-tailscale.eviljungle.com"
```

#### Fallback Behavior

Services without specific DNS records automatically resolve to the Cloudflare wildcard (`*.eviljungle.com` → `100.65.132.11`), routing them to the `nginx-tailscale` controller. This provides a secure default where undefined services are only accessible to tailnet users.

## Components

### 1. External-DNS OpnSense (`external-dns-opnsense.yaml`)

- Manages internal DNS records in OpnSense Unbound as **host overrides**
- Watches for ingresses/services with `external-dns.alpha.kubernetes.io/internal=true`
- Creates A records pointing to `10.0.6.150` (nginx controller)
- Uses webhook provider with `crutonjohn/external-dns-opnsense-webhook`

### 2. External-DNS Cloudflare (`external-dns-cloudflare.yaml`)

- Manages external DNS records in Cloudflare
- Watches for ingresses/services with `external-dns.alpha.kubernetes.io/external=true`
- Uses native Cloudflare provider
- **Registry**: `txt` with `txtOwnerId: k8s-external` for proper record lifecycle management

### 3. Credentials

- `opnsense-credentials.yaml`: OpnSense API credentials from 1Password
- `cloudflare-credentials.yaml`: Cloudflare API token from 1Password

## Usage Patterns

### Internal-Only Service (ISP Outage Resilient)

```yaml
annotations:
  external-dns.alpha.kubernetes.io/internal: "true"
  external-dns.alpha.kubernetes.io/target: "10.0.6.150"
```

**Result**: OpnSense host override created, service accessible during internet outages

### External Public Service

```yaml
annotations:
  external-dns.alpha.kubernetes.io/external: "true"
  external-dns.alpha.kubernetes.io/target: "eviljungle.com"
```

**Result**: Cloudflare record created pointing to public IP

### Tailnet-Only Service

```yaml
annotations:
  external-dns.alpha.kubernetes.io/external: "true"
  external-dns.alpha.kubernetes.io/target: "nginx-tailscale.eviljungle.com"
```

**Result**: Cloudflare CNAME created pointing to tailscale IP

### Dual Access (Public + Internal Optimization)

**Method**: Create two separate ingresses with unique paths to avoid NGINX conflicts:

```yaml
# External ingress
metadata:
  name: app-external
  annotations:
    external-dns.alpha.kubernetes.io/external: "true"
    external-dns.alpha.kubernetes.io/target: "eviljungle.com"
spec:
  ingressClassName: nginx
  rules:
    - host: app.eviljungle.com
      http:
        paths:
          - path: /
---
# Internal ingress  
metadata:
  name: app-internal
  annotations:
    external-dns.alpha.kubernetes.io/internal: "true"
    external-dns.alpha.kubernetes.io/target: "10.0.6.150"
spec:
  ingressClassName: nginx
  rules:
    - host: app.eviljungle.com
      http:
        paths:
          - path: /internal-dns-only  # Unique path to avoid conflicts
```

**Result**: Both Cloudflare and OpnSense records created for maximum resilience

## ISP Outage Resilience

### Services That Will Work During Internet Outages

Any service with `external-dns.alpha.kubernetes.io/internal=true` annotation will remain accessible because:

1. DNS query goes to OpnSense (local)
2. OpnSense finds the host override (created by External-DNS)
3. Returns local IP (`10.0.6.150`)
4. Connection made entirely within local network

**Critical services configured for internal access:**

- `plex.eviljungle.com`
- `hass.eviljungle.com` (Home Assistant)
- `request.eviljungle.com` (Jellyseerr)
- `abs.eviljungle.com` (Audiobookshelf)
- `mc.eviljungle.com` (Minecraft proxy - special case with LoadBalancer service)

### Services That Will Fail During Outages

Services without internal DNS records will fail because:

1. DNS query goes to OpnSense (local)
2. No host override found
3. OpnSense tries to forward to Cloudflare (fails - no internet)
4. DNS resolution fails

## Services Currently Managed by External-DNS

### Internal DNS (OpnSense Host Overrides)

- `plex.eviljungle.com` → `10.0.6.150` (nginx ingress)
- `hass.eviljungle.com` → `10.0.6.150` (nginx ingress)
- `request.eviljungle.com` → `10.0.6.150` (nginx ingress)
- `abs.eviljungle.com` → `10.0.6.150` (nginx ingress)
- `mc.eviljungle.com` → `10.0.6.106` (LoadBalancer service)

### External DNS (Cloudflare Records)

- `plex.eviljungle.com` → `eviljungle.com` (CNAME)
- `hass.eviljungle.com` → `eviljungle.com` (CNAME)
- `request.eviljungle.com` → `eviljungle.com` (CNAME)
- `abs.eviljungle.com` → `eviljungle.com` (CNAME)
- `flux-webhook.eviljungle.com` → `eviljungle.com` (CNAME)
- `www.eviljungle.com` → `eviljungle.com` (CNAME)

### Manual Records (One-time Setup)

- `eviljungle.com` A record → Router public IP (for port forwarding)
- `nginx-tailscale.eviljungle.com` A record → `100.65.132.11`
- `*.eviljungle.com` A record → `100.65.132.11` (wildcard fallback)

This architecture provides maximum flexibility: external users get proper public access, internal users get optimized local routing, tailnet users get secure access, and critical services remain available during internet outages. The wildcard fallback ensures that any undefined service defaults to tailnet-only access, providing a secure-by-default posture.
