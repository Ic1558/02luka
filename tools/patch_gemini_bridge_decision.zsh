#!/usr/bin/env zsh
# Atomic SIP patch: Add decision_summarizer telemetry logging to gemini_bridge.py
# Strategy: Telemetry logging (least invasive, preserves core logic)
set -euo pipefail

die() { print -u2 "❌ ERROR: $*"; exit 1; }
warn() { print -u2 "⚠️  $*"; }
info() { print "ℹ️  $*"; }

REPO_ROOT="$HOME/02luka"
GB_PATH="$REPO_ROOT/gemini_bridge.py"
DS_PATH="$REPO_ROOT/decision_summarizer.py"
TELEMETRY_DIR="$REPO_ROOT/g/telemetry"
DECISION_LOG="$TELEMETRY_DIR/decision_log.jsonl"

# --- Preflight checks ---
[[ -f "$GB_PATH" ]] || die "gemini_bridge.py not found at: $GB_PATH"
[[ -f "$DS_PATH" ]] || die "decision_summarizer.py not found at: $DS_PATH"
[[ -d "$TELEMETRY_DIR" ]] || mkdir -p "$TELEMETRY_DIR"

# --- Check if already patched ---
if grep -q "02LUKA_DECISION_SUMMARIZER" "$GB_PATH" 2>/dev/null; then
    info "gemini_bridge.py already patched (markers found)"
    info "To re-patch, remove markers first or restore from backup"
    exit 0
fi

# --- Backup ---
BACKUP="${GB_PATH}.bak_decision_$(date +%s)"
cp -p "$GB_PATH" "$BACKUP"
info "Backup created: ${BACKUP/#$HOME/~}"

# --- Patch using Python (atomic, syntax-checked) ---
python3 - "$GB_PATH" "$BACKUP" "$DECISION_LOG" <<'PYPATCH'
import sys, os, tempfile, shutil, py_compile, re

gb_path = sys.argv[1]
backup = sys.argv[2]
log_path = sys.argv[3]

with open(gb_path, "r", encoding="utf-8") as f:
    orig = f.read()

# --- Insert import block after existing imports ---
IMPORT_MARK = "# >>> 02LUKA_DECISION_SUMMARIZER_IMPORT >>>"
IMPORT_BLOCK = f'''{IMPORT_MARK}
try:
    from decision_summarizer import summarize_decision, build_decision_block_for_logs
except ImportError:
    summarize_decision = None
    build_decision_block_for_logs = None
# <<< 02LUKA_DECISION_SUMMARIZER_IMPORT <<<
'''

lines = orig.splitlines(True)
import_end_idx = 0
for i, line in enumerate(lines):
    if re.match(r"^\s*(import|from)\s+", line):
        import_end_idx = i + 1

lines.insert(import_end_idx, "\n" + IMPORT_BLOCK + "\n")
patched = "".join(lines)

# --- Insert telemetry logging BEFORE empty-content check (line ~60) ---
LOG_MARK = "# >>> 02LUKA_DECISION_SUMMARIZER_LOG >>>"
LOG_BLOCK = f'''
            {LOG_MARK}
            # Log decision analysis (telemetry, non-blocking)
            if content.strip() and summarize_decision is not None:
                try:
                    decision_info = summarize_decision(content)
                    with open("{log_path}", "a", encoding="utf-8") as _log:
                        _log.write(decision_info.to_json() + "\\n")
                except Exception:
                    pass  # Silent fail, don't break bridge
            # <<< 02LUKA_DECISION_SUMMARIZER_LOG <<<
'''

# Find "if not content.strip(): return" and insert logging BEFORE it
lines2 = patched.splitlines(True)
for i, line in enumerate(lines2):
    if "if not content.strip(): return" in line:
        # Insert BEFORE the return check
        lines2.insert(i, LOG_BLOCK)
        break

patched2 = "".join(lines2)

# --- Verify markers present ---
if IMPORT_MARK not in patched2 or LOG_MARK not in patched2:
    print("PATCH_FAILED: Markers not inserted correctly", file=sys.stderr)
    sys.exit(1)

# --- Write to temp file and syntax check ---
fd, tmp = tempfile.mkstemp(prefix="gb_patch_", suffix=".py", dir=os.path.dirname(gb_path))
os.close(fd)

with open(tmp, "w", encoding="utf-8") as f:
    f.write(patched2)

try:
    py_compile.compile(tmp, doraise=True)
except Exception as e:
    print(f"SYNTAX_ERROR: {e}", file=sys.stderr)
    os.unlink(tmp)
    sys.exit(2)

# --- Atomic replace ---
os.replace(tmp, gb_path)
print("✅ Patch applied successfully")
print(f"📦 Backup: {backup}")
print(f"📊 Decision log: {log_path}")
PYPATCH

EXIT_CODE=$?

if (( EXIT_CODE == 0 )); then
    info "Patch completed successfully!"
    info "Decision summary will be logged to: ${DECISION_LOG/#$HOME/~}"
    info ""
    info "To verify: tail -f ${DECISION_LOG/#$HOME/~}"
    info "To rollback: cp ${BACKUP/#$HOME/~} ${GB_PATH/#$HOME/~}"
else
    warn "Patch failed (exit code: $EXIT_CODE)"
    if [[ -f "$BACKUP" ]]; then
        cp "$BACKUP" "$GB_PATH"
        warn "Restored from backup"
    fi
    exit $EXIT_CODE
fi
