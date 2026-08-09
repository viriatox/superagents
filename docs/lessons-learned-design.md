# Design: Lessons-Learned (shared automemory) for superagents

Status: DESIGN — not implemented. This document is the review input for adapting an
existing superagents installation (workflows/agents/skills/rules identical to this repo)
to learn from its own mistakes over time, across all three variants (hybrid `/sa:*`,
full-opencode `oc-*`, reverse `rev-*`), without adding context clutter.

---

## 1. Goal and non-goals

**Goal.** When a task's validation cycles, retries, or blocked delegations reveal a
*preventable* failure class, distill it into a short, reusable instruction that future
delegations automatically receive — but only the delegations it applies to, and only a
few lines of it.

**Non-goals (explicitly out of scope):**
- No vector/embedding retrieval. Keyword/tag matching against a manifest is
  deterministic, debuggable, and sufficient at this scale (dozens of lessons, not
  thousands). Full rationale in §12.
- No mid-task journaling. Agents never write memory while doing work; volume without
  signal, and garbage compounds.
- No lessons pasted into `AGENTS.md` / `CLAUDE.md` / delegation prompts. Always-loaded
  context gets at most an index line; content is loaded by the delegate on tag match,
  by file path (consistent with core principle "pass context by file path, never by content").
- Subagents never write lessons. Single writer: the retro step (see §5).

## 2. Core concept: lessons are dynamically authored rules

The system already has exactly the selective-recall mechanism a memory needs: the
`sa-rules` skill. Agents read `rules/rules-manifest.md`, collect tags for the work at
hand, and load ONLY the matching rule files. Lessons reuse this mechanism instead of
inventing a parallel one:

> **A lesson is a small rule file that was written by the workflow itself, carries
> provenance, and lives in a separate "learned" store with its own manifest.**

Every agent that already performs rule selection (planner, refiner, coder, tester,
validator, autotester — all variants) gets lesson recall for free by extending the
`sa-rules` procedure with one step: *also consult the lessons manifest*.

## 3. Storage layout — two tiers

### 3.1 Global tier (cross-project, survives redeployment)

Lessons about the tooling, harnesses, and models: opencode headless quirks, permission
allowlist behavior, model-specific tendencies, contract-line failure patterns. These
transfer across every project.

```
~/.config/superagents/lessons/
├── lessons-manifest.md
└── <slug>.md                    # one lesson per file
```

**Critical constraint:** the deployed skill directories
(`~/.claude/skills/sa-rules/…` and the opencode equivalents) are overwritten from the
canonical source repo on every redeploy. Learned state must therefore live OUTSIDE any
deployed directory. `~/.config/superagents/` is machine-local runtime state, never
touched by deployment. Do NOT store lessons under `sa-rules/rules/`.

### 3.2 Per-project tier (codebase-specific)

Lessons that must not leak between projects: "this repo's tests need the DB container
up first", "module X's public API is generated — never edit it directly".

```
<target-repo>/.superagents/.lessons/
├── lessons-manifest.md
└── <slug>.md
```

**Naming caveat:** task resolution scans `.superagents/` for task directories. The
lessons directory must be excluded — hence the leading dot (`.lessons/`), plus an
explicit exclusion in the task-resolution rule of `sa-workflow` ("directories starting
with `.` are never task-ids"). Reviewers of the older version: verify its task
resolution wording and add this exclusion.

## 4. Lesson file format

One lesson per file, hard cap **≤ 15 lines total** (frontmatter included). Template to
be added to `sa-templates` (see §9).

```markdown
---
name: oc-compound-shell-kills-phase
tags: [develop, test, opencode, shell]        # phase / role / tech / variant tags
scope: global                                  # global | project
status: candidate                              # candidate | active | retired | promoted
hits: 1                                        # times this failure class was seen
added: 2026-08-07
provenance: PROJ-123 .superagents/PROJ-123/develop/validation-api.md
---
**When:** running shell commands in a headless opencode delegation.
**Do:** issue one simple command per call; never chain with `&&`/`;`/pipes —
the resulting `ask` permission is auto-rejected and kills the phase.
```

Format rules:
- Body is exactly two labelled lines — **When:** (trigger condition) and **Do:**
  (imperative instruction). No narrative, no examples, no rationale beyond one clause.
- `tags` use the same vocabulary as the rules manifest (technology, layer, activity)
  **plus** phase names (`refine`, `plan`, `develop`, `test`, `autotest`) and agent
  roles (`planner`, `coder`, `validator`, …) so lessons can be scoped tighter than rules.
- `provenance` is mandatory: task-id + the artifact (usually a validation report) that
  evidences the failure. A lesson without provenance is invalid and must be rejected.

## 5. Write path: the RETRO step

### 5.1 When it runs

At the tail of task completion — concretely: when the final phase of a task reaches
`approved` (TEST, or AUTOTEST when enabled), the orchestrator runs retro before its
closing summary. Additionally a standalone command (`/sa:retro <task-id>`,
`/oc-retro`, `/rev-retro`) allows running it on demand for past tasks.

Rationale for tail-of-approval rather than a separate gated phase: retro needs no user
input to *propose*, only to *promote* (§6), and a separate phase row in `state.md`
would add ceremony to every task for a step that often yields nothing.

### 5.2 What it reads (mistake signals — all already exist as artifacts)

- Validation reports ending `VERDICT: FAIL` and the subsequent FIX-cycle reports —
  the strongest signal.
- `state.md` `## Log` entries: `failed` states, phase re-runs, retries.
- Delegation replies recorded as `BLOCKED — …`.
- Verify reports (`verify-*.md`) that contradict dev/test reports.

### 5.3 Who writes

The orchestrator delegates to a new read-mostly agent **`sa-retro`** (opus-tier; both
a Claude agent file and an opencode agent file, mirroring `sa-validator`). It follows
the standard output contract (`DONE <path> (<n> lines) — …` / `BLOCKED — …`).
It writes ONLY:
1. new lesson files with `status: candidate`, and
2. the manifest rows for them (pending section), and
3. a short retro report `.superagents/<task-id>/retro.md` listing what it proposed,
   what it matched to existing lessons (hit increments), and what it deliberately
   discarded as one-off.

### 5.4 Distillation criteria (the quality bar)

A failure becomes a lesson candidate ONLY if all hold:
1. **Preventable by instruction** — a ≤ 2-line instruction, had it been in context,
   would plausibly have prevented it. (A typo is not a lesson; a systematic omission is.)
2. **Recurrence-shaped** — the cause is a property of the tooling, model behavior, the
   project, or the workflow — not of this task's specific requirements.
3. **Not already covered** — no permanent rule and no existing lesson covers it. If an
   existing lesson matches: increment its `hits` instead of writing a duplicate. If an
   existing lesson matched *and was loaded* by the failing delegation yet the failure
   still occurred, mark the lesson `ineffective: true` — it goes to review (§7).
4. **Not contradicting permanent rules** — permanent rules always win; a "lesson" that
   contradicts one is either wrong or a rule-change proposal for the human, never a lesson.

Expected outcome for most tasks: **zero candidates.** The retro report saying
"nothing learned" is a success case, not a failure.

## 6. Approval gate (poisoning defense)

A wrong lesson silently degrades every future task, so candidates never self-activate:

- `candidate` lessons are **not loaded** by the recall path. Only `active` ones are.
- Promotion `candidate → active` goes through the existing approval flow: the retro
  summary (or `/sa:approve` / `/oc-approve` when a retro is awaiting approval) shows
  each candidate's When/Do lines + provenance and asks approve / reject / edit.
- In autonomous campaign mode: batch all candidates, present at end of the campaign,
  never block mid-run.

## 7. Lifecycle and budgets (clutter defense over time)

- **Hard caps:** max **10 active lessons per (phase × scope)** and max **40 lines of
  lesson content** loadable by any single delegation. When a cap would be exceeded,
  the retro must merge candidates into a generalized lesson or propose an eviction —
  it may not simply append. Caps are stated in the lessons manifest header so every
  reader can verify them.
- **Promotion:** `hits ≥ 3` → retro proposes migrating the lesson into the appropriate
  permanent rule file (human applies it in the canonical source repo; lesson file gets
  `status: promoted` and stops being loaded). Lessons are a staging area for rules,
  not a second permanent rulebook.
- **Retirement:** `ineffective: true`, or unmatched for ~20 tasks (manifest records
  `added` date; retro checks staleness) → propose `status: retired`. Retired/promoted
  files are kept (audit trail via provenance) but never loaded.
- **Audit:** the status command (`sa:status` / `oc-status`) gains a `lessons` argument
  that lists both manifests with status/hits — read-only.

## 8. Recall path (the only context-facing change)

Extend the `sa-rules` SKILL procedure with one step (after loading matched rule files):

> N. Read the lessons manifests (global: `~/.config/superagents/lessons/lessons-manifest.md`;
> project: `.superagents/.lessons/lessons-manifest.md` — either may be absent; absence
> is normal, not an error). From their index tables, load every `active` lesson whose
> tag set intersects your work tags (same matching rule as for rules, with phase and
> role tags added). Respect the 40-line budget: if matches exceed it, load by
> descending `hits` and note the truncation in your artifact. List loaded lessons in
> the artifact's "rules consulted" section like any rule file.

Clutter properties this preserves:
- Zero always-loaded cost: nothing is added to `AGENTS.md`/`CLAUDE.md`/system prompts;
  the manifest is read only by agents already reading the rules manifest.
- Tag-scoped: a planner never sees coder lessons; an Angular task never sees Java lessons.
- Bounded: 15-line files, 40-line budget, 10-per-phase cap — worst case is comparable
  to one small rule file.
- Auditable: "rules consulted" already propagates to validators, so validators
  automatically re-load the same lessons when validating.

## 9. Change checklist (what an implementation review must touch)

| # | file (canonical source repo) | change |
|---|---|---|
| 1 | `claude/skills/sa-rules/SKILL.md` | add the lessons-consultation step (§8) |
| 2 | `claude/skills/sa-workflow/SKILL.md` | retro trigger at final-phase approval; `.lessons` exclusion in task resolution; approval-flow extension for candidates; delegation-table rows for `sa-retro` per variant |
| 3 | `claude/skills/sa-templates/templates/` | new `lesson.md` and `retro-report.md` templates + rows in the SKILL table |
| 4 | `claude/agents/sa-retro.md` | new agent (opus, read-only except lesson files, manifest, retro report; standard output contract) |
| 5 | `opencode/agents/sa-retro.md` | opencode twin of the above |
| 6 | `claude/commands/sa/retro.md` | standalone retro command (hybrid) |
| 7 | `opencode/commands/oc-retro.md`, `opencode/commands/rev-retro.md` | standalone retro commands (full-oc, rev) |
| 8 | `claude/commands/sa/status.md` + `opencode/commands/oc-status.md` | optional `lessons` listing argument |
| 9 | deploy script / install docs | create `~/.config/superagents/lessons/` with an empty manifest on install; NEVER overwrite it on redeploy |

Nothing in `rules/rules-manifest.md` or existing rule files changes — the learned
store is additive and separate, so redeploys of the canonical skills remain safe.

## 10. Variant notes

- All three variants read the same two lesson locations; plain markdown, no
  harness-specific format. The opencode side reads them the same way it already reads
  the globally installed rules.
- Writes happen only in the retro delegation, at end of task — single writer, no
  concurrent-write handling needed. If two tasks in different repos finish
  simultaneously against the global manifest (rare, human-driven), last-write-wins on
  the manifest is acceptable; lesson *files* are per-slug so they never collide.
- Headless/campaign runs: retro proposes only (candidates are inert), so a fully
  autonomous run can complete without approval; promotion happens at the next
  interactive session or end-of-campaign review.

## 11. Open questions for the review

1. Should retro run at TEST approval even when AUTOTEST follows, or strictly once at
   the true final phase? (Leaning: final phase only — one retro per task.)
2. Is the `hits` counter worth having from day one, or add it once dedup pressure is
   real? (Leaning: keep it — it costs one frontmatter line and drives both promotion
   and eviction.)
3. Per-(phase × scope) cap of 10 and the 40-line budget are guesses — validate against
   the token budget philosophy of the existing rules ("never load the whole directory").
4. Should `sa-validator` be extended to flag artifacts that violate an *active lesson*
   the producer had loaded (making lessons enforceable, not just advisory)? (Leaning:
   yes, but as `minor` severity initially, upgraded to `blocking` only for promoted rules.)
5. Global-tier path: `~/.config/superagents/lessons/` assumed; confirm both harnesses
   on all target machines can read `~/.config` in headless mode.

## 12. Appendix — why tag matching instead of a vector database

Vector retrieval earns its keep when queries are fuzzy natural language, the corpus is
large and heterogeneous, and there is no shared vocabulary between query and content.
This feature has none of those properties, and several that actively argue against it:

1. **The query side is already structured.** A delegation never asks an open-ended
   question — it knows, deterministically from the artifacts, its phase, role,
   technology, and variant. Those are categorical keys, and lesson authors assign tags
   from the same controlled vocabulary (the rules-manifest tag set plus phase/role
   names). When both sides of the match use one vocabulary, tag intersection IS exact
   retrieval; embeddings can only approximate it, worse.
2. **Scale never gets there by design.** The caps in §7 (10 active per phase,
   promotion at 3 hits, staleness retirement) keep the store at dozens of entries
   precisely so a manifest table suffices. Wanting vector search over hundreds of
   lessons would signal a curation failure, not a retrieval problem — and better
   recall over a bloated store makes things worse, because whatever is retrieved still
   gets injected. The scarce resource is context tokens, not recall.
3. **Error asymmetry favors precision.** A false negative (missed lesson) costs the
   status quo. A false positive (semantically-adjacent-but-wrong lesson injected) is
   exactly the context pollution and poisoning §6 defends against. Similarity scoring
   produces confident near-misses; tag intersection fails closed.
4. **Debuggability in headless runs.** Campaigns run autonomously across two
   harnesses. "Which lessons did this delegation load and why" must be answerable
   after the fact: with the manifest it is a table lookup plus the artifact's "rules
   consulted" line, and the validator re-derives the identical set. With embeddings
   the answer is "these scored above a threshold" — unfalsifiable, unstable across
   embedding-model versions, and not reviewable by reading a file.
5. **Operational cost across two harnesses.** Everything in superagents works via
   "read a markdown file", which both Claude Code and headless opencode do with zero
   dependencies, offline, on any deployed machine. A vector store adds an embedding
   model, an index to maintain and re-embed on edits, a service or native library both
   harnesses must reach, and one more silently breakable component mid-campaign.

**When embeddings WOULD be right:** a future, different feature — case-based retrieval
over past task transcripts and reports ("find situations similar to this one"). That
is free-text search over thousands of heterogeneous documents with no shared
vocabulary. This design deliberately keeps the small curated self-growing rulebook
from morphing into that.
