#!/usr/bin/env zsh
set -euo pipefail
REPO="$HOME/02luka"; cd "$REPO"
/opt/homebrew/bin/node run/health_dashboard.cjs export > g/reports/health_dashboard.json 2>&1 || true

STAMP=$(date -u +%Y%m%d_%H%MZ)
mkdir -p g/reports/phase5/daily
cp g/reports/health_dashboard.json "g/reports/phase5/daily/health_dashboard_${STAMP}.json" 2>/dev/null || true
cp g/reports/health_dashboard.txt "g/reports/phase5/daily/health_dashboard_${STAMP}.txt" 2>/dev/null || true

# Lightweight HTML wrapper
cat > "g/reports/phase5/daily/health_dashboard_${STAMP}.html" <<'HTML'
<!doctype html><meta charset="utf-8">
<title>02LUKA Health Dashboard</title>
<style>body{font-family:system-ui, -apple-system, Segoe UI, Roboto; margin:24px;}</style>
<h1>02LUKA Health Dashboard</h1>
<pre id="data"></pre>
<script>
fetch('../health_dashboard.json').then(r=>r.json()).then(j=>{
  document.getElementById('data').textContent = JSON.stringify(j,null,2);
}).catch(()=>{document.getElementById('data').textContent='(no data)';});
</script>
HTML
echo "$(date -u +%F\ %T) dashboard: exported" >> g/logs/ops_dashboard.log
