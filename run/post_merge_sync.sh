#!/usr/bin/env bash
set -euo pipefail
echo "== Post-merge sync =="
branch="$(git rev-parse --abbrev-ref HEAD)"
[ "$branch" = "main" ] || git checkout main
git fetch origin
git pull --rebase origin main || true

echo "== Preflight & mapping =="
bash .codex/preflight.sh
bash g/tools/mapping_drift_guard.sh --validate

echo "== Smoke API/UI =="
export HOST=${HOST:-127.0.0.1}
export PORT=${PORT:-4000}
bash run/smoke_api_ui.sh || true

echo "== Daily report =="
mkdir -p run/daily_reports
echo "- $(date +%F) Post-merge sync run on $branch" >> run/daily_reports/REPORT_$(date +%F).md
git add run/daily_reports/REPORT_$(date +%F).md || true
git commit -m "chore(report): post-merge sync run" || true
echo "Done."
