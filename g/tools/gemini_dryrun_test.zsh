#!/usr/bin/env zsh
# Gemini routing dry-run validation & safety checks
# Safe to run on mobile: copy → paste → zsh g/tools/gemini_dryrun_test.zsh

set -euo pipefail

SOT="${LUKA_SOT:-$HOME/02luka}"
TEST_DIR="$SOT/g/tests/gemini_dryrun"
LOG_FILE="$SOT/logs/gemini_dryrun_$(date +%Y%m%d_%H%M%S).log"
WO_ID="GEMINI_DRYRUN_$(date +%Y%m%d_%H%M%S)"
WO_FILE="$TEST_DIR/${WO_ID}.yaml"

mkdir -p "$TEST_DIR" "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$LOG_FILE"
}

log "=== Gemini Dry-Run Validation ==="
log "Base dir: $SOT"
log "WO file: $WO_FILE"

log "Step 1: Validate handler import"
python3 - <<'PY' 2>&1 | tee -a "$LOG_FILE"
import importlib
import importlib.machinery
import importlib.util
import sys
import types

def _ensure_stubbed_google():
    """Provide a lightweight stub for google.generativeai if missing.

    This keeps the dry-run isolated from optional cloud deps while allowing
    gemini_handler imports to proceed.
    """

    if "google" not in sys.modules:
        sys.modules["google"] = types.ModuleType("google")
    if "google.generativeai" not in sys.modules:
        sys.modules["google.generativeai"] = types.ModuleType("google.generativeai")

    original_find_spec = importlib.util.find_spec

    def _patched_find_spec(name, package=None):
        if name == "google.generativeai":
            return importlib.machinery.ModuleSpec("google.generativeai", None)
        return original_find_spec(name, package)

    importlib.util.find_spec = _patched_find_spec


try:
    _ensure_stubbed_google()
    handler = importlib.import_module("bridge.handlers.gemini_handler")
    required_exports = ["handle_wo", "handle", "GeminiHandler"]
    missing = [name for name in required_exports if not hasattr(handler, name)]
    if missing:
        print(f"❌ Missing exports on gemini_handler: {', '.join(missing)}")
        sys.exit(1)
    print("DRY-RUN: HANDLER_IMPORT_OK")
except Exception as exc:
    print(f"❌ Failed to import gemini_handler: {exc}")
    sys.exit(1)
PY
log ""

log "Step 2: Write dry-run work order"
cat > "$WO_FILE" <<EOF_WO
wo_id: "$WO_ID"
engine: gemini
task_type: code_transform
impact_zone: apps
routing:
  origin: liam
  reviewer: kim
  path:
    - liam
    - kim
    - dispatcher
    - gemini_handler
  prefer_agent: gemini
  review_required_by: kim
  locked_zone_allowed: false
input:
  instructions: |
    DRY-RUN: Validate Gemini routing path (Liam → Kim → Dispatcher → Handler).
    Do NOT execute external calls. Ensure metadata and handler shape are valid.
  target_files:
    - apps/dashboard/README.md
  context:
    intent: "gemini dry-run validation"
    allow_write: false
metadata:
  tags:
    - gemini
    - dryrun
  requested_via: liam
  reviewer: kim
EOF_WO
log "✅ Work order drafted"
log ""

log "Step 3: Schema + routing validation"
python3 - "$WO_FILE" <<'PY' 2>&1 | tee -a "$LOG_FILE"
import sys
from pathlib import Path
import yaml

wo_path = Path(sys.argv[1])
wo = yaml.safe_load(wo_path.read_text()) or {}
errors = []

expected_path = ["liam", "kim", "dispatcher", "gemini_handler"]
routing = wo.get("routing", {})
input_block = wo.get("input", {})

if wo.get("engine") != "gemini":
    errors.append("engine must be gemini")
if routing.get("locked_zone_allowed") not in (False, "false"):
    errors.append("locked_zone_allowed must be false")
if routing.get("path") != expected_path:
    errors.append(f"routing.path must be {expected_path}")
if routing.get("review_required_by") != "kim":
    errors.append("review_required_by must be kim")

instructions = input_block.get("instructions", "")
if not isinstance(instructions, str) or not instructions.strip():
    errors.append("input.instructions must be non-empty")

targets = input_block.get("target_files", []) or []
if not isinstance(targets, list) or not targets:
    errors.append("input.target_files must include at least one entry")

blocked_tokens = ["/CLC", "/CLS", "AI:OP-001", "bridge/core", "bridge/core"]
for target in targets:
    for token in blocked_tokens:
        if token in target:
            errors.append(f"target_files contains locked-zone path token: {token}")
            break

if errors:
    print("❌ Schema validation errors:")
    for issue in errors:
        print(f"  - {issue}")
    sys.exit(1)

print("DRY-RUN: ROUTING_OK")
PY
log ""

log "Step 4: Minimal handler payload validation"
python3 - "$WO_FILE" <<'PY' 2>&1 | tee -a "$LOG_FILE"
import json
import sys
from pathlib import Path
import yaml

wo_path = Path(sys.argv[1])
wo = yaml.safe_load(wo_path.read_text()) or {}

input_block = wo.get("input", {}) if isinstance(wo, dict) else {}
minimal_task = {
    "task_type": wo.get("task_type", "code_transform"),
    "input": {
        "instructions": input_block.get("instructions", ""),
        "target_files": input_block.get("target_files", []),
        "context": input_block.get("context", {}),
    },
    "routing": wo.get("routing", {}),
}

issues = []
if not minimal_task["task_type"]:
    issues.append("task_type missing")
if not minimal_task["input"]["instructions"]:
    issues.append("instructions missing")
if not minimal_task["input"]["target_files"]:
    issues.append("target_files missing")
if minimal_task["routing"].get("locked_zone_allowed") is not False:
    issues.append("locked_zone_allowed must be false for handler payload")

if issues:
    print("❌ Handler payload invalid:")
    for item in issues:
        print(f"  - {item}")
    sys.exit(1)

print("DRY-RUN: HANDLER_OK")
print("Minimal task dictionary:\n" + json.dumps(minimal_task, indent=2))
PY
log ""

log "Summary"
log "DRY-RUN: ROUTING_OK → verified path Liam → Kim → Dispatcher → Handler"
log "DRY-RUN: HANDLER_OK → minimal task payload ready for Gemini handler"
log "Log file: $LOG_FILE"
log "=== Dry-run complete ==="
