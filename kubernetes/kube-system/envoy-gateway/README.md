# Envoy Gateway

Primary Gateway API controller for L7 HTTP/HTTPS routing. Replaces nginx Ingress with a more flexible, role-oriented architecture.

## Three Gateway Architecture

```
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Public Gateway   │  │ Internal Gateway │  │Tailscale Gateway │
│   10.0.6.150     │  │   10.0.6.151     │  │ 100.85.60.114    │
│  eg-standard     │  │  eg-standard     │  │  eg-tailscale    │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │                     │                      │
    Internet              LAN-Only             Tailnet VPN
  (ports 80/443)      (ISP outage safe)    (secure remote)
```

### 1. Public (`10.0.6.150`)
- Internet-facing services
- Router forwards ports 80/443 here
- DNS: Cloudflare → `eviljungle.com` CNAME

### 2. Internal (`10.0.6.151`)
- LAN-only services
- ISP outage resilient (local DNS + routing)
- DNS: OpnSense host overrides → `10.0.6.151`

### 3. Tailscale (`100.85.60.114`)
- VPN-only access
- No public firewall ports
- DNS: Cloudflare → Tailscale IP

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
│   ├── gateway-class-standard.yaml # eg-standard (public/internal)
│   └── gateway-class.yaml          # eg-tailscale (VPN)
├── envoy-proxies/
│   ├── envoy-proxy-standard.yaml   # 2 replicas, standard LB config
│   └── envoy-proxy.yaml            # 1 replica, Tailscale LB config
├── gateways/
│   ├── gateway-public.yaml         # 10.0.6.150 (internet)
│   ├── gateway-internal.yaml       # 10.0.6.151 (LAN)
│   └── gateway.yaml                # 100.85.60.114 (Tailscale)
├── routes/
│   ├── https-redirect.yaml         # Global HTTP→HTTPS redirect
│   └── wildcard-route.yaml         # Catchall fallback for Tailscale
├── policies/
│   ├── backend-traffic-policy.yaml # Backend connection settings
│   └── client-traffic-policy.yaml  # TLS, HTTP/2, client IP detection
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

Both policies currently apply only to the Tailscale gateway for enhanced security and performance tuning.

## DNS Integration

HTTPRoutes are discovered by External-DNS and converted to DNS records. See [external-dns/README.md](../external-dns/README.md) for details on how split-horizon DNS works with the three gateways.

## IP Address Management

**CRITICAL**: Gateways must have `io.cilium/lb-ipam-ips` annotation to pin their LoadBalancer IPs:

```yaml
metadata:
  annotations:
    io.cilium/lb-ipam-ips: "10.0.6.151"  # Reserves this IP from Cilium LB-IPAM pool
spec:
  addresses:
    - type: IPAddress
      value: 10.0.6.151  # Must match annotation
```

Without this annotation, Cilium LB-IPAM assigns random IPs from the pool, breaking DNS and routing when services are recreated. The annotation ensures the Gateway always gets the same IP.

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
- LoadBalancer IP not assigned: Check Cilium LB-IPAM pool and `io.cilium/lb-ipam-ips` annotation
- Wrong IP assigned: Missing or incorrect `io.cilium/lb-ipam-ips` annotation on Gateway
- TLS errors: Verify `acme-crt-secret` exists in `cert-manager` namespace

## Further Reading

- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
