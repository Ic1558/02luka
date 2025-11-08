import fs from "fs";
import path from "path";

const ROOT = process.env.HOME;
const CURSOR_CFG = path.join(ROOT, ".cursor", "mcp.json");
const REGISTRY_PATH = "hub/mcp_registry.json";

function safeRead(p) {
  try { return JSON.parse(fs.readFileSync(p, "utf8")); }
  catch { return {}; }
}

const cfg = safeRead(CURSOR_CFG);
const servers = Object.entries(cfg.mcpServers || {}).map(([name, data]) => ({
  name,
  command: data.command,
  args: data.args,
  detected_at: new Date().toISOString()
}));

const output = {
  _meta: {
    created_by: "GG_Agent_02luka",
    created_at: new Date().toISOString(),
    source: "hub/mcp_discovery.mjs",
    total: servers.length
  },
  servers
};

fs.writeFileSync(REGISTRY_PATH, JSON.stringify(output, null, 2));
console.log(`✅ MCP Registry generated (${servers.length} servers)`);
