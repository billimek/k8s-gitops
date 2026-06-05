# tune-renovate-review

Mine recent `renovate-review` action runs to surface prompt inefficiencies, permission gaps,
tier mis-routing, and cost outliers — then offer to apply the highest-impact fixes to the workflow.

## Usage

```
/tune-renovate-review                # analyze the last ~20 gated runs (default)
/tune-renovate-review --limit N      # widen or narrow the run window
/tune-renovate-review <runId|PR#>    # deep-dive a single run
```

---

## Steps

### 1 — Establish baseline

Read the workflow and its commit history so findings don't re-propose already-reverted ideas.

```bash
git log --oneline -20 -- .github/workflows/renovate-review.yaml
```

Then read `.github/workflows/renovate-review.yaml`. The primary tuning targets are:
- **Tier routing** (lines ~57-77): the `title` regex that assigns model/max-turns.
- **allowedTools** (line ~90): the `Bash(...)` allowlist passed to the action.
- **Prompt efficiency rules** (lines ~121-215): Tool Use Efficiency, Anti-thrash, Repo File
  Discovery, and the per-tier turn-target bands.

Anything the git log shows was previously added and then reverted must be explicitly excluded
from this session's findings.

---

### 2 — Enumerate recent gated runs

```bash
gh run list --workflow=renovate-review.yaml --limit 30 \
  --json databaseId,conclusion,status,createdAt,displayTitle,event
```

Keep only runs where `status == "completed"` and `conclusion != "cancelled"`. Work from the most
recent 20 (or `--limit N` from the invocation). Single-run mode: use the provided run ID or look
up the run ID for the given PR number:
```bash
gh run list --workflow=renovate-review.yaml --limit 50 \
  --json databaseId,displayTitle --jq '.[] | select(.displayTitle | test("PR #<N>|<PR title>"))'
```

---

### 3 — Mine each run's transcript

Fetch the log once per run and strip the `job<TAB>step<TAB>timestamp ` prefix and ANSI codes:

```bash
id=<databaseId>
log=$(gh run view "$id" --log 2>/dev/null \
  | sed -E 's/^[^\t]*\t[^\t]*\t//' \
  | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z //' \
  | sed -E 's/\x1b\[[0-9;]*m//g')
```

From the cleaned log, extract the following signals:

**Tier and result metadata** (the `result` record and echoed `claude_args`):
```bash
printf '%s\n' "$log" | rg -N \
  '"subtype"|"num_turns":|"duration_ms":|"total_cost_usd":|--max-turns|--model'
```
`subtype` values: `success`, `error_max_turns`, `error_during_execution`.

**Permission denials** (non-empty array means the model hit the tool allowlist):
```bash
printf '%s\n' "$log" | rg -A 10 '"permission_denials"'
```

**Every Bash command issued** (ordered — reveals sequential turns that could be parallel):
```bash
printf '%s\n' "$log" | rg -N '"command":'
```

**Failed tool results** (denied commands, `is_error` hits):
```bash
printf '%s\n' "$log" | rg -B 2 '"is_error": true'
```

Record per run: PR title, tier (model + max_turns), `num_turns`, `subtype`, cost, denial count,
and the ordered Bash command list.

---

### 4 — Derive findings

Analyze the full run window and group findings into the four categories below. Each finding must
cite specific run IDs, repeat-counts, and the exact line/section of the workflow to change. Order
within each category by frequency (most runs affected first).

**Do not create a finding for something the Step 1 history shows was already tried and reverted.**

#### A. Permission gaps

Evidence: non-empty `permission_denials` array, or `"is_error": true` results whose message
contains "denied", "not allowed", or "prefix rule".

Proposed fix: add the missing `Bash(<command-prefix>:*)` entry to `--allowedTools` (workflow
line ~90). If the command is already documented in the prompt's "Shell & Tool Conventions" block
(lines ~137-165) but the model still trips it, the doc wording is the bug — propose a rewrite
of that guidance instead.

#### B. Turn efficiency and waste

Evidence: `subtype == error_max_turns`; `num_turns` at or within 2 of the budget; consecutive
`"command"` entries that appear in separate turns and have no data dependency (could be issued in
parallel); repeated near-identical `Grep`/`Glob`/`gh api` calls (thrash) in the same run.

Map to the relevant prompt section:
- Parallel lookups → Tool Use Efficiency (lines ~130-135)
- Thrash → Anti-thrash rule (lines ~162-165)
- Unnecessary upstream tree walks → Repo File Discovery (lines ~167-179)

Proposed fix: add or sharpen the guidance sentence that addresses the observed pattern.

#### C. Tier calibration

Evidence: compare actual `num_turns` and cost against each tier's stated target band —
light 5-7 turns, full 12-18, deep 20-30 (workflow lines ~193-215) — and against the routing
regex in the tier-selection step (lines ~65-69).

Flag:
- **Over-tiered**: a simple patch bump (`fix(container):` title, single image) routed to `full`
  or `deep` when it used only 4-6 turns and cost <$0.05. Propose tightening the haiku/light
  routing regex.
- **Under-tiered**: a grouped PR or high-blast-radius component that hit `error_max_turns` at
  25 turns. Propose adding its keyword to the `deep` regex or bumping the `full` budget.

#### D. Reliability and noise

Evidence: `error_during_execution` runs; duplicate reviews on the same PR (the pre-check at
lines ~121-128 should prevent these); gated runs that ended without posting any review; status
publish step toggling fail-closed noise (lines ~360-391).

Proposed fix is specific to the failure mode observed.

---

### 5 — Report

Print the summary table first, then the findings list.

**Per-run summary table:**

```
Run ID       | PR title (truncated)               | Tier     | Turns/Budget | Subtype         | Cost    | Denials
-------------|------------------------------------|-----------|-----------  |-----------------|---------|--------
26952735414  | feat(container): kei 0.20.4→0.21.3 | full/25  | 4/25         | success         | $0.107  | 0
...
```

**Findings (prioritized, A→D order):**

```
[A] Permission gap — <command> — seen N runs (IDs: ...)
    Workflow line ~90 (allowedTools): add Bash(<prefix>:*)

[B] Wasted turns — sequential X+Y lookups in separate turns — seen N runs
    Workflow lines ~130-135 (Tool Use Efficiency): add "... and Y ..." to parallel example

[C] Over-tiered — fix(container): patch bumps using 4-6 turns but routed to full/sonnet — N runs
    Workflow lines ~65-69: tighten light-tier regex to also match ...

[D] ...
```

Explicitly call out: "No findings for [category]" if a category has no evidence. Include a one-line
cost summary: total spend and average cost per gated run over the window.

---

### 6 — Offer to apply

After printing the report, ask:

> "Which findings should I implement? (list letters/numbers, or 'all', or 'none')"

Wait for the response. On confirmation, edit `.github/workflows/renovate-review.yaml` with the
minimal targeted changes for each approved finding. Do not commit or push unless explicitly asked
(global safety rule). Keep all edits ASCII-only — no emojis or em-dashes.

If any finding would substantially restructure the prompt or change the tier routing logic,
preview the proposed diff in the conversation before applying.
