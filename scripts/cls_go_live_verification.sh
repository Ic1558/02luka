#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pushd "$REPO_ROOT" >/dev/null

# 0) Pretty
BOLD=$(tput bold 2>/dev/null || true); NC=$(tput sgr0 2>/dev/null || true)
ok(){ echo "✅ $*"; }
warn(){ echo "⚠️  $*"; }
die(){ echo "❌ $*"; exit 1; }

echo "${BOLD}CLS Go-Live Verification — $(date -Iseconds)${NC}"

# 1) Shell resolver
echo "1) Checking shell resolver…"
CLS_SHELL="${CLS_SHELL:-}"
SHELL_JS='console.log(require("./packages/skills/resolveShell").resolveShell())'
RESOLVED="$(node -e "$SHELL_JS" || true)"
if [[ -z "$RESOLVED" || ! -x "$RESOLVED" ]]; then
  warn "Resolver returned '$RESOLVED'. Forcing /bin/bash."
  export CLS_SHELL="/bin/bash"
  RESOLVED="/bin/bash"
fi
ok "Shell: $RESOLVED"

# 2) Filesystem allowlist
echo "2) Checking FS allowlist…"
DEFAULT_ALLOW="/Volumes/lukadata:/Volumes/hd2:$HOME/Documents/Projects"
export CLS_FS_ALLOW="${CLS_FS_ALLOW:-$DEFAULT_ALLOW}"
IFS=':' read -r -a ROOTS <<<"$CLS_FS_ALLOW"
[[ ${#ROOTS[@]} -gt 0 ]] || die "CLS_FS_ALLOW empty"
for r in "${ROOTS[@]}"; do
  [[ -d "$r" ]] || warn "Allow root not found: $r"
done
ok "Allow roots: $CLS_FS_ALLOW"

# 3) SecureFS wiring (Node require)
echo "3) Loading secureFS…"
node -e 'require("./packages/fs/secureFS") && console.log("secureFS OK")' >/dev/null || die "secureFS not loadable"
ok "secureFS OK"

# 4) Prepare inbox tasks (idempotent, safe paths only)
echo "4) Seeding safe tasks into queue/inbox/…"
mkdir -p queue/inbox queue/done queue/failed 2>/dev/null || true

cat > queue/inbox/001_mkfile.json <<'JSON'
{
  "id": "001_mkfile",
  "risk": "low",
  "skill": "bash",
  "desc": "Create hello file on lukadata",
  "writePaths": ["/Volumes/lukadata/CLS/tmp"],
  "cmd": "mkdir -p /Volumes/lukadata/CLS/tmp && echo 'hello cls' > /Volumes/lukadata/CLS/tmp/hello.txt"
}
JSON

cat > queue/inbox/002_node.json <<'JSON'
{
  "id": "002_node",
  "risk": "low",
  "skill": "node",
  "desc": "Sum 1..100 and write result",
  "code": "const fs=require('fs');let s=0;for(let i=1;i<=100;i++)s+=i;fs.mkdirSync('/Volumes/lukadata/CLS/tmp',{recursive:true});fs.writeFileSync('/Volumes/lukadata/CLS/tmp/sum.txt',String(s));console.log(s);"
}
JSON

cat > queue/inbox/003_disk.json <<'JSON'
{
  "id": "003_disk_usage",
  "risk": "low",
  "skill": "bash",
  "desc": "Disk usage snapshot",
  "cmd": "df -h /Volumes/lukadata /Volumes/hd2 || true"
}
JSON

ok "Seeded 3 tasks"

# 5) Run orchestrator
echo "5) Running orchestrator…"
node agents/local/orchestrator.cjs || true

# 6) Check queue rotation
echo "6) Verifying queue rotation…"
DONE=$(ls -1 queue/done 2>/dev/null | wc -l | tr -d ' ')
FAILED=$(ls -1 queue/failed 2>/dev/null | wc -l | tr -d ' ')
ok "Queue → done:$DONE failed:$FAILED"

# 7) Check artifacts on lukadata
echo "7) Checking artifacts on lukadata…"
[[ -f /Volumes/lukadata/CLS/tmp/hello.txt ]] && ok "hello.txt present" || warn "hello.txt missing"
[[ -f /Volumes/lukadata/CLS/tmp/sum.txt ]] && ok "sum.txt present" || warn "sum.txt missing"

# 8) Telemetry + Memory
echo "8) Telemetry & Memory…"
TELEM_LAST=$(ls -1t g/telemetry/*.log 2>/dev/null | head -n1 || true)
[[ -n "$TELEM_LAST" ]] && tail -n 3 "$TELEM_LAST" || warn "No telemetry log yet"
node memory/index.cjs --stats || warn "Memory stats not available"

# 9) Produce verification report
echo "9) Writing report…"
mkdir -p g/reports
REPORT="g/reports/CLS_GO_LIVE_VERIFICATION_$(date +%Y%m%d_%H%M%S).md"
cat > "$REPORT" <<EOF
# CLS Go-Live Verification

- Date: $(date -Iseconds)
- Shell: \`$RESOLVED\`
- FS Allow: \`$CLS_FS_ALLOW\`
- Queue: done=$DONE, failed=$FAILED

## Artifacts
- /Volumes/lukadata/CLS/tmp/hello.txt $( [[ -f /Volumes/lukadata/CLS/tmp/hello.txt ]] && echo "✅" || echo "❌" )
- /Volumes/lukadata/CLS/tmp/sum.txt $( [[ -f /Volumes/lukadata/CLS/tmp/sum.txt ]] && echo "✅" || echo "❌" )

## Notes
- If paths were blocked, ensure they are inside the allowlist and mounted.
- Set \`CLS_SHELL=/bin/bash\` if your container lacks zsh.

EOF

ok "Report: $REPORT"

echo
echo "${BOLD}DONE — review the report above.${NC}"
popd >/dev/null
