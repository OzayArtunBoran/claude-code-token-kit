#!/usr/bin/env bash
# Graphify + Claude Code token-strategy setup.
# Usage: ./install.sh /path/repo1 [/path/repo2 ...]
# Idempotent: safe to run again.
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER="# === token-strategy: graphify + phase discipline ==="

if [ $# -eq 0 ]; then
  echo "Usage: $0 /path/repo1 [/path/repo2 ...]" >&2
  exit 1
fi

echo "==> 1/5 graphify CLI (PyPI package: graphifyy — double y)"
if ! command -v graphify >/dev/null 2>&1; then
  if command -v uv >/dev/null 2>&1; then
    uv tool install "graphifyy[mcp]"
    uv tool update-shell || true
  elif command -v pipx >/dev/null 2>&1; then
    pipx install "graphifyy[mcp]"
    pipx ensurepath || true
  else
    # No uv/pipx (typical on a locked-down server): private venv + symlink on PATH.
    python3 -m venv "$HOME/.graphify-venv"
    "$HOME/.graphify-venv/bin/pip" install -U "graphifyy[mcp]"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$HOME/.graphify-venv/bin/graphify" "$HOME/.local/bin/graphify"
  fi
fi
graphify --version

echo "==> 2/5 ~/.claude/CLAUDE.md rule block"
mkdir -p "$HOME/.claude"
touch "$HOME/.claude/CLAUDE.md"
if grep -qF "$MARKER" "$HOME/.claude/CLAUDE.md"; then
  echo "    already present, skipped"
else
  { echo ""; echo "$MARKER"; cat "$KIT_DIR/token-strategy.md"; } >> "$HOME/.claude/CLAUDE.md"
  echo "    added"
fi

echo "==> 3/5 ~/.claude/settings.json merge (effortLevel, subagentPromptCacheTtl, workflowSizeGuideline)"
SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
python3 - "$SETTINGS" "$KIT_DIR/settings-merge.json" <<'PY'
import json, os, sys
target, fragment = sys.argv[1], sys.argv[2]
data = json.load(open(target)) if os.path.exists(target) else {}
data.update(json.load(open(fragment)))  # top-level scalar keys only; hooks etc. are preserved
json.dump(data, open(target, "w"), indent=2, ensure_ascii=False)
print("    merged:", target)
PY
python3 -m json.tool "$SETTINGS" >/dev/null  # syntax check

echo "==> 4/5 graph-sync alias for after git pull (git gpull)"
git config --global alias.gpull '!git pull && graphify update .'

echo "==> 5/5 per repository: extract + claude install + git hooks + global graph"
for repo in "$@"; do
  name="$(basename "$repo")"
  echo "--- $name ($repo)"
  (
    cd "$repo"
    graphify extract . --code-only   # local tree-sitter AST, 0 LLM tokens, no API key needed
    graphify claude install          # project CLAUDE.md section + PreToolUse hook (.claude/settings.json) + /graphify skill
    graphify hook install            # git post-commit / post-checkout (background rebuild)
    graphify global add graphify-out/graph.json --as "$name"
  )
done
graphify global list || true

cat <<'NOTES'

Done. Notes:
- Optional semantic pass over docs/PDFs (needs an API key): graphify extract ./docs --backend claude
- The MCP server is OPTIONAL — the primary integration is skill + hook. If you want it, inside a repo:
    claude mcp add graphify -- python -m graphify.serve graphify-out/graph.json
  Careful: with a uv/pipx install a bare `python` will not see this module; use the python of an environment that has
  graphifyy[mcp] installed. (This command is not in the Graphify README; it is inferred from the Claude Code CLI.)
- Upgrade (releases ship very often), then re-run in every repo: graphify claude install && graphify hook install
- After git pull: use `git gpull`, or run `graphify update .` by hand — the hooks do NOT catch pull/merge.
- Strict mode (blocks the first raw source read of a session and redirects it to the graph):
    GRAPHIFY_HOOK_STRICT=1  (runtime toggle)
NOTES
