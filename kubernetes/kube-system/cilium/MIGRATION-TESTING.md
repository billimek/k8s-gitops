# Cilium Ingress Controller Migration - Phase 1 Testing

This document describes the testing and validation process for Phase 1 of the nginx → Cilium ingress migration.

## Overview

**Branch:** `feat/cilium-ingress-migration`
**Issue:** https://github.com/billimek/k8s-gitops/issues/4959

Phase 1 sets up Cilium's ingress controller alongside the existing nginx controllers, with parallel test hostnames to validate functionality before migrating production traffic.

## Changes Made

### 1. Cilium Ingress Controller Configuration
**File:** `kubernetes/kube-system/cilium/cilium.yaml`

Enabled Cilium's ingress controller with:
- `loadbalancerMode: dedicated` - Creates separate LoadBalancer services per IngressClass
- **Public IngressClass:** `cilium` with fixed IP `10.0.6.152`
- **Internal IngressClass:** `cilium-tailscale` (will use Tailscale LoadBalancer)

### 2. Tailscale LoadBalancer Configuration
**File:** `kubernetes/kube-system/cilium/cilium-ingress-tailscale-lb.yaml`

Patches the Cilium-created LoadBalancer service to use `loadBalancerClass: tailscale` for Tailscale VPN access.

### 3. Test Ingress Resource
**File:** `kubernetes/default/emqx/ingress-test.yaml`

Creates `emqx-test.eviljungle.com` as a parallel test hostname that:
- Uses `cilium-tailscale` IngressClass
- Points to the same emqx-dashboard service backend
- Has external-dns annotations for OpnSense internal DNS

## Pre-Deployment Checklist

Before applying changes:

- [ ] Verify BGP pool has `10.0.6.152` available
  ```bash
  kubectl get ciliumbgppeeringpolicies -A
  kubectl get ciliumloadbalancerippools -A
  ```

- [ ] Confirm Tailscale operator is running and functional
  ```bash
  kubectl get pods -n tailscale
  ```

- [ ] Review current nginx-tailscale services
  ```bash
  kubectl get svc -n kube-system ingress-nginx-tailscale-controller
  ```

## Deployment Steps

### Step 1: Apply Cilium Configuration

```bash
# The Flux HelmRelease will reconcile automatically after commit/push
# Or manually trigger:
flux reconcile helmrelease cilium -n kube-system --with-source
```

**Expected Result:**
- Cilium pods will restart (rolling update)
- Two new LoadBalancer services will be created:
  - `cilium-ingress-cilium` (10.0.6.152)
  - `cilium-ingress-cilium-tailscale`

### Step 2: Verify Cilium Ingress Controller

```bash
# Check Cilium operator logs
kubectl logs -n kube-system -l app.kubernetes.io/part-of=cilium-operator --tail=100

# Verify LoadBalancer services
kubectl get svc -n kube-system | grep cilium-ingress

# Expected output:
# cilium-ingress-cilium              LoadBalancer   10.x.x.x   10.0.6.152   80:xxxxx/TCP,443:xxxxx/TCP
# cilium-ingress-cilium-tailscale    LoadBalancer   10.x.x.x   <pending>    80:xxxxx/TCP,443:xxxxx/TCP
```

### Step 3: Patch Tailscale LoadBalancer

The `cilium-ingress-tailscale-lb.yaml` should be applied automatically by Flux. If not, manually apply:

```bash
kubectl apply -f kubernetes/kube-system/cilium/cilium-ingress-tailscale-lb.yaml
```

**Verify Tailscale LoadBalancer:**
```bash
kubectl get svc cilium-ingress-cilium-tailscale -n kube-system -o yaml | grep -A5 "spec:"

# Should show:
#   loadBalancerClass: tailscale
#   type: LoadBalancer
```

Wait for Tailscale to assign an IP:
```bash
kubectl get svc cilium-ingress-cilium-tailscale -n kube-system --watch

# Eventually shows:
# cilium-ingress-cilium-tailscale   LoadBalancer   10.x.x.x   100.x.x.x   80:xxxxx/TCP,443:xxxxx/TCP
```

**Get Tailscale hostname:**
```bash
kubectl get svc cilium-ingress-cilium-tailscale -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Example output: cilium-internal.tailnet-xxxx.ts.net
```

### Step 4: Apply Test Ingress

```bash
kubectl apply -f kubernetes/default/emqx/ingress-test.yaml

# Verify Ingress resource
kubectl get ingress -n default emqx-dashboard-test
```

### Step 5: Verify External-DNS Records

```bash
# Check external-dns-opnsense logs
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns-opnsense --tail=50

# Look for:
# - "CREATE: emqx-test.eviljungle.com A [Tailscale IP]"
```

**Manually verify in OpnSense:**
- Navigate to Services → Unbound DNS → Overrides
- Look for `emqx-test.eviljungle.com` A record pointing to Tailscale IP

## Validation Tests

### Test 1: DNS Resolution

From a machine connected to Tailscale:

```bash
# Should resolve to Tailscale LoadBalancer IP (100.x.x.x)
nslookup emqx-test.eviljungle.com

# Or
dig emqx-test.eviljungle.com +short
```

### Test 2: TLS Certificate

```bash
# Should show valid Let's Encrypt certificate for *.eviljungle.com
curl -vI https://emqx-test.eviljungle.com 2>&1 | grep -A10 "SSL certificate"

# Or use openssl
echo | openssl s_client -servername emqx-test.eviljungle.com -connect emqx-test.eviljungle.com:443 2>/dev/null | openssl x509 -noout -text | grep -A2 "Subject Alternative Name"
```

### Test 3: Service Accessibility

```bash
# Should return HTTP 200 or redirect to login
curl -I https://emqx-test.eviljungle.com

# Or visit in browser (must be on Tailscale VPN):
# https://emqx-test.eviljungle.com
```

**Expected:** EMQX dashboard login page loads successfully

### Test 4: Backend Connectivity

From within the cluster:

```bash
# Exec into a test pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh

# Test internal service connectivity
curl -I http://emqx-dashboard.default.svc.cluster.local:18083
```

### Test 5: Client IP Preservation

Check EMQX logs to verify client IPs are preserved (not showing Envoy pod IPs):

```bash
kubectl logs -n default -l app.kubernetes.io/name=emqx --tail=50 | grep -i "http request"
```

### Test 6: Concurrent Access (Both Ingresses)

Verify both ingresses work simultaneously:

```bash
# Original nginx-tailscale ingress (should still work)
curl -I https://emqx.eviljungle.com

# New cilium-tailscale ingress (new test)
curl -I https://emqx-test.eviljungle.com
```

**Both should return successful responses.**

## Monitoring

### Key Metrics to Watch

```bash
# Cilium Envoy proxy metrics
kubectl exec -n kube-system <cilium-envoy-pod> -- wget -qO- localhost:9964/metrics | grep ingress

# View Hubble flows for ingress traffic
hubble observe --namespace default --pod emqx-dashboard --follow

# Check for errors in Cilium logs
kubectl logs -n kube-system -l app.kubernetes.io/part-of=cilium --tail=100 | grep -i error
```

### Grafana Dashboards

- **Cilium Metrics:** `https://grafana.eviljungle.com/d/cilium-metrics`
- **Envoy Proxy:** `https://grafana.eviljungle.com/d/16088` (if available)

## Troubleshooting

### Issue: Tailscale LoadBalancer stuck in `<pending>`

```bash
# Check Tailscale operator logs
kubectl logs -n tailscale -l app=operator

# Verify loadBalancerClass is set
kubectl get svc cilium-ingress-cilium-tailscale -n kube-system -o yaml | grep loadBalancerClass
```

**Fix:** Ensure `cilium-ingress-tailscale-lb.yaml` is applied.

### Issue: DNS not resolving

```bash
# Verify external-dns is processing the Ingress
kubectl logs -n kube-system -l app.kubernetes.io/instance=external-dns-opnsense --tail=100

# Check for annotation issues
kubectl get ingress emqx-dashboard-test -n default -o yaml | grep annotations -A5
```

**Fix:** Ensure `external-dns.alpha.kubernetes.io/internal: "true"` annotation is present.

### Issue: TLS certificate not working

```bash
# Check if cert-manager secret is accessible
kubectl get secret -n cert-manager acme-crt-secret

# Verify ReferenceGrant allows access from kube-system
kubectl get referencegrants -n cert-manager
```

**Fix:** The ReferenceGrant at `kubernetes/cert-manager/referencegrant.yaml` should already allow this.

### Issue: HTTP 503 / Backend unavailable

```bash
# Check Envoy upstream connectivity
kubectl exec -n kube-system <cilium-envoy-pod> -- wget -qO- localhost:9901/clusters | grep emqx

# Verify service endpoints exist
kubectl get endpoints emqx-dashboard -n default
```

## Rollback Procedure

If issues arise, rollback is simple:

### Option 1: Remove Test Ingress Only
```bash
kubectl delete ingress emqx-dashboard-test -n default
# DNS record will be automatically removed by external-dns
```

### Option 2: Disable Cilium Ingress Controller

Edit `kubernetes/kube-system/cilium/cilium.yaml`:
```yaml
ingressController:
  enabled: false  # Change to false
```

Then reconcile:
```bash
flux reconcile helmrelease cilium -n kube-system --with-source
```

### Option 3: Full Branch Rollback

```bash
git checkout master
git push origin master
flux reconcile source git flux-system
```

## Success Criteria

Phase 1 is considered successful when:

- [x] Cilium ingress controller pods are running and healthy
- [x] Both LoadBalancer services have IPs assigned (public: 10.0.6.152, Tailscale: 100.x.x.x)
- [x] `emqx-test.eviljungle.com` resolves to Tailscale LoadBalancer IP
- [x] EMQX dashboard is accessible via `https://emqx-test.eviljungle.com`
- [x] TLS certificate is valid (Let's Encrypt wildcard)
- [x] Client IPs are preserved in application logs
- [x] No errors in Cilium/Envoy logs
- [x] External-DNS automatically creates/updates DNS records
- [x] Original `emqx.eviljungle.com` (nginx) continues working without disruption

**Duration:** Monitor for 24-48 hours with no issues before proceeding to Phase 2.

## Next Steps (Phase 2)

After successful validation:

1. Migrate production hostname by changing `kubernetes/default/emqx/ingress.yaml`:
   ```yaml
   ingressClassName: cilium-tailscale  # Changed from nginx-tailscale
   ```

2. Monitor for issues. If stable, proceed to migrate additional services.

3. Follow migration waves as outlined in issue #4959:
   - Simple services (echo-server)
   - Media services (sonarr, radarr, etc.)
   - Monitoring services (grafana, victoria-metrics)
   - IoT services (home-assistant, frigate, node-red)
   - Complex services (unifi, proxmox with custom backend configs)

## References

- **GitHub Issue:** https://github.com/billimek/k8s-gitops/issues/4959
- **Cilium Ingress Docs:** https://docs.cilium.io/en/stable/network/servicemesh/ingress/
- **Tailscale Kubernetes Operator:** https://tailscale.com/kb/1236/kubernetes-operator
