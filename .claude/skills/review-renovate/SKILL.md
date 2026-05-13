# review-renovate

Review a Renovate-generated PR: fetch the diff, read the upstream changelog for the version range, flag breaking changes or schema migrations, verify cluster readiness, then merge via the Renovate branch — never directly to master.

## Usage

```
/review-renovate [PR# | branch]
```

If no argument is given, uses the current branch's open PR.

## Steps

### 1 — Identify the PR

```bash
gh pr view <PR> --json number,title,headRefName,baseRefName,url
```

Record: PR number, head branch, package/image bumped, old version, new version.

### 2 — Fetch the diff

```bash
gh pr diff <PR>
```

Note:
- Which HelmRelease(s) or image tags are bumped.
- Whether any `values:` schema keys are added, removed, or renamed.
- Whether securityContext, persistence, or resource fields changed.

### 3 — Read the upstream changelog

Derive the source from the diff (chart repo, container image registry, GitHub releases).

**GitHub-hosted projects:**
```bash
gh api repos/<owner>/<repo>/releases \
  --jq '[.[] | select(.tag_name >= "v<old>" and .tag_name <= "v<new>") | {tag: .tag_name, body: .body}]'
```

**Helm charts not on GitHub:** WebFetch the chart repo's `CHANGELOG.md` for the version range.

Explicitly call out:
- **Breaking changes** — config key renames, removed defaults, required new fields.
- **Schema migrations** — CRD version bumps, new required annotations.
- **Deprecations** that become breaking in a future version.
- **Security advisories** patched in this range.

### 4 — Check cluster readiness

Per `CLAUDE.md` → Troubleshooting → "Stuck HelmRelease":

```bash
# Is the HelmRelease already failed/exhausted?
flux get helmrelease <app> -n <namespace>

# Any pods stuck from a prior revision?
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<app>
```

If stuck pods exist, scale to 0 first:
```bash
kubectl scale deployment <app> --replicas=0 -n <namespace>
```

If the HelmRelease is in a failed state, suspend before merging and resume after:
```bash
flux suspend helmrelease <app> -n <namespace>
# merge step
flux resume helmrelease <app> -n <namespace>
```

### 5 — Decision summary

Print this before merging:

```
Package  : <name>  <old> → <new>
Breaking : yes/no — <summary or "none">
Schema   : yes/no — <summary or "none">
Security : yes/no — <CVEs or "none">
Cluster  : ready / needs scale-to-0 / HR stuck
```

Stop and ask the user to confirm before proceeding if any of the following are true:
- Breaking changes found.
- Schema migration required.
- HelmRelease is currently in a failed state.

Otherwise proceed to step 6.

### 6 — Merge via the Renovate branch

**Never push directly to master.** Always merge through the PR:

```bash
gh pr merge <PR> --squash --delete-branch
```

After merging, confirm FluxCD picks up the change:

```bash
flux reconcile kustomization cluster-apps --with-source
flux get helmrelease <app> -n <namespace>
```

Report the final HelmRelease status to the user.
