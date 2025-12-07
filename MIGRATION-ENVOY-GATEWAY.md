# Gateway Consolidation: Cilium → Envoy Gateway

## Overview
Consolidating from dual gateway setup (Cilium + Envoy) to Envoy Gateway only for simplified operations and unified observability.

## Migration Plan

### Phase 1: Deploy Envoy Gateway Infrastructure ✓
1. ✓ Created new GatewayClass `eg-standard` for public/internal traffic
2. ✓ Created EnvoyProxy config `standard-proxy-config` with LoadBalancer settings
3. ✓ Created Gateway `public` (10.0.6.150) with Envoy
4. ✓ Created Gateway `internal` (10.0.6.151) with Envoy
5. ✓ Updated HTTPS redirect to cover all three gateways
6. ✓ Commented out Cilium gateway resources

### Phase 2: Deploy & Validate
1. Commit and push changes to branch
2. Apply manually or wait for Flux reconciliation
3. Verify new Envoy gateways are created and get correct IPs:
   ```fish
   kubectl get gateway -n kube-system
   kubectl get svc -n kube-system | grep envoy
   ```
4. Check HTTPRoute status on affected apps:
   ```fish
   kubectl get httproute -A -o wide
   ```
5. Test connectivity to affected apps:
   - audiobookshelf (abs.eviljungle.com)
   - echo-server (echo.eviljungle.com)
   - home-assistant (hass.eviljungle.com)
   - jellyseerr (jellyseerr.eviljungle.com)
   - plex (plex.eviljungle.com)
   - prowlarr (prowlarr.eviljungle.com)
   - flux-webhook

### Phase 3: Cleanup (after validation)
1. Delete Cilium gateway files completely:
   ```fish
   rm kubernetes/kube-system/cilium/gateway/*.yaml
   ```
2. Update documentation if needed

## Affected Applications
- **Public/Internal routes (12 total)**:
  - audiobookshelf (app + internal)
  - echo-server (app + internal)
  - home-assistant (app + internal)
  - jellyseerr (app + internal)
  - plex (app + internal)
  - prowlarr (app)
  - flux-webhook

- **Tailscale routes**: No changes needed (already on Envoy Gateway)

## IP Assignments
- **public**: 10.0.6.150 (external DNS → eviljungle.com)
- **internal**: 10.0.6.151 (internal DNS → 10.0.6.151)
- **tailscale-gateway**: 100.85.60.114 (Tailscale network)

## Rollback Plan
If issues occur:
1. Uncomment Cilium gateway resources
2. Comment out or delete Envoy gateway resources
3. Git revert and push

## Benefits
- ✅ Single gateway controller to manage
- ✅ Unified observability (all traffic through Envoy metrics)
- ✅ Richer L7 features available (rate limiting, auth, etc.)
- ✅ Simpler troubleshooting

## Trade-offs
- ⚠️ Loss of Cilium eBPF datapath optimization for public routes
- ⚠️ Slightly higher resource usage (Envoy proxy pods)
- ⚠️ Migration requires coordination to avoid downtime
