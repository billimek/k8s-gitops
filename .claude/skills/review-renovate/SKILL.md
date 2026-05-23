# review-renovate

Review Renovate-generated PRs: classify each bump, scan for known hazards, check CI and cluster readiness, auto-merge low-risk changes, and poll until reconciliation is confirmed.

## Usage

```
/review-renovate              # batch: all open Renovate PRs
/review-renovate <PR# | branch>   # single PR
```

## Steps

### 1 — Enumerate PRs

**Batch (no arg):**
```bash
gh pr list --author "app/renovate" --state open \
  --json number,title,headRefName,url,statusCheckRollup
```

**Single PR:**
```bash
gh pr view <PR> --json number,title,headRefName,baseRefName,url,statusCheckRollup
```

Process each PR through the remaining steps. Collect verdicts for the final batch summary.

---

### 2 — Classify the bump

From the PR title and diff, assign one class:

| Class | Pattern |
|-------|---------|
| `digest-only` | SHA/digest change only, no version bump |
| `patch-image` | container image `x.y.Z+1` |
| `minor-image` | container image `x.Y.0` |
| `chart-minor` | Helm chart `x.Y.0` |
| `chart-major` | Helm chart `X.0.0` |
| `grouped` | multiple packages in one PR |

```bash
gh pr diff <PR>
```

Note which HelmRelease(s) or image tags changed, and whether any `values:` keys, securityContext, persistence, or resource fields were touched.

---

### 3 — Changelog

**Skip for `digest-only`.** For all other classes:

**Step 3a — PR body first (Renovate embeds release notes):**
```bash
gh pr view <PR> --json body --jq '.body'
```
Read the "Release Notes" section Renovate injects. If present and covers the full version range, use it — no need to fetch upstream.

**Step 3b — Fallback: upstream releases:**
```bash
gh api repos/<owner>/<repo>/releases --jq \
  '[.[] | {tag: .tag_name, body: .body}] | .[:20]'
```
Fetch the most recent 20 releases and manually filter to the bumped range. Do not rely on tag string comparison — just print them and read the relevant ones.

**Explicitly call out:**
- Breaking changes — config key renames, removed defaults, required new fields
- Schema migrations — CRD version bumps, new required annotations
- Deprecations becoming breaking in a future version
- Security advisories patched in this range

---

### 4 — Known-hazard scan

Grep the diff for these codified patterns and flag any matches:

**app-template 4.x → 5.x**
- `rawResources` key added/removed — requires manifest migration
- ConfigMap names changed from `<release>-<key>` to `<release>` — breaks `persistence.configMap.name` references

**automountServiceAccountToken**
- Removed or default-flipped in chart majors — check if it was previously set explicitly in your values; if absent, the cluster default applies

**CRD apiVersion bumps**
```bash
gh pr diff <PR> | rg 'apiVersion.*v[0-9]alpha|apiVersion.*v[0-9]beta|kind: CustomResourceDefinition'
```

**Key renames / removals in values schema**
```bash
gh pr diff <PR> | rg '^\+.*:.*null|^-.*:' | head -30
```

**Extensible known-footgun list** (update as new ones are discovered):
- `kei` image — SQLite tmp-dir migration on minor bumps; watch for CrashLoopBackOff on first start
- any `home-assistant` major — config breaking changes common; check HA release notes carefully

---

### 5 — Cluster and CI readiness

**CI checks:**
```bash
gh pr checks <PR>
```
Confirm `flux-local` diff and test checks are green. If pending → verdict is `defer`. If failing → verdict is `block`.

**HelmRelease state:**
```bash
# Derive <app> and <namespace> from the diff
flux get helmrelease <app> -n <namespace>
```

**Pod state:**
```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<app>
```

**Gateway check:** If the app has an HTTPRoute pointing to `internal` or `public` gateway in kube-system, flag it — the post-merge step will need to watch for envoy stale endpoints (dead pod IPs in xDS cache after image bumps).

---

### 6 — Decision summary and merge

Print before acting:

```
PR #N    : <title>
Class    : <class>
Hazards  : none | <list>
CI       : green | pending | failing
Cluster  : ready | HR failed | stuck pods
Verdict  : auto-merge | needs-confirmation | defer | block
```

**Verdict rules:**

- **`auto-merge`** — class is `digest-only` or `patch-image`, hazards empty, CI green, cluster ready. Merge without asking.
- **`needs-confirmation`** — `minor-image`, `chart-minor`, `chart-major`, or `grouped`; OR any class with non-empty hazards; OR cluster not ready. Stop and ask the user before proceeding.
- **`defer`** — CI checks still pending. Skip this PR in the batch; include in final summary.
- **`block`** — CI failing, or hazards that require manual intervention. Stop the entire batch and ask.

**If stuck pods exist before merging:**
```bash
kubectl scale deployment <app> --replicas=0 -n <namespace>
```

**If the HelmRelease is in a failed state, suspend before merging:**
```bash
flux suspend helmrelease <app> -n <namespace>
```

**Merge:**
```bash
gh pr merge <PR> --squash --delete-branch
```

**If suspended, resume after merge:**
```bash
flux resume helmrelease <app> -n <namespace>
```

---

### 7 — Post-merge: poll and auto-recover

Poll every 15s for up to 5 minutes:
```bash
flux get helmrelease <app> -n <namespace>
```

**If Ready=True within 5 min:**
- Run `kubectl get pods -n <namespace>` and confirm pods are Running.
- If app is gateway-routed, rollout-restart envoy to clear stale xDS endpoints:
  ```bash
  kubectl rollout restart deployment/envoy-gateway -n kube-system
  kubectl rollout restart deployment/<envoy-proxy-deploy> -n kube-system
  ```

**If still not Ready after 5 min — auto-invoke stuck-HR recovery:**
```bash
# Scale down stuck workload
kubectl scale deployment <app> --replicas=0 -n <namespace>
# Force reconcile
flux reconcile helmrelease <app> -n <namespace> --with-source
```
Then re-poll for another 5 minutes. If still failing, report to user and stop.

---

### 8 — Batch summary

After processing all PRs, print one line per PR:

```
#N   auto-merged    Ready=True   <title>
#N   confirmed+merged Ready=True  <title>
#N   deferred       CI pending   <title>
#N   blocked        hazards: ... <title>
```
