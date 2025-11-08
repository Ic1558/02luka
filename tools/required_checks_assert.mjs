import fs from "fs";
import path from "path";

const root = process.cwd();
const cfg = JSON.parse(fs.readFileSync(path.join(root, "config/required_checks.json"), "utf-8"));
const wfDir = path.join(root, ".github", "workflows");

const jobIds = new Set();
for (const f of fs.readdirSync(wfDir)) {
  if (!f.endsWith(".yml") && !f.endsWith(".yaml")) continue;
  const txt = fs.readFileSync(path.join(wfDir, f), "utf-8");
  // naive parse: find top-level job IDs (lines starting without spaces then colon under "jobs:")
  const m = txt.match(/jobs:\s*([\s\S]+)/);
  if (!m) continue;
  const section = m[1];
  const ids = [...section.matchAll(/^\s{2}([a-zA-Z0-9_-]+):\s*$/gm)].map(x => x[1]);
  ids.forEach(id => jobIds.add(id));
}

const missing = cfg.required.filter(r => !jobIds.has(r));
if (missing.length) {
  console.error("❌ Missing required job IDs in workflows:", missing);
  process.exit(1);
} else {
  console.log("✅ All required job IDs present:", cfg.required.join(", "));
}
