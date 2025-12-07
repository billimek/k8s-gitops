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
├── envoy-gateway.yaml              # HelmRelease
├── gateway-classes/
│   ├── gateway-class-standard.yaml # For public/internal
│   └── gateway-class.yaml          # For Tailscale
├── envoy-proxies/
│   ├── envoy-proxy-standard.yaml   # 2 replicas, standard LB
│   └── envoy-proxy.yaml            # 1 replica, Tailscale LB
├── gateways/
│   ├── gateway-public.yaml         # 10.0.6.150
│   ├── gateway-internal.yaml       # 10.0.6.151
│   └── gateway.yaml                # 100.85.60.114
├── routes/
│   ├── https-redirect.yaml         # Global HTTP→HTTPS
│   └── wildcard-route.yaml         # Fallback for Tailscale
└── policies/                       # Traffic policies (Tailscale only)
```

## Key Differences vs Nginx Ingress

| Nginx Ingress | Envoy Gateway |
|---------------|---------------|
| `Ingress` resource | `Gateway` + `HTTPRoute` |
| Annotation-based config | Standard CRD-based policies |
| One IngressClass = one controller | Multiple Gateways = one controller |
| Duplicate Ingress for split-horizon | Single HTTPRoute, multiple parentRefs |
| Limited RBAC separation | Infra (Gateway) vs Apps (HTTPRoute) |

## DNS Integration

HTTPRoutes are discovered by External-DNS and converted to DNS records. See [external-dns/README.md](../external-dns/README.md) for details on how split-horizon DNS works with the three gateways.

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
- LoadBalancer IP not assigned: Check MetalLB config or Tailscale operator
- TLS errors: Verify `acme-crt-secret` exists in `cert-manager` namespace

## Further Reading

- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
