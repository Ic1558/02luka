#!/usr/bin/env bash
set -uo pipefail

API_BASE="${API_BASE:-http://127.0.0.1:4000}"
UI_BASE="${UI_BASE:-http://127.0.0.1:5173}"
MCP_BASE="${MCP_BASE:-http://127.0.0.1:8765}"
STAMP="$(date +%Y%m%d_%H%M%S)"
REPORT="g/reports/VALIDATION_${STAMP}.md"

shopt -s nocasematch

# ------- helpers -------
sec(){ perl -MTime::HiRes=time -e 'printf "%.3f", time' ; }
tms(){ local s1 s2; s1="$(sec)"; set +e; "$@" >/tmp/cmd.out 2>/tmp/cmd.err; local rc=$?; set -e; s2="$(sec)"; awk -v a="$s1" -v b="$s2" 'BEGIN{printf "%.3f", (b-a)}'; return $rc; }
ok(){ echo "✅"; }
warn(){ echo "⚠️"; }
fail(){ echo "❌"; }
jqmin(){ command -v jq >/dev/null 2>&1 && jq -r "$1" || python3 - <<PY 2>/dev/null || cat /tmp/cmd.out
import sys,json; d=json.load(sys.stdin);
k="${1}".strip('.');
v=d
for p in k.split('.'):
  v=v.get(p, {})
print(v if isinstance(v,str) else (json.dumps(v) if v else ""))
PY
}

critical_pass=0
critical_total=0
optional_pass=0
optional_total=0
section(){
  echo -e "\n## $1\n" >> "$REPORT"
}

mkdir -p g/reports

# ------- 0) Ensure services are up -------
echo "# 02LUKA Full Validation — $STAMP" > "$REPORT"
echo -e "\nStarting services if needed..." >> "$REPORT"
( bash ./run/dev_up_simple.sh >/tmp/dev_up.out 2>&1 || true )
echo -e "\n<details><summary>dev_up_simple.sh output</summary>\n\n\`\`\`\n$(sed -e 's/`/\\`/g' /tmp/dev_up.out)\n\`\`\`\n</details>" >> "$REPORT"

# ------- 1) Core API -------
section "Core API"
((critical_total+=1))
t=$(tms curl -s --max-time 5 "$API_BASE/api/capabilities" -H 'Accept: application/json')
rc=$?
if [[ $rc -eq 0 ]]; then
  caps="$(cat /tmp/cmd.out | jqmin '.')"
  echo "- Capabilities $(ok) (${t}s)" >> "$REPORT"
  ((critical_pass+=1))
else
  echo "- Capabilities $(fail) (timeout or error) (${t}s)" >> "$REPORT"
fi

((critical_total+=1))
t=$(tms curl -s --max-time 5 "$API_BASE/api/plan" -H 'Content-Type: application/json' -d '{"goal":"ping","stub":true}')
rc=$?
if [[ $rc -eq 0 ]]; then
  mode="$(cat /tmp/cmd.out | jqmin '.mode')"
  echo "- Plan stub $(ok) (${t}s) mode=${mode:-n/a}" >> "$REPORT"
  ((critical_pass+=1))
else
  echo "- Plan stub $(fail) (${t}s)" >> "$REPORT"
fi

section "Reports API"
((critical_total+=1))
t=$(tms curl -s --max-time 5 "$API_BASE/api/reports/summary")
rc=$?
if [[ $rc -eq 0 ]]; then
  echo "- Reports summary $(ok) (${t}s)" >> "$REPORT"
  ((critical_pass+=1))
else
  echo "- Reports summary $(fail) (${t}s)" >> "$REPORT"
fi

# ------- 2) UI checks -------
section "UI"
((critical_total+=1))
t=$(tms curl -sI --max-time 5 "$UI_BASE/")
rc=$?
if [[ $rc -eq 0 && "$(head -1 /tmp/cmd.out | awk '{print $2}')" == "200" ]]; then
  echo "- UI index $(ok) (${t}s)" >> "$REPORT"
  ((critical_pass+=1))
else
  code="$(head -1 /tmp/cmd.out | awk '{print $2}')"
  echo "- UI index $(fail) (${t}s) code=${code:-n/a}" >> "$REPORT"
fi

((critical_total+=1))
t=$(tms curl -sI --max-time 5 "$UI_BASE/luka.html")
rc=$?
if [[ $rc -eq 0 && "$(head -1 /tmp/cmd.out | awk '{print $2}')" == "200" ]]; then
  echo "- UI luka.html $(ok) (${t}s)" >> "$REPORT"
  ((critical_pass+=1))
else
  code="$(head -1 /tmp/cmd.out | awk '{print $2}')"
  echo "- UI luka.html $(fail) (${t}s) code=${code:-n/a}" >> "$REPORT"
fi

# ------- 3) Optional: Discord -------
section "Discord (Optional)"
((optional_total+=1))
if [[ -n "${DISCORD_WEBHOOK_DEFAULT:-}" ]]; then
  payload='{"content":"02LUKA validation ping ✅","level":"info","channel":"default"}'
  t=$(tms curl -s --max-time 6 -X POST "$API_BASE/api/discord/notify" -H "Content-Type: application/json" -d "$payload")
  rc=$?
  if [[ $rc -eq 0 && "$(cat /tmp/cmd.out | jqmin '.ok')" == "true" ]]; then
    echo "- Discord notify $(ok) (${t}s)" >> "$REPORT"
    ((optional_pass+=1))
  else
    echo "- Discord notify $(fail) (${t}s)" >> "$REPORT"
  fi
else
  echo "- Discord notify $(warn) SKIP (no DISCORD_WEBHOOK_DEFAULT)" >> "$REPORT"
fi

# ------- 4) Optional: MCP FS health -------
section "MCP FS (Optional)"
((optional_total+=1))
t=$(tms curl -s --max-time 3 "$MCP_BASE/health")
rc=$?
if [[ $rc -eq 0 ]]; then
  status="$(cat /tmp/cmd.out | jqmin '.status')"
  if [[ "$status" == "ok" ]]; then
    echo "- MCP FS health $(ok) (${t}s)" >> "$REPORT"
    ((optional_pass+=1))
  else
    echo "- MCP FS health $(fail) (${t}s) status=${status:-n/a}" >> "$REPORT"
  fi
else
  echo "- MCP FS health $(warn) unreachable (${t}s)" >> "$REPORT"
fi

# ------- 5) Summary & grade -------
section "Summary"
crit_fail=$((critical_total - critical_pass))
opt_fail=$((optional_total - optional_pass))
grade="A"
risk="LOW"
if (( crit_fail > 0 )); then grade="C"; risk="HIGH"; fi

cat >> "$REPORT" <<OUT
- Critical: ${critical_pass}/${critical_total} passed
- Optional: ${optional_pass}/${optional_total} passed
- Grade: **${grade}**
- Risk: **${risk}**

**Next steps:**
$( ((crit_fail==0)) && echo "- All critical checks passed. No action required." || echo "- Investigate FAILED critical items above (API/UI) and restart those services." )
- For Discord WARN: export DISCORD_WEBHOOK_DEFAULT and re-run.
- For MCP WARN: start/forward port 8765 if you need MCP inside this env.

> Re-run anytime:
\`\`\`bash
bash ./run/validate_full.sh
\`\`\`
OUT

echo "Wrote $REPORT"
echo "Critical ${critical_pass}/${critical_total} | Optional ${optional_pass}/${optional_total} | Grade ${grade}"
# non-zero exit if any critical failed
(( crit_fail == 0 )) || exit 2
