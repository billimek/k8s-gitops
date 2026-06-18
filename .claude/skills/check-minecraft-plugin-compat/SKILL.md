# check-minecraft-plugin-compat

Check whether plugins pinned via direct CDN URL (because they lacked a tagged Paper build
for the running Minecraft version) have since published real support, and whether plugins
marked optional (`?`) in `MODRINTH_PROJECTS` can be re-enabled. Reports findings and offers
to apply safe reverts -- does not auto-merge anything.

## Background

During the 26.2 Paper upgrade (see git history around commit `af4d1bb57` and surrounding
commits in `kubernetes/default/minecraft/`), several plugins had no Paper build tagged for
26.2 in their Modrinth/Hangar metadata. Two different fixes were applied depending on the
actual root cause, which this skill must distinguish between:

- **Metadata-only gap** (plugin jar actually works, just not tagged): pinned via
  `APPLY_EXTRA_FILES: plugins<<CDN-URL>>` to bypass the Modrinth/Hangar compatibility
  resolver entirely. Example: `essentialsx`, `locked-chests-plugin`, `luckperms`.
- **Real incompatibility** (plugin code itself refuses to run / crashes on the new MC
  version): marked optional in `MODRINTH_PROJECTS` (`coreprotect?`) so it's cleanly skipped
  instead of installed-but-broken. `nochatreports-spigot-paper` was outright replaced with
  a different plugin (`BlockReports`) because its NMS-version lookup crashed.

**Critical lesson learned**: do not trust Modrinth's declared `game_versions` metadata or
even an explicit `project:versionId` pin as proof a plugin works. CoreProtect's jar
downloads fine via direct URL but prints `Minecraft 26.2 is not supported.` and disables
itself at runtime. NoChatReports crashes with a `NullPointerException` in its own NMS
version-detection code. **Always check the actual pod startup logs after a test restart,
not just whether the resolver/download succeeded.**

There is no Renovate datasource (native or community) for Modrinth/Hangar plugin versions
-- confirmed via web search, this is a known gap. That's why this is a skill instead of a
`.renovate/*.json5` custom datasource: Modrinth CDN URLs embed an opaque version ID and a
filename that must change together, and there's no reliable way for Renovate's versioning
schemes to determine which opaque ID is "newer."

## Usage

```
/check-minecraft-plugin-compat
```

No arguments. Scans all three server configs under `kubernetes/default/minecraft/`.

## Steps

### 1 -- Find the current pins and optional entries

```bash
rg -n "plugins<https://(cdn\.modrinth\.com|hangarcdn\.papermc\.io)" kubernetes/default/minecraft/*.yaml
rg -n -A1 "MODRINTH_PROJECTS" kubernetes/default/minecraft/*.yaml
```

From the `APPLY_EXTRA_FILES` URLs, extract the Modrinth project ID (segment after
`/data/`) or Hangar owner/slug (segment after `/plugins/`). From `MODRINTH_PROJECTS`,
note any entries ending in `?` -- those are the optional/skipped ones to re-check.

### 2 -- Determine the running Minecraft version

Read it from the live world data rather than assuming -- the cluster may have moved on
since this skill was written:

```bash
kubectl exec -n default minecraft-survival-0 -- cat /data/version_history.json
```

Use the `currentVersion` MC number (e.g. `26.2`) as the target to check compatibility
against.

### 3 -- Query Modrinth for each pinned/optional project

```bash
curl -s "https://api.modrinth.com/v2/project/<slug-or-id>/version?loaders=%5B%22paper%22%5D" \
  | jq -r '.[0] | "version_number=\(.version_number) id=\(.id) date=\(.date_published) game_versions=\(.game_versions[-5:])"'
```

A project is a candidate for reverting to plain auto-resolve (no pin, no `?`) only if the
target MC version string appears in `game_versions`. A metadata match is necessary but
**not sufficient** -- proceed to step 5 before declaring it fixed.

### 4 -- Query Hangar for Hangar-hosted plugins (e.g. BlockReports)

```bash
curl -s "https://hangar.papermc.io/api/v1/projects/<owner>/<slug>/versions?limit=5" \
  | jq -r '.result[] | "\(.name) platforms=\(.platformDependencies)"'
curl -s "https://hangar.papermc.io/api/v1/projects/<owner>/<slug>/versions/<version>" \
  | jq -r '.platformDependencies'
```

Also worth periodically re-checking whether `nochatreports-spigot-paper` itself has
published real 26.2 support, in case the team wants to revert from BlockReports back to
it -- check the actual crash signature is gone (see step 5), not just the version tag.

### 5 -- Functionally verify candidates before recommending a revert

For each candidate found in steps 3-4, this skill must not just report "metadata now
matches" -- it must actually test it, the same way this was diagnosed originally:

1. Edit the relevant `MODRINTH_PROJECTS`/`APPLY_EXTRA_FILES` entry locally (uncommitted).
2. `flux suspend helmrelease <app> -n default` to stop Flux from fighting a failed test.
3. Push a throwaway commit is NOT needed for this -- instead patch the live StatefulSet
   pod env directly is also not appropriate (see GitOps note below). Prefer: commit the
   candidate change to a scratch branch, **but do not push/reconcile against `master`**
   until step 5 confirms it. If a live functional test is needed, ask the user first --
   direct pod/PVC mutation outside git is a deliberate, confirmed exception, not a default
   action (this was flagged mid-session previously).
4. Check `kubectl logs -n default <pod> | rg -i "error|exception|disab|not supported"` for
   the specific plugin's enable sequence. Only a clean `Enabling <Plugin>` with no
   following ERROR/Exception counts as confirmed working.

### 6 -- Report findings

```
Plugin              Pin type        Latest available    Target MC tagged?   Functionally verified?   Recommendation
essentialsx         CDN pin         2.23.0               yes                 not yet tested            test before reverting
coreprotect         optional (?)    23.3                  no                  n/a                       still skip
nochatreports       (replaced)      2.8.0                 yes                 not yet tested            consider reverting from BlockReports
```

Ask the user before applying any revert -- do not auto-commit. If they approve, follow the
same careful rollout procedure used originally: suspend the HelmRelease, commit + push +
reconcile, resume, watch the pod via `Monitor` until ready, then check logs for the
specific plugin's enable line before declaring success.
