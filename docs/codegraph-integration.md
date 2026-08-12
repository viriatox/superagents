# CodeGraph integration — required changes and gains analysis

Input document for a fix pass. Constraint: **CodeGraph is the only allowed structure-aware
exploration tool for now** (Serena, code-index-mcp, Sourcegraph etc. are out of scope — see
`token-optimizations.md` OPT-8 for the landscape analysis).

## 0. The tool

**colbymchenry/codegraph** (https://github.com/colbymchenry/codegraph) — verified Aug 2026:
66k★ / 4.2k forks, MIT, created Jan 2026, very active. Not to be confused with the older
namesakes (CodeGraphContext, codegraph.codes, FalkorDB code-graph) — this one supersedes them
for our purposes.

Facts that matter for this integration:
- **Index**: native Rust kernel + compiled tree-sitter grammars, 30+ languages; **Java, TypeScript,
  and 17 web frameworks incl. Spring** are first-tier (matches the target stacks). Local SQLite
  (`.codegraph/codegraph.db`), FTS5; 100% local, no data leaves the machine (a telemetry system
  exists — review/disable it before use on private code).
- **Query**: MCP server exposing one primary tool, `codegraph_explore` (returns relevant symbols'
  verbatim source, call paths incl. dynamic dispatch, blast-radius summaries), plus a full **CLI**
  (`codegraph query|explore|node|callers|callees|impact|affected|init|sync|status|daemon`).
- **Staleness**: file watcher with debounced auto-sync (~2 s), per-file staleness banners in
  responses, connect-time reconciliation. Skips `node_modules`/`dist`/`vendor`, respects
  `.gitignore`, skips files >1 MB.
- **Install**: `npm i -g @colbymchenry/codegraph`, standalone bundles, or one-line installer;
  `codegraph install` auto-configures agents. Verified builds (npm provenance, SLSA L2).

## 1. Where CodeGraph plugs into the workflow (and where it must NOT)

Source-code contact in superagents is deliberately concentrated:

| Agent | Touches source? | CodeGraph? |
|---|---|---|
| Orchestrator (main thread) | never | **no** — unchanged |
| CL:sa-refiner / sa-planner / sa-validator | never (artifacts only) | **no** — unchanged |
| OC:explore (`@explore`) | yes — the localization workhorse | **yes — primary consumer** |
| OC:sa-coder / sa-tester / sa-autotester | yes, on planned paths | **optional** — FIX-mode reference lookups |
| OC:sa-verifier | runs builds only | no |

The core contract is untouched: Claude-side agents still read only `.superagents/` artifacts;
all graph querying happens inside opencode delegations. CodeGraph changes HOW exploration
answers are found, not WHO reads source. The explore output contract (path:line answer, ≤80
lines, redirected to `context/exploration-<n>.md`, never through orchestrator context) is
unchanged — the graph's dense payloads land in the cheap explorer's context and are distilled
before anything expensive sees them.

## 2. Required changes

### 2.1 Machine config (deployed copies ONLY — never the repo source)

Two integration routes; **start with the MCP route**, keep the CLI as fallback:

- **MCP route (primary)**: register the codegraph MCP server in
  `~/.config/opencode/opencode.jsonc`; grant `codegraph_explore` to the `explore` agent
  (and optionally the coders). **Permissions**: mark the tool `allow` — anything left `ask`
  is AUTO-REJECTED in headless runs (known gotcha) and silently degrades exploration back
  to grep. The single-tool design (`codegraph_explore`) is an adoption advantage: cheap
  models pick one obvious tool far more reliably than a large tool menu.
- **CLI route (fallback / non-MCP contexts)**: allowlist the `codegraph` binary in the
  opencode bash permissions; the explore prompt may then call `codegraph explore/callers/...`
  directly. Same headless-allow requirement, one binary instead of an MCP entry.
- Machine prerequisites: `npm i -g @colbymchenry/codegraph`; run `codegraph init` per target
  repo (or let `codegraph install` configure it); decide daemon vs on-demand `sync`.
  **Review/disable telemetry** in its config before first use on private code.

### 2.2 Repo source — `claude/skills/sa-workflow/SKILL.md`

1. **Explore snippet (HYBRID section)** — add one guidance line to the `@explore` prompt
   template: *"Prefer `codegraph_explore` (symbols, call paths, impact) for locating code;
   fall back to grep/read for content, convention, and config questions. Answer format
   unchanged (path:line, max 80 lines)."*
   Rationale for the fallback: graph retrieval wins on localization and cost but published
   comparisons show a small quality dip where full-file context matters; and CodeGraph skips
   >1 MB files and non-code config — grep still owns those.
2. **Index lifecycle** (short subsection; applies to REFINE step 3, PLAN explorations,
   AUTOTEST step 3):
   - REFINE step 1 gains: "ensure the CodeGraph index exists (`codegraph status`; `init`/
     `sync` if needed) — one simple command; do not block exploration on it."
   - **Post-DEVELOP explorations** (TEST clarifications, AUTOTEST step 3): with the watcher/
     daemon running, auto-sync makes this a no-op; without it, run `codegraph sync` first.
     CodeGraph's per-file staleness banners are a safety net, not a substitute — a stale
     graph answering AUTOTEST exploration with pre-develop symbols would poison the autotest
     plan.
   - Index unavailable/broken → exploration proceeds grep-only (CodeGraph is an accelerator,
     never a dependency; no BLOCKED on index problems).
3. **Delegation table**: no new rows — CodeGraph is a tool inside existing delegations, not a
   new delegate.

### 2.3 Repo source — opencode agents (all variants)

- `opencode/agents/sa-coder.md` (and sa-tester/sa-autotester if granted): one line permitting
  CodeGraph lookups **in FIX mode only** — when a validation report cites a wrong path or a
  missed reference, resolve the symbol via `callers`/`impact` instead of directory-walking.
  Normal mode stays plan-driven (exact paths from the plan); a coder self-exploring in normal
  mode is scope creep. CodeGraph's `impact`/blast-radius output is also a natural input for
  FIX-mode "what else references this" checks.
- `opencode/commands/oc-*.md` / `rev-*.md`: no structural change — they inherit the SKILL.md
  explore guidance. Verify no wording hardcodes "grep".

### 2.4 Repo source — docs & installer

- `INSTALL.md`: optional "CodeGraph" section — npm install, `codegraph init`, MCP
  registration example (marked machine-specific), headless permission note, telemetry note.
- `validate-install.sh`: optional check — if codegraph is registered in the deployed config,
  verify the binary exists and `codegraph status` answers; warn (not fail) otherwise.

### 2.5 Explicit non-changes (guard against scope creep in the fix pass)

- No CodeGraph tools for Claude-side subagents or the orchestrator (they are forbidden source
  access by contract).
- No change to artifact formats, contract lines, validation gates, or delegation tables.

## 3. Gains analysis

### Direct gains (opencode side — real but small in money terms)

Vendor benchmarks across 7 real repos (VS Code, Django, Tokio, OkHttp, …): **88% fewer tool
calls, 62% fewer tokens, 53% faster, 44% cheaper, zero file reads** vs a file-reading
baseline — vendor-run, so discount accordingly, but directionally consistent with independent
research on graph retrieval (Codebase-Memory 2026: ~10× fewer retrieval tokens; LocAgent
ACL'25: ~86% cheaper localization). The backend model (deepseek-v4-flash) is cheap, so the
euro savings here are minor; the latency gain is not — shorter explore delegations mean less
prompt-cache decay on the Claude side while waiting (couples with OPT-2/OPT-7).

One vendor-documented trade-off: `codegraph_explore` returns a single dense payload that
stays resident in the caller's window (~67k vs 18k tokens median in their tests). In this
architecture that cost lands ONLY in the throwaway explorer session and is distilled to a
≤80-line artifact — the trade-off is structurally muted here. Do not grant the graph tools to
long-lived contexts (reinforces §2.5).

### Indirect gains (Claude side — the actual business case)

Exploration accuracy gates the expensive path: the planner must name exact file paths or
BLOCK, and a wrong path becomes a DEVELOP fix loop. Research baselines for graph-guided
localization (LocAgent: 92.7% file-level accuracy; RepoGraph: +32.8% relative SWE-bench)
plus CodeGraph's resolved cross-file dependency coverage (73.8–100% of symbol-bearing files
in its benchmarks) suggest a real accuracy lift for a cheap explorer. Each avoided fix loop
saves: a coder re-delegation + diff recapture + verifier run + a FRESH validator context
(`-r<n>`) — the most expensive repeated unit in the workflow. Each avoided planner BLOCKED
saves a full round trip plus an extra exploration.

### Costs & risks

- **Young project** (created Jan 2026) despite massive adoption (66k★) — pin a version;
  re-validate on upgrades.
- **Telemetry** exists — must be reviewed/disabled for private code (code itself stays local).
- Vendor benchmarks are vendor-run; the campaign arm below is the real gate.
- Framework-routing depth on the exact stacks (Spring, Angular) needs a spot-check during the
  campaign arm — first-tier support is claimed, not yet verified by us.
- >1 MB files and gitignored/generated files are invisible to the graph — grep fallback
  covers this; keep it in the prompt.
- One more headless permission surface (MCP tool or binary allowlist) per machine.

### Measurement gate (adopt only on evidence)

A/B sa-test campaign arm — same task, explore with vs without CodeGraph. Metrics:
1. Exploration artifact accuracy (spot-check paths/symbols exist and are the right ones).
2. Planner BLOCKED count.
3. DEVELOP fix-loop count (number of `validation-*-r*.md` files).
4. Explorer tokens + delegation wall time (secondary).
Adopt if 1–3 improve; 4 alone does not justify the added moving part.

## 4. Suggested rollout order

1. Install + `codegraph init` on this machine; disable telemetry; index a sandbox repo;
   smoke-test `codegraph_explore` output quality on a known question.
2. Deployed opencode.jsonc: MCP registration + `allow` for the explore agent.
3. SKILL.md explore-guidance + index-lifecycle edits (repo source).
4. A/B campaign arm (measurement gate above).
5. If adopted: sa-coder FIX-mode line, INSTALL.md/validate-install.sh, version pin note.
