#!/usr/bin/env zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CUR_DIR="$ROOT/.cursor"
EX="$CUR_DIR/mcp.example.json"
DST="$CUR_DIR/mcp.json"
mkdir -p "$CUR_DIR"
if [[ ! -f "$EX" ]]; then
  cat > "$EX" <<'JSON'
{
  "//": "Local-only MCP example. Copy to .cursor/mcp.json on each machine.",
  "mcpServers": {
    "mcp_fs": {
      "transport": { "type": "http", "url": "http://127.0.0.1:8765" }
    },
    "mcp_docker": {
      "transport": { "type": "http", "url": "http://127.0.0.1:5012" }
    }
  }
}
JSON
  echo "Created $EX"
fi
if [[ ! -f "$DST" ]]; then
  cp "$EX" "$DST"
  echo "Created $DST from example."
fi
# Install pre-commit guard (append or create), preserving existing logic
HOOK="$ROOT/.git/hooks/pre-commit"
mkdir -p "$ROOT/.git/hooks"
if [[ -f "$HOOK" ]]; then
  # Only append guard if missing
  if ! grep -q '.cursor/mcp.json' "$HOOK"; then
    cat >> "$HOOK" <<'SH'
# Guard local-only Cursor MCP config
if git diff --cached --name-only | grep -qx ".cursor/mcp.json"; then
  echo "Refusing to commit .cursor/mcp.json (local-only)."
  exit 1
fi
SH
  fi
else
  cat > "$HOOK" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# Guard local-only Cursor MCP config
if git diff --cached --name-only | grep -qx ".cursor/mcp.json"; then
  echo "Refusing to commit .cursor/mcp.json (local-only)."
  exit 1
fi
exit 0
SH
  chmod +x "$HOOK"
fi
# Validate JSON when jq available
if command -v jq >/dev/null 2>&1; then
  jq empty "$EX"
  jq empty "$DST"
  echo "JSON OK: $EX and $DST"
else
  echo "Note: jq not found; JSON validation skipped."
fi

echo "dev-setup complete."
