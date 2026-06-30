# tune-renovate-review

Mine recent `renovate-review` action runs to surface prompt inefficiencies, permission gaps,
tier mis-routing, and cost outliers -- then offer to apply the highest-impact fixes to the workflow.

## Usage

```
/tune-renovate-review                # analyze the last ~20 gated runs (default)
/tune-renovate-review --limit N      # widen or narrow the run window
/tune-renovate-review <runId|PR#>    # deep-dive a single run
```

---

## Shell environment note

The Bash tool runs **zsh** on macOS. Use `ids=(a b c)` array syntax and `for id in $ids`.
Do NOT use bash `$()` inside a `for` header or fish `set` syntax -- both fail in zsh.
Use Python 3 for any multi-line data processing; it avoids quoting and pipeline pitfalls.

---

## Steps

### 1 -- Establish baseline

Read the workflow and its commit history so findings don't re-propose already-reverted ideas.
Run these two commands in parallel:

```bash
git log --oneline -20 -- .github/workflows/renovate-review.yaml
```

```bash
cat .github/workflows/renovate-review.yaml
```

The primary tuning targets are:

- **`Select model tier` step**: the `title` regex that routes each PR to a model + max-turns.
- **`claude` step `--allowedTools` arg**: the `Bash(...)` allowlist passed to the action.
- **`Gather PR evidence` step**: writes `pr-context.md`; a finding where the model re-fetches
  PR data instead of reading that file maps here.
- **`Tool Use Efficiency` section** (in the prompt): guidance on parallelizing independent
  lookups in a single turn.
- **`Shell & Tool Conventions` section** (in the prompt): allowlist rules, anti-thrash rule,
  and permission-denial guidance.
- **`Repo File Discovery` section** (in the prompt): guidance on using Glob/Read before
  upstream API calls.
- **`Review Depth` section** (in the prompt): per-tier turn-target bands (light 5-7 turns /
  full 12-18 / deep 20-30) and the turn-budget rule.

Anything the git log shows was previously added and then reverted must be explicitly excluded
from this session's findings.

---

### 2 -- Enumerate recent gated runs

```bash
gh run list --workflow=renovate-review.yaml --limit 30 \
  --json databaseId,conclusion,status,createdAt,displayTitle,event
```

Keep only runs where `status == "completed"` and `conclusion != "cancelled"`. Work from the most
recent 20 (or `--limit N` from the invocation). Single-run mode: use the provided run ID or look
up the run ID for the given PR number:

```bash
gh run list --workflow=renovate-review.yaml --limit 50 \
  --json databaseId,displayTitle \
  --jq '.[] | select(.displayTitle | test("PR #<N>|<PR title>"))'
```

---

### 3 -- Download all logs and analyze in one pass

**Download all logs to temp files first** (one Bash call with a loop -- do not store in shell
variables, large logs silently truncate):

```bash
ids=(ID1 ID2 ID3 ...)   # paste the databaseId list from Step 2
for id in $ids; do
  gh run view "$id" --log >/tmp/rr_$id.log 2>/dev/null
done
```

**Then run a single Python script** to extract all signals and print the summary table.
This avoids repeated `rg`/`grep` tool calls (and the permission prompts they each trigger):

```python
import re, glob, os, json

fields = {}
for f in sorted(glob.glob("/tmp/rr_*.log")):
    id = os.path.basename(f)[3:-4]
    raw = open(f, encoding="utf-8", errors="replace").read()

    model    = (re.search(r'--model ([\w.-]+)', raw) or ['',''])[1] if re.search(r'--model', raw) else ''
    maxturns = (re.search(r'--max-turns (\d+)', raw) or ['',''])[1]
    turns    = ''
    cost     = ''
    subtype  = ''
    # result record is the last occurrence
    for m in re.finditer(r'"num_turns":\s*(\d+)', raw): turns = m.group(1)
    for m in re.finditer(r'"total_cost_usd":\s*([\d.]+)', raw): cost = m.group(1)
    for m in re.finditer(r'"subtype":\s*"(success|error_max_turns|error_during_execution)"', raw):
        subtype = m.group(1)

    cmds = re.findall(r'"command":\s*"((?:[^"\\]|\\.)*)"', raw)
    decoded = []
    for c in cmds:
        try: c = json.loads('"' + c + '"')
        except: pass
        decoded.append(c.replace('\n', ' ; '))

    denials = [m.group(0) for m in re.finditer(r'"permission_denials":\s*\[[^\]]+\]', raw)
               if '[]' not in m.group(0)]
    errors  = []
    for m in re.finditer(r'"is_error":\s*true', raw):
        seg = raw[max(0, m.start()-400):m.start()]
        ts  = re.findall(r'"(?:text|content)":\s*"((?:[^"\\]|\\.)*)"', seg)
        if ts: errors.append(ts[-1][:160].replace('\n', ' '))

    fields[id] = dict(model=model, maxturns=maxturns, turns=turns, cost=cost,
                      subtype=subtype, cmds=decoded, denials=denials, errors=errors)

# Summary table
tier_map = {'sonnet': 'son', 'haiku': 'hku'}
print(f"{'Run ID':<15} {'Tier':<12} {'Turns/Budget':<14} {'Subtype':<25} {'Cost':<10} {'Denials'}")
print('-'*95)
for id, d in fields.items():
    tier = tier_map.get(d['model'], d['model'][-6:])
    bud  = d['maxturns']
    trn  = d['turns']
    print(f"{id:<15} {tier+'/'+bud:<12} {trn+'/'+bud:<14} {d['subtype']:<25} ${d['cost']:<9} {len(d['denials'])}")

# Per-run detail
print()
for id, d in fields.items():
    if d['cmds'] or d['denials'] or d['errors']:
        print(f"\n=== {id} commands ===")
        for i, c in enumerate(d['cmds'], 1):
            print(f"  {i:2}. {c[:160]}")
        for e in d['errors']:
            print(f"  ERROR: {e}")
        for dn in d['denials']:
            print(f"  DENIAL: {dn[:120]}")
```

Run the script with: `python3 /tmp/analyze_rr.py` (or inline via `python3 - <<'PY' ... PY`).

**Cleanup** at the end of the session:
```bash
rm -f /tmp/rr_*.log /tmp/analyze_rr.py
```

---

### 4 -- Derive findings

Analyze the full run window and group findings into the four categories below. Each finding must
cite specific run IDs, repeat-counts, and the exact step or section of the workflow to change.
Order within each category by frequency (most runs affected first).

**Do not create a finding for something the Step 1 history shows was already tried and reverted.**

#### A. Permission gaps

Evidence: non-empty `permission_denials` array, or `"is_error": true` results whose message
contains "denied", "not allowed", or "prefix rule".

Proposed fix: add the missing `Bash(<command-prefix>:*)` entry to the `--allowedTools` arg in
the `claude` step. If the command is already documented in the prompt's **`Shell & Tool
Conventions`** section but the model still trips it, the doc wording is the bug -- propose a
rewrite of that guidance instead.

#### B. Turn efficiency and waste

Evidence: `subtype == error_max_turns`; `num_turns` at or within 2 of the budget; consecutive
`"command"` entries that appear in separate turns and have no data dependency (could be issued in
parallel); repeated near-identical `Grep`/`Glob`/`gh api` calls (thrash) in the same run.

Map to the relevant prompt section:
- Parallel lookups -> **`Tool Use Efficiency`** section
- Thrash -> **`Anti-thrash rule`** in the **`Shell & Tool Conventions`** section
- Unnecessary upstream tree walks -> **`Repo File Discovery`** section
- Model re-fetching PR data instead of reading `pr-context.md` -> **`Gather PR evidence`** step
  prompt note in the **`Workflow > 1. Analyze`** section

Proposed fix: add or sharpen the guidance sentence that addresses the observed pattern.

#### C. Tier calibration

Evidence: compare actual `num_turns` and cost against each tier's stated target band from the
**`Review Depth`** section (light 5-7 turns, full 12-18, deep 20-30) and against the routing
regex in the **`Select model tier`** step.

Flag:
- **Over-tiered**: a simple patch bump (`fix(container):` title, single image) routed to `full`
  or `deep` when it used only 4-6 turns and cost <$0.05. Propose tightening the haiku/light
  routing regex in the `Select model tier` step.
- **Under-tiered**: a grouped PR or high-blast-radius component that hit `error_max_turns` at
  25 turns. Propose adding its keyword to the `deep` regex or bumping the `full` budget in the
  `Select model tier` step.

#### D. Reliability and noise

Evidence: `error_during_execution` runs; duplicate or stacked reviews on the same PR (the
**`Pre-check: skip redundant re-reviews`** section and the **dismiss-stale-reviews block** in the
**`Submitting the Review`** section are both dedup safeguards -- duplicate reviews indicate one
or both mis-fired); gated runs that ended without posting any review; **`Publish review status`**
step toggling fail-closed noise.

Proposed fix is specific to the failure mode observed.

---

### 5 -- Report

Print the summary table first, then the findings list.

**Per-run summary table:**

```
Run ID          | PR title (truncated)                  | Tier   | Turns/Budget | Subtype  | Cost
----------------|---------------------------------------|--------|--------------|----------|------
26952735414     | feat(container): kei 0.20.4->0.21.3   | full/25| 4/25         | success  | $0.107
...
```

**Findings (prioritized, A->D order):**

```
[A] Permission gap -- <command> -- seen N runs (IDs: ...)
    claude step --allowedTools: add Bash(<prefix>:*)

[B] Wasted turns -- sequential X+Y lookups in separate turns -- seen N runs
    Prompt "Tool Use Efficiency" section: add "... and Y ..." to parallel example

[C] Over-tiered -- fix(container): patch bumps using 4-6 turns but routed to full/sonnet -- N runs
    "Select model tier" step: tighten light-tier regex to also match ...

[D] ...
```

Explicitly call out: "No findings for [category]" if a category has no evidence. Include a one-line
cost summary: total spend and average cost per gated run over the window.

---

### 6 -- Offer to apply

After printing the report, ask:

> "Which findings should I implement? (list letters/numbers, or 'all', or 'none')"

Wait for the response. On confirmation, edit `.github/workflows/renovate-review.yaml` with the
minimal targeted changes for each approved finding. Do not commit or push unless explicitly asked
(global safety rule). Keep all edits ASCII-only -- no emojis or em-dashes.

If any finding would substantially restructure the prompt or change the tier routing logic,
preview the proposed diff in the conversation before applying.
