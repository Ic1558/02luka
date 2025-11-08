#!/usr/bin/env bash
set -euo pipefail

echo "▶ MCP prune (project-level) — remove MCP_DOCKER, keep local_02luka"

# Paths - adjust these to your local environment
# On macOS/Linux dev machines: $HOME typically points to /Users/<username> or /home/<username>
# In CI/containers: may point to /root
PROJECTS=("$HOME/LocalProjects/02luka/.cursor/mcp.json" "$HOME/02luka/.cursor/mcp.json")
GLOBAL="$HOME/.cursor/mcp.json"

# Alternative: auto-detect common locations
# Uncomment and adjust if needed:
# if [[ -d "/home/user/02luka" ]]; then
#   PROJECTS=("/home/user/LocalProjects/02luka/.cursor/mcp.json" "/home/user/02luka/.cursor/mcp.json")
# fi

fix_project_json() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "  - skip (missing): $file"
    return
  fi
  # Read JSON
  local tmp; tmp="$(mktemp -t mcp_fix.XXXXXX.json)"
  # Normalize to mcpServers key and drop MCP_DOCKER
  node -e '
    const fs=require("fs");
    const p=process.argv[1];
    const raw=fs.readFileSync(p,"utf8");
    let j=JSON.parse(raw);
    const key = j.mcpServers ? "mcpServers" : (j.servers ? "servers" : "mcpServers");
    j.mcpServers = j[key] || {};
    delete j.servers;

    // Keep only local_02luka
    const srv = j.mcpServers || {};
    const keep = {};
    if (srv.local_02luka) keep.local_02luka = srv.local_02luka;
    j.mcpServers = keep;

    // Ensure args array for local_02luka
    if (j.mcpServers.local_02luka) {
      j.mcpServers.local_02luka.args = Array.isArray(j.mcpServers.local_02luka.args) ? j.mcpServers.local_02luka.args : [];
    }

    process.stdout.write(JSON.stringify(j,null,2));
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "  ✓ pruned: $file"
}

for f in "${PROJECTS[@]}"; do
  fix_project_json "$f"
done

# Show summary
echo "— Summary —"
echo "Global servers (should include MCP_DOCKER):"
[[ -f "$GLOBAL" ]] && jq '.mcpServers // .servers' "$GLOBAL" || echo "  (no global config found)"
echo
echo "Project servers (should be only local_02luka):"
for f in "${PROJECTS[@]}"; do
  if [[ -f "$f" ]]; then
    echo "  • $f"
    jq '.mcpServers // .servers' "$f"
  else
    echo "  • $f (missing)"
  fi
done

echo "Done."
