#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-4000}"
BASE_URL="${BASE_URL:-http://127.0.0.1:${PORT}}"

log() {
  echo "[smoke] $1"
}

log "Using base URL: ${BASE_URL}"

log "Checking /healthz"
curl -fsS "${BASE_URL}/healthz" | node -e "const input = require('fs').readFileSync(0, 'utf8'); const data = JSON.parse(input); if (!data.ok) { console.error('Health check did not return ok=true'); process.exit(1); } if (data.status !== 'healthy' && data.status !== 'degraded') { console.error('Unexpected health status value:', data.status); process.exit(1); }"

log "Checking /api/jobs"
curl -fsS "${BASE_URL}/api/jobs" | node -e "const input = require('fs').readFileSync(0, 'utf8'); const data = JSON.parse(input); if (!data.ok) { console.error('Jobs endpoint returned ok=false'); process.exit(1); } if (!Array.isArray(data.runs) || data.runs.length === 0) { console.error('Jobs endpoint missing runs array'); process.exit(1); }"

log "Checking /api/status"
curl -fsS "${BASE_URL}/api/status" | node -e "const input = require('fs').readFileSync(0, 'utf8'); const data = JSON.parse(input); if (!data.ok) { console.error('Status endpoint returned ok=false'); process.exit(1); } if (!data.summary || typeof data.summary.total_runs !== 'number') { console.error('Status summary missing total_runs'); process.exit(1); }"

log "Checking /api/branches"
curl -fsS "${BASE_URL}/api/branches" | node -e "const input = require('fs').readFileSync(0, 'utf8'); const data = JSON.parse(input); if (!data.ok) { console.error('Branches endpoint returned ok=false'); process.exit(1); } if (!Array.isArray(data.branches) || data.branches.length === 0) { console.error('Branches endpoint returned empty list'); process.exit(1); } if (data.default_branch && !data.branches.includes(data.default_branch)) { console.error('Default branch missing from branches list'); process.exit(1); }"

log "Checking invalid branch handling"
tmp_branch_response="$(mktemp)"
http_code="$(curl -s -o "${tmp_branch_response}" -w '%{http_code}' "${BASE_URL}/api/status?branch=__invalid_branch__")"
node -e "const fs = require('fs'); const data = JSON.parse(fs.readFileSync('${tmp_branch_response}', 'utf8')); if (data.error !== 'branch_invalid') { console.error('Expected branch_invalid error'); process.exit(1); } if (!data.details || !Array.isArray(data.details.available_branches)) { console.error('branch_invalid response missing available branches'); process.exit(1); }"
rm -f "${tmp_branch_response}"
if [[ "${http_code}" -ne 404 && "${http_code}" -ne 400 ]]; then
  echo "Expected 404 or 400 HTTP status for invalid branch, got ${http_code}"
  exit 1
fi

log "Checking /status HTML"
status_page="$(curl -fsS "${BASE_URL}/status")"
if [[ "${status_page}" != *"<!DOCTYPE html>"* ]]; then
  echo "Status page did not return HTML"
  exit 1
fi

log "All smoke tests passed"
