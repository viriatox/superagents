#!/usr/bin/env bash
# Superagents — global installer for Claude Code + opencode.
# Run from anywhere: paths resolve relative to this script's location,
# which must sit at the root of the superagents source tree.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
OC_DIR="${OC_DIR:-$HOME/.config/opencode}"

# --- sanity: all needed files must be next to this script -------------------
for d in claude/agents claude/commands/sa claude/skills/sa-workflow \
         claude/skills/sa-templates/templates claude/skills/sa-rules/rules \
         opencode/agents opencode/commands; do
  [ -d "$SRC/$d" ] || { echo "ERROR: missing $SRC/$d — run install.sh from a complete superagents source tree." >&2; exit 1; }
done
[ -f "$SRC/opencode/opencode.jsonc" ] || { echo "ERROR: missing $SRC/opencode/opencode.jsonc" >&2; exit 1; }

echo "Superagents install"
echo "  source  : $SRC"
echo "  claude  : $CLAUDE_DIR"
echo "  opencode: $OC_DIR"
echo

# --- Claude side (the skills here are shared: opencode reads them too) ------
mkdir -p "$CLAUDE_DIR/agents" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/skills"
cp -r "$SRC/claude/agents/."   "$CLAUDE_DIR/agents/"
cp -r "$SRC/claude/commands/." "$CLAUDE_DIR/commands/"
cp -r "$SRC/claude/skills/."   "$CLAUDE_DIR/skills/"

# --- opencode side: prefer whichever agent/command layout already exists ----
# (opencode >= 1.16 reads both the singular and plural directory names;
#  we follow an existing layout to avoid split installs, default to plural.)
if   [ -d "$OC_DIR/agent" ] || [ -d "$OC_DIR/command" ];  then A_DIR="agent";  C_DIR="command"
elif [ -d "$OC_DIR/agents" ] || [ -d "$OC_DIR/commands" ]; then A_DIR="agents"; C_DIR="commands"
else A_DIR="agents"; C_DIR="commands"; fi
mkdir -p "$OC_DIR/$A_DIR" "$OC_DIR/$C_DIR"
cp -r "$SRC/opencode/agents/."   "$OC_DIR/$A_DIR/"
cp -r "$SRC/opencode/commands/." "$OC_DIR/$C_DIR/"

# --- opencode config: never clobber an existing one -------------------------
CFG=""
[ -f "$OC_DIR/opencode.jsonc" ] && CFG="$OC_DIR/opencode.jsonc"
[ -z "$CFG" ] && [ -f "$OC_DIR/opencode.json" ] && CFG="$OC_DIR/opencode.json"
if [ -z "$CFG" ]; then
  cp "$SRC/opencode/opencode.jsonc" "$OC_DIR/opencode.jsonc"
  CFG_NOTE="fresh opencode.jsonc installed — edit its REPLACE-ME placeholders"
else
  cp "$SRC/opencode/opencode.jsonc" "$OC_DIR/opencode.superagents.jsonc"
  CFG_NOTE="existing $(basename "$CFG") left untouched; superagents keys written to
             opencode.superagents.jsonc — merge model/small_model (or keep your own
             provider), mcp.jira, tools.jira*, permission.external_directory into $CFG"
fi

# --- summary -----------------------------------------------------------------
n_ca=$(ls "$CLAUDE_DIR/agents" | grep -c '^sa-')
n_cc=$(ls "$CLAUDE_DIR/commands/sa" | wc -l)
n_ru=$(ls "$CLAUDE_DIR/skills/sa-rules/rules" | wc -l)
n_tp=$(ls "$CLAUDE_DIR/skills/sa-templates/templates" | wc -l)
n_oa=$(ls "$OC_DIR/$A_DIR" | grep -c '^sa-')
n_oc=$(ls "$OC_DIR/$C_DIR" | grep -cE '^(oc|rev)-')
echo "Installed:"
echo "  claude  : $n_ca agents, $n_cc /sa: commands, 3 shared skills ($n_ru rule files, $n_tp templates)"
echo "  opencode: $n_oa agents + $n_oc commands (into $A_DIR/ and $C_DIR/)"
echo "  config  : $CFG_NOTE"
echo
echo "Next steps (see INSTALL.md for detail):"
echo "  1. Model: set model/small_model in the opencode config — any entry from"
echo "     'opencode models' works; the shipped placeholder provider is only for"
echo "     a custom OpenAI-compatible endpoint."
echo "  2. Jira MCP (optional): fill mcp.jira command/env and set enabled=true."
echo "  3. Validate: ./validate-install.sh          (static checks)"
echo "              ./validate-install.sh --live   (adds model round-trip probes)"
