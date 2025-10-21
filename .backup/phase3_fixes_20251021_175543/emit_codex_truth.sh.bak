#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

mkdir -p .codex run/auto_context

# 1) System Map (CONTEXT_SEED.md)
{
  echo "# 02luka System Map (auto)"
  echo
  echo "## Roots & Roles"
  echo "- g/: infra tools, validators, helpers"
  echo "- run/: runtime artifacts, status, reports"
  echo "- boss/: your workspace (inbox/sent/deliverables/dropbox)"
  echo "- f/ai_context/: resolver mapping & context data"
  echo "- Forbidden for AI writes: a/, c/, o/, s/ (human-only)"
  echo
  echo "## Tree (depth 2)"
  (command -v tree >/dev/null && tree -L 2 -a -I '.git|node_modules|.venv*' || find . -maxdepth 2 -type d | sort) | sed 's/^/    /'
  echo
  echo "## Known Services"
  # boss-api port scan
  PORTS="$(grep -RnoE 'PORT\s*=\s*.*(4000|[0-9]{3,5})' boss-api 2>/dev/null || true)"
  echo "- boss-api: $( [ -n "$PORTS" ] && echo "$PORTS" | sed 's/^/    /' || echo 'not found')"
  echo
  echo "## Data Flow"
  echo "dropbox → (router) → inbox/sent (query/answer) → deliverables"
} > .codex/CONTEXT_SEED.md

# 2) Mapping ของเครื่อง (mapping.json) — copy สถานะจริง + สรุป key
MAP="f/ai_context/mapping.json"
if [ -f "$MAP" ]; then
  jq -r '.' "$MAP" > run/auto_context/mapping.snapshot.json || cp "$MAP" run/auto_context/mapping.snapshot.json
  echo "# Mapping Summary (auto)" > run/auto_context/mapping.keys.md
  echo >> run/auto_context/mapping.keys.md
  (jq -r 'paths(scalars) as $p | "\($p|join(".")) = \(.|getpath($p))"' "$MAP" 2>/dev/null || true) | sed 's/^/- /' >> run/auto_context/mapping.keys.md
else
  echo "{}" > run/auto_context/mapping.snapshot.json
  echo "# Mapping Summary (auto)\n- (mapping.json not found)" > run/auto_context/mapping.keys.md
fi

# 3) PATH_KEYS.md — ดึง key ที่อนุญาตจาก mapping + ตัวอย่าง resolver
{
  echo "# PATH KEYS (auto)"
  echo
  echo "Use: \`bash g/tools/path_resolver.sh human:<key>\`"
  echo
  if [ -f "$MAP" ]; then
    echo "## Allowed keys (from mapping.json)"
    KEYS="$(jq -r 'paths | map(tostring) | join(":")' "$MAP" 2>/dev/null || true)"
    if [ -n "$KEYS" ]; then
      echo "$KEYS" | sed 's/^/- /'
    else
      echo "- (no keys parsed)"
    fi
  else
    echo "- (mapping.json not found)"
  fi
  echo
  echo "## Examples"
  echo '```bash'
  echo 'bash g/tools/path_resolver.sh human:inbox'
  echo 'bash g/tools/path_resolver.sh human:sent'
  echo 'bash g/tools/path_resolver.sh human:deliverables'
  echo '```'
} > .codex/PATH_KEYS.md

# 4) Guardrails + Tests — รวบรวมข้อห้าม + คำสั่งทดสอบจริง
{
  echo "# GUARDRAILS (auto)"
  echo "- Resolver-only paths (no absolute paths, no symlinks)"
  echo "- Do NOT write under a/, c/, o/, s/"
  echo "- CORS required for API"
  echo "- Path traversal guard required for file reads"
  echo
  echo "## Tests to run"
  echo '```bash'
  echo 'bash .codex/preflight.sh'
  echo 'bash g/tools/mapping_drift_guard.sh --validate'
  echo 'bash g/tools/clc_gate.sh'
  echo '# optional smoke (if port free)'
  echo 'HOST=127.0.0.1 PORT=4000 node boss-api/server.cjs'
  echo 'curl -s http://127.0.0.1:4000/api/list/inbox | jq .'
  echo '```'
} > .codex/GUARDRAILS.md

# 5) Workflow/Recipes — ดึงสูตรที่ใช้บ่อย (ถ้าไม่มี ใส่สั้นๆ ให้)
if [ ! -f ".codex/TASK_RECIPES.md" ]; then
  {
    echo "# TASK RECIPES (auto)"
    echo "## Patch server.cjs to resolver-only + WHATWG URL"
    echo "- Replace server code to call g/tools/path_resolver.sh from repo root"
    echo "## Set boss-ui API base"
    echo "- Point to http://127.0.0.1:4000"
    echo "## Append manifest + update daily report"
    echo "- run/change_units/<CONTEXT_ID>.yml (append), run/daily_reports/REPORT_\$(date +%F).md"
  } > .codex/TASK_RECIPES.md
fi

# 6) Environment Hints — สร้างไฟล์ env ให้ชัด
{
  echo "HOST: 127.0.0.1"
  echo "PORT: 4000"
  echo "SOT_PATH_HINT: $ROOT"
} > .codex/codex.env.yml

# รายงานผล
echo "[02luka] codex-truth emitted:"
ls -la .codex | sed 's/^/  /'
ls -la run/auto_context | sed 's/^/  /' || true
