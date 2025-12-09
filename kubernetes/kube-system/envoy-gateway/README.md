# Envoy Gateway

Primary Gateway API controller for L7 HTTP/HTTPS routing. Replaces nginx Ingress with a more flexible, role-oriented architecture.

## Two Gateway Architecture

```
┌──────────────────┐  ┌──────────────────┐
│ Public Gateway   │  │ Internal Gateway │
│   10.0.6.150     │  │   10.0.6.151     │
│  eg-standard     │  │  eg-standard     │
└────────┬─────────┘  └────────┬─────────┘
         │                     │
    Internet         LAN + Tailscale (via App Connector)
  (ports 80/443)      (ISP outage safe)
                            ↑
                     ┌──────┴────────┐
                     │ App Connector │
                     │ (advertises   │
                     │ 10.0.6.0/24)  │
                     └───────────────┘
```

### 1. Public (`10.0.6.150`)
- Internet-facing services
- Router forwards ports 80/443 here
- DNS: Cloudflare → `eviljungle.com` CNAME

### 2. Internal (`10.0.6.151`)
- LAN-only services
- ISP outage resilient (local DNS + routing)
- DNS: OpnSense host overrides → `10.0.6.151`
- **Tailscale access**: Via App Connector routing `10.0.6.0/24` subnet

## Component Hierarchy

```
EnvoyProxy (infrastructure config)
  ├─ replicas, resources, LoadBalancer settings
  │
GatewayClass (infrastructure template)
  ├─ references EnvoyProxy config
  │
Gateway (infrastructure instance)
  ├─ uses GatewayClass
  ├─ defines listeners (HTTP/HTTPS)
  ├─ requests LoadBalancer IP
  │
HTTPRoute (application routing)
  ├─ references Gateway(s)
  ├─ defines hostname/path matching
  └─ points to backend Service
```

## Directory Structure

```
envoy-gateway/
├── envoy-gateway.yaml              # HelmRelease for Envoy Gateway controller
├── gateway-classes/
│   └── gateway-class-standard.yaml # eg-standard (public/internal)
├── envoy-proxies/
│   └── envoy-proxy-standard.yaml   # 2 replicas, standard LB config
├── gateways/
│   ├── gateway-public.yaml         # 10.0.6.150 (internet)
│   └── gateway-internal.yaml       # 10.0.6.151 (LAN + Tailscale via App Connector)
├── routes/
│   ├── https-redirect.yaml         # Global HTTP→HTTPS redirect
│   ├── wildcard-public.yaml        # Wildcard catchall for Public
│   └── wildcard-internal.yaml      # Wildcard catchall for Internal
├── policies/
│   ├── backend-traffic-policy.yaml # Backend connection settings
│   └── client-traffic-policy.yaml  # TLS, HTTP/2, client IP detection
├── error-pages/
│   └── error-pages.yaml            # Custom error page service
├── monitoring/
│   ├── podmonitor-envoy-proxy.yaml     # Prometheus scraping for proxies
│   └── servicemonitor-envoy-gateway.yaml # Prometheus scraping for controller
└── external-proxmox.yaml           # Example: External service proxy route
```

## Key Differences vs Nginx Ingress

| Nginx Ingress | Envoy Gateway |
|---------------|---------------|
| `Ingress` resource | `Gateway` + `HTTPRoute` |
| Annotation-based config | Standard CRD-based policies |
| One IngressClass = one controller | Multiple Gateways = one controller |
| Duplicate Ingress for split-horizon | Single HTTPRoute, multiple parentRefs |
| Limited RBAC separation | Infra (Gateway) vs Apps (HTTPRoute) |

## Tailscale Integration

Remote access via Tailscale is handled by the **App Connector** (see `/kubernetes/kube-system/tailscale/`), which advertises the `10.0.6.0/24` subnet to the Tailscale network. This allows Tailscale clients to route traffic to the `internal` gateway at `10.0.6.151`.

## Traffic Policies

**BackendTrafficPolicy**: Controls connection settings to backend services
- Compression (Gzip)
- Connection buffer limits
- TCP keepalive
- Request timeouts

**ClientTrafficPolicy**: Controls client-facing connection settings
- TLS configuration (min version, ALPN)
- HTTP/2 settings
- Client IP detection (X-Forwarded-For handling)
- Request timeouts

Both policies apply to all Gateways (public and internal) for consistent security and performance tuning.

## Error Pages

Both gateways have wildcard catchall routes (`*.eviljungle.com`) that route undefined hostnames to a custom error-pages service using the [tarampampam/error-pages](https://github.com/tarampampam/error-pages) project.

**Route Matching Precedence**: Gateway API ensures specific hostnames (e.g., `grafana.eviljungle.com`) always take precedence over wildcard patterns (`*.eviljungle.com`), so existing applications are unaffected.

**DNS Exclusion**: Wildcard routes have `external-dns.alpha.kubernetes.io/exclude: "true"` to prevent External-DNS from creating wildcard DNS records. Only explicit application routes create DNS entries.

## DNS Integration

HTTPRoutes are discovered by External-DNS and converted to DNS records. See [external-dns/README.md](../external-dns/README.md) for details on how split-horizon DNS works with the three gateways.

## IP Address Management

**CRITICAL**: Gateways must use `spec.infrastructure.annotations` to pin their LoadBalancer IPs. This propagates the annotation to the Service that Envoy Gateway creates:

```yaml
spec:
  infrastructure:
    annotations:
      lbipam.cilium.io/ips: "10.0.6.151"  # Propagated to LoadBalancer Service
```

Without `spec.infrastructure.annotations`, Cilium LB-IPAM assigns random IPs from the pool. The annotation ensures deterministic IP assignment.

## Debugging

```bash
# Check gateways
kubectl get gateways -n kube-system
kubectl describe gateway public -n kube-system

# Check routes
kubectl get httproutes -A
kubectl describe httproute myapp -n default

# Check Envoy proxies
kubectl get pods -n kube-system -l app.kubernetes.io/name=envoy
kubectl logs -n kube-system -l app.kubernetes.io/name=envoy

# Check controller
kubectl logs -n kube-system -l control-plane=envoy-gateway
```

**Common issues:**
- HTTPRoute not attaching: Check `hostnames` matches Gateway listener pattern
- LoadBalancer IP not assigned: Check Cilium LB-IPAM pool and `spec.infrastructure.annotations`
- Dual IP assigned: Missing `lbipam.cilium.io/ips` in `spec.infrastructure.annotations`
- TLS errors: Verify `acme-crt-secret` exists in `cert-manager` namespace

## Further Reading

- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
