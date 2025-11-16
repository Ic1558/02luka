#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

REPORT_DIR="$REPO_ROOT/g/reports/system"
TEMPLATE_PATH="$REPORT_DIR/reality_hooks_PR_TEMPLATE.md"
mkdir -p "$REPORT_DIR"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

pr_identifier="local"
if [[ -n "${GITHUB_REF:-}" && "$GITHUB_REF" == refs/pull/* ]]; then
  pr_number="${GITHUB_REF#refs/pull/}"
  pr_number="${pr_number%%/*}"
  pr_identifier="PR-${pr_number}"
elif [[ -n "${GITHUB_HEAD_REF:-}" ]]; then
  pr_identifier="$GITHUB_HEAD_REF"
elif [[ -n "${GITHUB_REF_NAME:-}" ]]; then
  pr_identifier="$GITHUB_REF_NAME"
else
  pr_identifier="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo local)"
fi
PR_IDENTIFIER="$pr_identifier"

commit_sha_full="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo local)}"
if [[ "$commit_sha_full" == local ]]; then
  short_sha="local"
else
  short_sha="${commit_sha_full:0:12}"
fi
REPORT_FILE="$REPORT_DIR/reality_hooks_pr_${short_sha}.md"

CHECK_ORDER=(dashboard_smoke orchestrator_smoke telemetry_schema)
declare -A CHECK_LABELS
CHECK_LABELS[dashboard_smoke]="Dashboard smoke"
CHECK_LABELS[orchestrator_smoke]="Orchestrator summary"
CHECK_LABELS[telemetry_schema]="Telemetry schema"

declare -A CHECK_STATUS
declare -A CHECK_DETAIL
for key in "${CHECK_ORDER[@]}"; do
  CHECK_STATUS[$key]="unknown"
  CHECK_DETAIL[$key]="not run"
done

record_check() {
  local key="$1"
  local status="$2"
  local detail="$3"
  CHECK_STATUS[$key]="$status"
  CHECK_DETAIL[$key]="$detail"
}

dashboard_smoke_check() {
  local key="dashboard_smoke"
  local data_file="$REPO_ROOT/g/apps/dashboard/dashboard_data.json"
  log "▶ Checking dashboard data at $data_file"
  if [[ ! -f "$data_file" ]]; then
    local msg="Dashboard data file missing: $data_file"
    log "❌ $msg"
    record_check "$key" "fail" "$msg"
    return 1
  fi

  local output
  if ! output=$(DASHBOARD_DATA="$data_file" node <<'EOS' 2>&1
const fs = require('fs');
const path = process.env.DASHBOARD_DATA;
const payload = JSON.parse(fs.readFileSync(path, 'utf8'));
if (!payload.roadmap || typeof payload.roadmap.overall_progress_pct !== 'number') {
  throw new Error('roadmap.overall_progress_pct missing or invalid');
}
if (!payload.services || typeof payload.services.total !== 'number') {
  throw new Error('services.total missing or invalid');
}
const progress = payload.roadmap.overall_progress_pct;
const phase = payload.roadmap.current_phase_name || 'unknown';
const services = payload.services.total;
console.log(`Roadmap "${payload.roadmap.name}" phase "${phase}" (${progress}% complete, services=${services}).`);
EOS
); then
    log "❌ Dashboard validation failed"
    record_check "$key" "fail" "$output"
    return 1
  fi

  log "✅ Dashboard data looks healthy"
  record_check "$key" "ok" "$output"
  return 0
}

orchestrator_smoke_check() {
  local key="orchestrator_smoke"
  local orchestrator="$REPO_ROOT/tools/subagents/orchestrator.zsh"
  local summary_a="$REPORT_DIR/subagent_orchestrator_summary.json"
  local summary_b="$REPORT_DIR/claude_orchestrator_summary.json"

  log "▶ Running orchestrator smoke test"
  if [[ ! -x "$orchestrator" ]]; then
    local msg="Orchestrator script missing or not executable: $orchestrator"
    log "❌ $msg"
    record_check "$key" "fail" "$msg"
    return 1
  fi

  rm -f "$summary_a" "$summary_b"
  local orchestrator_stdout="/tmp/reality_orchestrator.out"
  local orchestrator_stderr="/tmp/reality_orchestrator.err"
  local orchestrator_shell
  if command -v zsh >/dev/null 2>&1; then
    orchestrator_shell="$(command -v zsh)"
  else
    orchestrator_shell="$(command -v bash)"
  fi

  if ! LUKA_SOT="$REPO_ROOT" "$orchestrator_shell" "$orchestrator" compete "echo reality_hook_success" 1 >"$orchestrator_stdout" 2>"$orchestrator_stderr"; then
    local msg="Orchestrator execution failed (see /tmp/reality_orchestrator.err)"
    log "❌ $msg"
    record_check "$key" "fail" "$(cat "$orchestrator_stderr" 2>/dev/null || echo "$msg")"
    return 1
  fi

  local summary_file="$summary_a"
  [[ -f "$summary_file" ]] || summary_file="$summary_b"
  if [[ ! -f "$summary_file" ]]; then
    local msg="Summary JSON not produced at $summary_a or $summary_b"
    log "❌ $msg"
    record_check "$key" "fail" "$msg"
    return 1
  fi

  local output
  if ! output=$(SUMMARY_FILE="$summary_file" node <<'EOS' 2>&1
const fs = require('fs');
const path = process.env.SUMMARY_FILE;
const payload = JSON.parse(fs.readFileSync(path, 'utf8'));
if (!Array.isArray(payload.agents) || payload.agents.length === 0) {
  throw new Error('agents array missing or empty');
}
if (!payload.winner) {
  throw new Error('winner field missing');
}
console.log(`Summary ${path} OK – ${payload.agents.length} agents, winner=${payload.winner}.`);
EOS
); then
    log "❌ Summary validation failed"
    record_check "$key" "fail" "$output"
    return 1
  fi

  rm -f "$orchestrator_stdout" "$orchestrator_stderr"

  log "✅ Orchestrator summary looks valid"
  record_check "$key" "ok" "$output"
  return 0
}

telemetry_schema_check() {
  local key="telemetry_schema"
  local schema_path="$REPO_ROOT/schemas/telemetry_v2.schema.json"
  local sample_path="$REPO_ROOT/telemetry/sample_telemetry_v2.json"

  log "▶ Validating telemetry sample against schema"
  if [[ ! -f "$schema_path" ]]; then
    local msg="Telemetry schema missing: $schema_path"
    log "❌ $msg"
    record_check "$key" "fail" "$msg"
    return 1
  fi
  if [[ ! -f "$sample_path" ]]; then
    local msg="Telemetry sample missing: $sample_path"
    log "❌ $msg"
    record_check "$key" "fail" "$msg"
    return 1
  fi

  local output
  if ! output=$(TELEMETRY_SCHEMA="$schema_path" TELEMETRY_SAMPLE="$sample_path" node <<'EOS' 2>&1
const fs = require('fs');
const path = require('path');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

const schemaPath = process.env.TELEMETRY_SCHEMA;
const samplePath = process.env.TELEMETRY_SAMPLE;
const schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
const rawSample = fs.readFileSync(samplePath, 'utf8');
const ext = path.extname(samplePath).toLowerCase();
let payload;
if (ext === '.jsonl' || ext === '.ndjson') {
  const line = rawSample
    .split(/\r?\n/)
    .map((entry) => entry.trim())
    .find((entry) => entry.startsWith('{'));
  if (!line) {
    throw new Error('Telemetry sample file contains no JSON entries');
  }
  payload = JSON.parse(line);
} else {
  payload = JSON.parse(rawSample);
}
const ajv = new Ajv({allErrors: true, strict: false});
addFormats(ajv);
const validate = ajv.compile(schema);
if (!validate(payload)) {
  const errors = validate.errors.map((err) => `${err.instancePath || '/'} ${err.message}`).join('; ');
  throw new Error(`Schema validation failed: ${errors}`);
}
console.log(`Telemetry entry from ${path.basename(samplePath)} validates against telemetry_v2 schema.`);
EOS
); then
    log "❌ Telemetry validation failed"
    record_check "$key" "fail" "$output"
    return 1
  fi

  log "✅ Telemetry schema check passed"
  record_check "$key" "ok" "$output"
  return 0
}

overall_rc=0
if ! dashboard_smoke_check; then
  overall_rc=1
fi
if ! orchestrator_smoke_check; then
  overall_rc=1
fi
if ! telemetry_schema_check; then
  overall_rc=1
fi

render_detail_log() {
  local detail=""
  for key in "${CHECK_ORDER[@]}"; do
    local label="${CHECK_LABELS[$key]}"
    local info="${CHECK_DETAIL[$key]}"
    detail+="$label:\n$info\n\n"
  done
  printf '%s' "$detail"
}

DETAIL_TEXT="$(render_detail_log)"

if [[ ! -f "$TEMPLATE_PATH" ]]; then
  cat <<'TEMPLATE' > "$TEMPLATE_PATH"
# Reality Hooks Report

- PR: {{PR_NUMBER_OR_BRANCH}}
- Commit: {{GIT_SHA}}

## Checks

- Dashboard smoke: {{DASHBOARD_STATUS}}
- Orchestrator summary: {{ORCHESTRATOR_STATUS}}
- Telemetry schema check: {{TELEMETRY_STATUS}}

## Details

{{DETAIL_LOG}}

---
Generated by `tools/reality_hooks/pr_reality_check.zsh`.
TEMPLATE
fi

export TEMPLATE_PATH REPORT_FILE DETAIL_TEXT PR_IDENTIFIER
export COMMIT_SHA="$commit_sha_full"
export DASHBOARD_STATUS="${CHECK_STATUS[dashboard_smoke]}"
export ORCHESTRATOR_STATUS="${CHECK_STATUS[orchestrator_smoke]}"
export TELEMETRY_STATUS="${CHECK_STATUS[telemetry_schema]}"

python3 - <<'PY'
import os
from pathlib import Path

template_path = Path(os.environ['TEMPLATE_PATH'])
report_path = Path(os.environ['REPORT_FILE'])
content = template_path.read_text()
replacements = {
    '{{PR_NUMBER_OR_BRANCH}}': os.environ['PR_IDENTIFIER'],
    '{{GIT_SHA}}': os.environ['COMMIT_SHA'],
    '{{DASHBOARD_STATUS}}': os.environ['DASHBOARD_STATUS'],
    '{{ORCHESTRATOR_STATUS}}': os.environ['ORCHESTRATOR_STATUS'],
    '{{TELEMETRY_STATUS}}': os.environ['TELEMETRY_STATUS'],
    '{{DETAIL_LOG}}': os.environ['DETAIL_TEXT'].rstrip() or 'n/a',
}
for needle, repl in replacements.items():
    content = content.replace(needle, repl)
report_path.write_text(content)
print(f"📝 reality hooks report written to {report_path}")
PY

echo "REALITY_HOOKS_SUMMARY_START"
for key in "${CHECK_ORDER[@]}"; do
  echo "${key}=${CHECK_STATUS[$key]}"
done
echo "REALITY_HOOKS_SUMMARY_END"

if [[ $overall_rc -ne 0 ]]; then
  log "❌ One or more reality hooks failed"
else
  log "✅ All reality hooks passed"
fi

exit $overall_rc
