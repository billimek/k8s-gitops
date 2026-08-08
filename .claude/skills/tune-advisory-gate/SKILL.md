# tune-advisory-gate

Measure the precision of the `claude/renovate-review` advisory-finding merge gate
(`.github/scripts/detect-advisory-findings.sh`, wired into the "Publish review status"
step of `.github/workflows/renovate-review.yaml`) against a corpus of real review bodies,
then offer to tune the script and/or the reviewer prompts.

The gate flips the required `claude/renovate-review` status to `failure` whenever an
approved review's `**New features worth adopting**` / `**Known issues**` sections carry
a bulleted, non-negative item. Its whole job is to hold only PRs that need a human to
read something before merging. This skill answers: *of the PRs it's currently holding,
how many actually needed that?*

Background: introduced for [#6046](https://github.com/billimek/k8s-gitops/issues/6046)
(`e3195c5b3`), refined once already for a false-positive class where the reviewer put
inline prose on the section header line (`543791f4e`, prompted by PR #6059). Precision
still degrades in a different way -- see Step 4 -- because the reviewer uses these
sections as a general interesting-notes bucket and writes its own actionability verdict
into bullet prose rather than a structured field.

## Usage

```
/tune-advisory-gate                # analyze the last ~80 Renovate PRs (default)
/tune-advisory-gate --limit N      # widen or narrow the PR window
```

---

## Shell environment note

The Bash tool runs **zsh** on macOS, which does not word-split unquoted variables the
way `bash`/`sh` do. A `for e in $expected_nonzero` loop over a space-separated string
silently iterates once with the whole string as one token instead of once per word --
this bit a prior session and cost a debugging detour. Wrap any script that relies on
word-splitting in `bash -c '...'`, or use a zsh-native array (`ids=(a b c); for id in
$ids`), or use Python. Prefer `bash -c` for anything ported from a bash one-liner.

---

## Steps

### 1 -- Build the review-body corpus

```bash
mkdir -p /tmp/tune-advisory-gate && cd /tmp/tune-advisory-gate
for pr in $(gh pr list --repo billimek/k8s-gitops --state all --author "app/renovate" \
    --limit ${LIMIT:-80} --json number --jq '.[].number'); do
  gh api "repos/billimek/k8s-gitops/pulls/$pr/reviews" \
    --jq '[.[] | select(.user.login=="claude[bot]" or .user.login=="github-actions[bot]")] | last | .body // ""' \
    > "rrbody-$pr.txt" 2>/dev/null
done
ls rrbody-*.txt | wc -l
```

Skip PRs whose body is empty (ungated update types -- digest/github-actions -- never get
a `claude[bot]` review; `detect-advisory-findings.sh` on an empty string returns 0 anyway
so they're harmless to leave in).

### 2 -- Run the current gate against the corpus

```bash
bash -c '
cd /tmp/tune-advisory-gate
S=/Users/jeff/src/k8s-gitops/.github/scripts/detect-advisory-findings.sh
for f in rrbody-*.txt; do
  pr=${f#rrbody-}; pr=${pr%.txt}
  c=$(bash "$S" < "$f")
  [ "$c" != "0" ] && echo "$pr count=$c"
done | sort -n'
```

This is the list of PRs the gate is currently holding (or would have held, for already-
merged ones -- the fingerprint cache means a merged PR's cached review body is still a
valid sample of what the reviewer writes).

### 3 -- Dump the blocking bullets for each held PR

```bash
bash -c '
cd /tmp/tune-advisory-gate
for pr in <space-separated list from step 2>; do
  echo "===================== $pr"
  awk "/^\*\*(New features worth adopting|Known issues)/{s=1;print;next}
       s&&/^(\*\*|---)/{s=0}
       s&&/^[[:space:]]*[-*][[:space:]]/{print}" "rrbody-$pr.txt"
done'
```

### 4 -- Hand-classify each held PR

Read every dumped bullet block from Step 3 and judge each held PR `actionable` or
`noise`, citing the reviewer's own words:

- **`noise`** signals (the reviewer already told you this doesn't matter): "no action
  needed", "no action required", "not required", "not actionable for this PR", "already
  auto-adopted by this bump", "optional, not required", "purely optional -- current ...
  behavior is unchanged", "just included in this bump".
- **`actionable`** signals: a recommended repo/config change, an explicit "worth keeping
  an eye on" / "worth a passive watch" risk callout, or a `could not verify` /
  `unable to confirm` hedge the human should resolve.

Report per-PR: PR number, one-line reason, verdict. Then the summary:
`precision = actionable / (actionable + noise)`, and separately the overall block rate
(`held / corpus size`).

**Do not** try to close the precision gap by extending `NEGATIVE_RE` in
`detect-advisory-findings.sh` with non-actionability phrases like "no action needed" or
"optional". That regex fires on the *content* of a bullet regardless of whether the
finding itself is real -- tested against the corpus during the last round, it also
matched PR #6010's genuine finding (phrased "Purely optional -- current behavior is
unchanged"), trading false positives for a false negative on exactly the case the gate
exists to catch. If precision is low, the fix belongs in Step 5.

### 5 -- If precision is low, propose a fix

The known-good pattern (validated during the `543791f4e` round, precision ~25% on an
80-PR sample) is a **reviewer-declared merge-gate line** instead of inferring
actionability from bullet presence -- ask for the judgment structurally since the model
already computes it in prose:

1. Add a required trailer to both prompt templates in
   `.github/workflows/renovate-review.yaml` (primary ~L407, escalated ~L546):
   `**Merge gate**: clear | hold -- [one-line reason]`. Definition: `hold` only when a
   human must read or act before merge (a recommended repo change, a risk to watch after
   rollout, or something that could not be verified); everything else -- informational,
   already-auto-adopted, optional-and-not-recommended, not-applicable -- is `clear`.
2. `.github/scripts/detect-advisory-findings.sh` reads that line when present and treats
   it as authoritative (`hold` -> count 1, `clear` -> count 0), falling back to the
   existing bullet scan for older cached bodies that predate the field.

Editing either the workflow or any `.github/scripts/*.sh` file invalidates every cached
review fingerprint (`review-fingerprint.sh` folds both into `config_hash`), so the next
trigger on any open PR produces a fresh review carrying the new field -- no manual
cache-busting needed.

Preview the exact diff in the conversation before applying. Re-run Steps 1-4 (a smaller
`--limit`, e.g. 15-20, is enough) against a handful of freshly-triggered reviews to
confirm the new field lands correctly before declaring it fixed.

### 6 -- Report and offer to apply

Print:

```
Corpus       : N PRs (open+merged Renovate PRs, last <limit>)
Held         : M PRs (<list>)
Actionable   : A  (<PR list + one-line reason each>)
Noise        : M-A  (<PR list + one-line reason each>)
Precision    : A/M
```

Then ask: *"Apply the merge-gate-line fix from Step 5? (yes/no/adjust)"*. Do not commit
or push unless explicitly asked (global safety rule). Keep all edits ASCII-only -- no
emojis or em-dashes.

---

## Cleanup

```bash
rm -rf /tmp/tune-advisory-gate
```
