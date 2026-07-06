#!/usr/bin/env bash
# Superagents — post-install validation.
# Static checks by default; add --live for model round-trip probes.
# Exit 0 = ready for orchestrations. Every FAIL prints the exact problem.
set -uo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
OC_DIR="${OC_DIR:-$HOME/.config/opencode}"
LIVE=0; [ "${1:-}" = "--live" ] && LIVE=1

PASS=0; FAIL=0; WARN=0
ok()   { PASS=$((PASS+1)); printf '  \033[32mOK\033[0m   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
warn() { WARN=$((WARN+1)); printf '  \033[33mWARN\033[0m %s\n' "$1"; }

section() { printf '\n== %s ==\n' "$1"; }

# ---------------------------------------------------------------- 1. binaries
section "Binaries"
if command -v claude >/dev/null 2>&1; then ok "claude CLI ($(claude --version 2>/dev/null | head -1))"
else bad "claude CLI not on PATH (needed for HYBRID and REV)"; fi
if command -v opencode >/dev/null 2>&1; then
  OCV="$(opencode --version 2>/dev/null | head -1)"
  ok "opencode CLI ($OCV)"
  case "$OCV" in
    0.*|1.0.*|1.1[0-5].*) warn "opencode < 1.16 — subagent permissions had a regression; upgrade recommended";;
  esac
else bad "opencode CLI not on PATH (needed by all variants)"; fi
command -v git >/dev/null 2>&1 && ok "git" || bad "git not on PATH"

# ------------------------------------------------------------ 2. Claude side
section "Claude side ($CLAUDE_DIR)"
for f in sa-refiner sa-planner sa-validator; do
  [ -f "$CLAUDE_DIR/agents/$f.md" ] && ok "agents/$f.md" || bad "missing $CLAUDE_DIR/agents/$f.md"
done
for f in refine plan develop test autotest approve status; do
  [ -f "$CLAUDE_DIR/commands/sa/$f.md" ] && ok "commands/sa/$f.md" || bad "missing $CLAUDE_DIR/commands/sa/$f.md"
done
for s in sa-workflow sa-templates sa-rules; do
  [ -f "$CLAUDE_DIR/skills/$s/SKILL.md" ] && ok "skills/$s/SKILL.md" || bad "missing $CLAUDE_DIR/skills/$s/SKILL.md"
done
NT=$(ls "$CLAUDE_DIR/skills/sa-templates/templates" 2>/dev/null | wc -l)
[ "$NT" -ge 10 ] && ok "templates present ($NT)" || bad "templates missing/short ($NT found in skills/sa-templates/templates)"
[ -f "$CLAUDE_DIR/skills/sa-rules/rules/rules-manifest.md" ] && ok "rules/rules-manifest.md" || bad "missing rules-manifest.md"
NR=$(ls "$CLAUDE_DIR/skills/sa-rules/rules" 2>/dev/null | wc -l)
[ "$NR" -ge 2 ] && ok "rule files present ($NR)" || bad "rule files missing ($NR)"

# ---------------------------------------------------------- 3. opencode side
section "opencode side ($OC_DIR)"
A_DIR=""; C_DIR=""
[ -d "$OC_DIR/agent" ]   && A_DIR="agent"
[ -d "$OC_DIR/agents" ]  && { [ -n "$A_DIR" ] && [ -n "$(ls "$OC_DIR/agents" 2>/dev/null | grep '^sa-')" ] && [ -n "$(ls "$OC_DIR/agent" 2>/dev/null | grep '^sa-')" ] && warn "sa-* agents exist in BOTH agent/ and agents/ — split install, keep one"; [ -z "$A_DIR" ] && A_DIR="agents"; }
[ -d "$OC_DIR/command" ]  && C_DIR="command"
[ -d "$OC_DIR/commands" ] && { [ -z "$C_DIR" ] && C_DIR="commands"; }
if [ -z "$A_DIR" ]; then bad "no agent/ or agents/ directory in $OC_DIR"; else
  ok "agent layout: $A_DIR/"
  for f in sa-orchestrator sa-refiner sa-planner sa-validator sa-coder sa-tester sa-autotester sa-verifier sa-jira; do
    [ -f "$OC_DIR/$A_DIR/$f.md" ] && ok "$A_DIR/$f.md" || bad "missing $OC_DIR/$A_DIR/$f.md"
  done
fi
if [ -z "$C_DIR" ]; then bad "no command/ or commands/ directory in $OC_DIR"; else
  ok "command layout: $C_DIR/"
  for f in oc-refine oc-plan oc-develop oc-test oc-autotest oc-approve oc-status \
           rev-refine rev-plan rev-develop rev-test rev-autotest; do
    [ -f "$OC_DIR/$C_DIR/$f.md" ] && ok "$C_DIR/$f.md" || bad "missing $OC_DIR/$C_DIR/$f.md"
  done
fi

# ----------------------------------------------------------------- 4. config
section "opencode config"
CFG=""
[ -f "$OC_DIR/opencode.jsonc" ] && CFG="$OC_DIR/opencode.jsonc"
[ -z "$CFG" ] && [ -f "$OC_DIR/opencode.json" ] && CFG="$OC_DIR/opencode.json"
if [ -z "$CFG" ]; then bad "no opencode.json[c] in $OC_DIR"; else
  ok "config: $CFG"
  MODEL_VAL=$(grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$CFG" | head -1 | sed 's/.*:.*"\(.*\)"/\1/')
  if [ -z "$MODEL_VAL" ]; then
    warn "no \"model\" key in $CFG — agents will use opencode's default"
  elif printf '%s' "$MODEL_VAL" | grep -q 'REPLACE-ME'; then
    bad "\"model\" is still a REPLACE-ME placeholder — set it (INSTALL.md §Model configuration)"
  else
    ok "model set: $MODEL_VAL"
    case "$MODEL_VAL" in internal/*)
      grep -A6 '"provider"' "$CFG" | grep -q 'REPLACE-ME' && bad "model uses the internal provider but its baseURL/apiKey are REPLACE-ME placeholders";;
    esac
  fi
  if grep -q '"jira"' "$CFG" 2>/dev/null; then
    if grep -q 'REPLACE-ME.*jira\|jira.*REPLACE-ME\|JIRA_TOKEN.*REPLACE-ME\|REPLACE-ME-jira' "$CFG"; then
      warn "Jira MCP block still has REPLACE-ME placeholders (fine if you don't use Jira — tasks start from plain prompts)"
    else
      grep -q '"enabled"[[:space:]]*:[[:space:]]*true' "$CFG" && ok "Jira MCP configured (enabled)" || warn "Jira MCP present but disabled (fine — tasks start from plain prompts)"
    fi
  else warn "no Jira MCP configured (optional)"; fi
fi
[ -f "$OC_DIR/opencode.superagents.jsonc" ] && warn "unmerged opencode.superagents.jsonc present — merge its keys into your config, then delete it"

# ---------------------------------------------- 5. content freshness markers
section "Deployed content freshness"
m() { # m <file> <pattern> <label>
  if [ -f "$1" ] && grep -q "$2" "$1"; then ok "$3"; else bad "$3 — marker missing in $1 (stale deploy? rerun ./install.sh)"; fi
}
m "$CLAUDE_DIR/skills/sa-workflow/SKILL.md" "One simple shell command per call" "workflow: single-command core principle"
m "$CLAUDE_DIR/skills/sa-workflow/SKILL.md" "RUNS" "workflow: TEST wave verdict lines"
m "$CLAUDE_DIR/skills/sa-workflow/SKILL.md" "matched trigger is BINDING" "workflow: binding-trigger rule"
m "$CLAUDE_DIR/skills/sa-workflow/SKILL.md" "NEVER excuses a failing existing suite" "workflow: RED-suite guard"
m "$CLAUDE_DIR/skills/sa-workflow/SKILL.md" "ORCHESTRATOR owns the lifecycle" "workflow: hybrid N-service autotest lifecycle"
m "$CLAUDE_DIR/skills/sa-rules/rules/automation-test-rules.md" "Environment lifecycle" "automation rules: environment lifecycle (rule 14)"
m "$CLAUDE_DIR/agents/sa-validator.md" "VERDICT" "claude validator: verdict contract"
[ -n "$A_DIR" ] && m "$OC_DIR/$A_DIR/sa-validator.md" "NEVER excuses a failing existing suite" "opencode validator: RED-suite guard"
[ -n "$C_DIR" ] && m "$OC_DIR/$C_DIR/oc-refine.md" "Agent guard" "commands: mis-dispatch agent guard"

# ------------------------------------------------------------- 6. live probes
if [ "$LIVE" = "1" ]; then
  section "Live probes (model calls — may take a minute each)"
  OUT=$(timeout 120 opencode run --agent sa-verifier "Diagnostic ping — no command to run. Reply per your contract (a BLOCKED line is the correct answer)." < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
  if printf '%s' "$OUT" | grep -qiE 'BLOCKED|PING|RESULT|DONE'; then ok "opencode agent round-trip (model answers, sa agent selected)"
  elif [ -n "$(printf '%s' "$OUT" | tr -d '[:space:]')" ]; then warn "opencode agent replied off-contract — model works, check agent files: $(printf '%s' "$OUT" | tail -1 | cut -c1-80)"
  else bad "opencode agent probe timed out with no output — check model config and backend health"; fi
  OUT=$(timeout 120 opencode run "Use the skill tool to load sa-workflow and reply only with its name." < /dev/null 2>&1)
  if printf '%s' "$OUT" | grep -qi "sa-workflow"; then ok "opencode sees the shared skills (~/.claude/skills)"
  else bad "opencode could not load skill sa-workflow — check permission.external_directory allows ~/.claude/skills/**"; fi
  OUT=$(timeout 120 claude -p "reply with exactly: OK" 2>&1)
  if printf '%s' "$OUT" | grep -q "OK"; then ok "claude -p round-trip (REV / HYBRID Claude path)"
  else bad "claude -p failed — authenticate the claude CLI (or usage limit active)"; fi
else
  section "Live probes"
  echo "  skipped — run './validate-install.sh --live' to probe the model paths"
fi

# ------------------------------------------------------------------- summary
printf '\n== Summary: %d ok, %d warnings, %d failures ==\n' "$PASS" "$WARN" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "Installation is ready for orchestrations."
  exit 0
else
  echo "Fix the failures above (usually: rerun ./install.sh, or edit the opencode config)."
  exit 1
fi
