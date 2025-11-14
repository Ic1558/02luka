# Feature PLAN: WO Pipeline v2 Rebuild (CLS-Only)

**Created:** 2025-11-14 00:00  
**Priority:** P0 (Critical)  
**Owner:** CLS (Cursor AI Agent)  
**Timeline:** 2-3 hours (single session)  
**Status:** Ready for PR Creation

---

## Executive Summary

**Problem:** WO pipeline completely broken - WOs not processed, no state files, dashboard empty.

**Solution:** Rebuild complete pipeline v2 with 7 scripts, 5 LaunchAgents, state directory, guardrail, and E2E test.

**Approach:** CLS-only implementation using provided skeletons. CLS must inspect repo for real schemas and fill execution logic.

**Deliverable:** Complete PR ready for GitHub with all files, tests passing, dashboard working.

---

## PR Template

### PR Title

```
feat(wo): rebuild WO processing pipeline v2 (CLS-only)
```

### PR One-Line Summary

```
Recreate the WO processing pipeline (processors + state writer + guardrail) so that WOs in bridge/inbox/CLC produce state files in followup/state and show up correctly in the followup dashboard.
```

### PR Description (Copy to GitHub PR Body)

```markdown
## 🎯 Goal

Rebuild the Work Order (WO) processing pipeline so that:

- WOs dropped into `bridge/inbox/CLC` are **discovered, parsed, and tracked**
- Per-WO state JSON files are written to `followup/state/`
- The existing `tools/claude_tools/generate_followup_data.zsh` script sees those state files
- The dashboard `apps/dashboard/followup.html` shows the correct WO list and status

This PR is designed to be implemented **by CLS only**, without CLC.

---

## 🧱 Scope

### New scripts (Zsh):

- `tools/wo_pipeline/lib_wo_common.zsh`
- `tools/wo_pipeline/apply_patch_processor.zsh`
- `tools/wo_pipeline/json_wo_processor.zsh`
- `tools/wo_pipeline/wo_executor.zsh`
- `tools/wo_pipeline/followup_tracker.zsh`
- `tools/wo_pipeline/wo_pipeline_guardrail.zsh`
- `tools/wo_pipeline/test_wo_pipeline_e2e.zsh`

### New directory:

- `followup/state/` (plus optional `.gitkeep`)

### LaunchAgent templates:

- `launchd/com.02luka.apply_patch_processor.plist`
- `launchd/com.02luka.json_wo_processor.plist`
- `launchd/com.02luka.wo_executor.plist`
- `launchd/com.02luka.followup_tracker.plist`
- `launchd/com.02luka.wo_pipeline_guardrail.plist`

### Documentation:

- `docs/WO_PIPELINE_V2.md`

---

## 📂 Expected Flow (v2)

```text
bridge/inbox/CLC/*.yaml / *.json   # raw WO files
              │
              ▼
tools/wo_pipeline/apply_patch_processor.zsh
  - normalizes file names
  - ensures basic metadata exists
  - writes/updates state: status = "pending"
              │
              ▼
tools/wo_pipeline/json_wo_processor.zsh
  - parses JSON/YAML WOs into a normalized structure
  - enriches state with fields like owner, category, priority, etc.
              │
              ▼
tools/wo_pipeline/wo_executor.zsh
  - actually runs the WO (or schedules other agents)
  - updates state status: "running" → "done"/"failed"
              │
              ▼
followup/state/*.json              # per-WO state files
              │
              ▼
tools/claude_tools/generate_followup_data.zsh
  - aggregates state JSON
              │
              ▼
apps/dashboard/followup.html
  - shows open/closed/failed WOs
```

**NOTE:** If `generate_followup_data.zsh` expects a specific JSON schema, adapt `lib_wo_common.zsh::write_state_json()` to match that schema instead of changing the generator script. Only adjust the generator if necessary.

---

## ✅ Checklist

### 1. State schema
- [ ] Inspect any existing sample in `followup/state/` (if git history still has them)
- [ ] If sample exists → mirror that schema exactly
- [ ] If no samples → define a minimal, documented schema and (only if needed) update `generate_followup_data.zsh` to consume it

### 2. Common library
- [ ] Implement `tools/wo_pipeline/lib_wo_common.zsh`:
  - [ ] `resolve_repo_root`
  - [ ] `log_info`, `log_warn`, `log_error`
  - [ ] `ensure_dir`
  - [ ] `normalize_wo_id`
  - [ ] `write_state_json`
  - [ ] `update_state_field`
  - [ ] `mark_status` (pending, running, done, failed)

### 3. Processors
- [ ] `apply_patch_processor.zsh`:
  - [ ] Finds new WOs in `bridge/inbox/CLC/`
  - [ ] Creates initial state JSON (status=pending)
  - [ ] Adds minimal metadata from filename / WO body
- [ ] `json_wo_processor.zsh`:
  - [ ] Parses YAML/JSON
  - [ ] Extracts structured fields (id, title, owner, category, priority,…)
  - [ ] Updates the corresponding state JSON
- [ ] `wo_executor.zsh`:
  - [ ] Reads normalized WOs
  - [ ] Executes or delegates actual work (may be stubbed for now, but must update state)
  - [ ] Updates status + last_error (if failed) + updated_at
- [ ] `followup_tracker.zsh`:
  - [ ] Periodically scans `followup/state/` for stale entries
  - [ ] Optionally adds derived fields (age, is_stale, etc.)

### 4. Guardrail
- [ ] `wo_pipeline_guardrail.zsh`:
  - [ ] Verifies that all critical scripts exist
  - [ ] Verifies that `followup/state/` exists and is writable
  - [ ] Emits a simple health JSON or log line (e.g. stdout / telemetry)
  - [ ] Exits non-zero if the pipeline is broken

### 5. Launchd templates
- [ ] Add `launchd/*.plist` pointing to the installed scripts under `/Users/icmini/02luka/g/tools/wo_pipeline/`
- [ ] Use absolute paths only
- [ ] Do not load/unload automatically from within scripts; keep these as templates only

### 6. Tests
- [ ] Implement `tools/wo_pipeline/test_wo_pipeline_e2e.zsh`:
  - [ ] Creates a temporary WO in `bridge/inbox/CLC/`
  - [ ] Runs processors in a deterministic order
  - [ ] Asserts that a state JSON is created and contains expected fields
  - [ ] Returns exit 0 only on success

### 7. Docs
- [ ] `docs/WO_PIPELINE_V2.md`:
  - [ ] Document the flow
  - [ ] Document the state JSON schema
  - [ ] Document how to run the E2E test
  - [ ] Document how to install LaunchAgents (manual steps)

---

## 🧪 Acceptance Criteria

- [ ] Dropping a valid WO file into `bridge/inbox/CLC/` and running the processors manually results in:
  - [ ] At least one new file in `followup/state/`
  - [ ] `tools/claude_tools/generate_followup_data.zsh` succeeds
  - [ ] The dashboard shows a non-empty list of WOs
- [ ] Guardrail script exits 0 in the healthy case and non-zero if any critical script or directory is missing.
- [ ] All scripts are `#!/usr/bin/env zsh` and do not rely on non-existent tools or paths.

---

## Implementation Tasks

### Task 1: Inspect Existing State Schema (15 min)

**Goal:** Find real state JSON schema from git history or existing files

**Steps:**
1. Search git history for `followup/state/*.json`:
   ```bash
   git log --all --full-history --follow -- "**/followup/state/*.json"
   git show <commit>:g/followup/state/*.json 2>/dev/null | head -50
   ```

2. Check if any state files exist:
   ```bash
   find ~/02luka/g/followup/state -name "*.json" 2>/dev/null | head -1 | xargs cat
   ```

3. Inspect `generate_followup_data.zsh` to see what schema it expects:
   ```bash
   cat ~/02luka/g/tools/claude_tools/generate_followup_data.zsh | grep -A20 "state\|json"
   ```

4. Document findings in `lib_wo_common.zsh` comments

**Deliverable:** Schema decision documented

---

### Task 2: Implement Common Library (20 min)

**File:** `tools/wo_pipeline/lib_wo_common.zsh`

**Skeleton provided below - CLS fills based on schema findings:**

```zsh
#!/usr/bin/env zsh
# tools/wo_pipeline/lib_wo_common.zsh

set -euo pipefail

# Resolve repo root from this script's location: /Users/icmini/02luka/g/tools/wo_pipeline
resolve_repo_root() {
  local script_dir repo_root
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  repo_root="$(cd "$script_dir/../.." && pwd)"
  echo "$repo_root"
}

log_info()  { echo "[INFO]  $*" >&2 }
log_warn()  { echo "[WARN]  $*" >&2 }
log_error() { echo "[ERROR] $*" >&2 }

ensure_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || mkdir -p "$dir"
}

# Normalize WO id from filename (CLS: adjust pattern to real naming)
normalize_wo_id() {
  local filename="$1"
  local base="${filename:t}"
  # Strip extension(s)
  base="${base%.*}"
  echo "$base"
}

# CLS: inspect existing or historical state JSON to copy the exact schema.
# This is a safe default if nothing exists.
write_state_json() {
  local state_file="$1"
  local wo_id="$2"
  local status="$3"
  local title="${4:-""}"
  local owner="${5:-""}"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  cat > "$state_file" <<EOF
{
  "id": "$(echo "$wo_id" | sed 's/"/\\"/g')",
  "title": "$(echo "$title" | sed 's/"/\\"/g')",
  "owner": "$(echo "$owner" | sed 's/"/\\"/g')",
  "status": "$status",
  "created_at": "$now",
  "updated_at": "$now",
  "last_error": "",
  "meta": {}
}
EOF
}

update_state_field() {
  local state_file="$1"
  local field="$2"
  local value="$3"

  # CLS: Replace with jq if available and allowed in this repo.
  # For now, a simple `python3 -c` patch is safer and aligns with SIP patterns.
  python3 - "$state_file" "$field" "$value" <<'PY'
import json, sys, pathlib, datetime

path = pathlib.Path(sys.argv[1])
field = sys.argv[2]
value = sys.argv[3]

data = {}
if path.exists():
    data = json.loads(path.read_text(encoding="utf-8"))

data[field] = value
data["updated_at"] = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
PY
}

mark_status() {
  local state_file="$1"
  local status="$2"
  update_state_field "$state_file" "status" "$status"
}
```

**TODO for CLS:**
- If historical schema found → update `write_state_json()` to match exactly
- Verify schema compatibility with `generate_followup_data.zsh`

---

### Task 3: Implement apply_patch_processor.zsh (15 min)

**File:** `tools/wo_pipeline/apply_patch_processor.zsh`

```zsh
#!/usr/bin/env zsh
# tools/wo_pipeline/apply_patch_processor.zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib_wo_common.zsh"

INBOX_DIR="$REPO_ROOT/bridge/inbox/CLC"
STATE_DIR="$REPO_ROOT/followup/state"

main() {
  ensure_dir "$INBOX_DIR"
  ensure_dir "$STATE_DIR"

  log_info "Scanning inbox: $INBOX_DIR"

  local f
  local found_any=0

  for f in "$INBOX_DIR"/*(.N); do
    case "$f" in
      *.yaml|*.yml|*.json) ;;
      *) continue ;;
    esac

    found_any=1

    local wo_id state_file
    wo_id="$(normalize_wo_id "$f")"
    state_file="$STATE_DIR/$wo_id.json"

    if [[ -f "$state_file" ]]; then
      log_info "State already exists for $wo_id → skipping create"
      continue
    fi

    log_info "Creating initial state for $wo_id"
    write_state_json "$state_file" "$wo_id" "pending" "" ""
  done

  if [[ "$found_any" -eq 0 ]]; then
    log_info "No WO files found in inbox"
  fi
}

main "$@"
```

**Verification:**
```bash
cd ~/02luka/g
./tools/wo_pipeline/apply_patch_processor.zsh
ls -lh followup/state/
```

---

### Task 4: Implement json_wo_processor.zsh (25 min)

**File:** `tools/wo_pipeline/json_wo_processor.zsh`

```zsh
#!/usr/bin/env zsh
# tools/wo_pipeline/json_wo_processor.zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib_wo_common.zsh"

INBOX_DIR="$REPO_ROOT/bridge/inbox/CLC"
STATE_DIR="$REPO_ROOT/followup/state"

# CLS: Implement a helper to parse YAML/JSON with python3
parse_wo() {
  local path="$1"
  python3 - "$path" <<'PY'
import sys, json, pathlib

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

# Very simple heuristic: if starts with { → JSON, else assume YAML
if text.lstrip().startswith("{"):
    data = json.loads(text)
else:
    import yaml  # CLS: ensure PyYAML is allowed, otherwise replace with a minimal parser
    data = yaml.safe_load(text)

# Normalize a few fields. Adjust keys to your real WO schema.
out = {
    "id": data.get("id") or data.get("wo_id") or path.stem,
    "title": data.get("title") or data.get("summary") or path.stem,
    "owner": data.get("owner") or data.get("assignee") or "",
    "category": data.get("category") or data.get("type") or "",
    "priority": data.get("priority") or "normal",
}
print(json.dumps(out))
PY
}

main() {
  ensure_dir "$INBOX_DIR"
  ensure_dir "$STATE_DIR"

  local f
  for f in "$INBOX_DIR"/*(.N); do
    case "$f" in
      *.yaml|*.yml|*.json) ;;
      *) continue ;;
    esac

    local meta_json
    meta_json="$(parse_wo "$f")" || {
      log_warn "Failed to parse WO: $f"
      continue
    }

    local wo_id state_file
    wo_id="$(normalize_wo_id "$f")"
    state_file="$STATE_DIR/$wo_id.json"

    # Ensure base state exists
    [[ -f "$state_file" ]] || write_state_json "$state_file" "$wo_id" "pending" "" ""

    # Update some fields
    python3 - "$state_file" "$meta_json" <<'PY'
import json, sys, pathlib, datetime

state_path = pathlib.Path(sys.argv[1])
meta = json.loads(sys.argv[2])

data = {}
if state_path.exists():
    data = json.loads(state_path.read_text(encoding="utf-8"))

data.update(meta)
data["updated_at"] = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

state_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
PY
  done
}

main "$@"
```

**TODO for CLS:**
- Inspect real WO files in `bridge/inbox/CLC/` to match schema
- Adjust field extraction to match real WO structure
- Handle YAML parsing (ensure PyYAML available or use minimal parser)

---

### Task 5: Implement wo_executor.zsh (30 min)

**File:** `tools/wo_pipeline/wo_executor.zsh`

```zsh
#!/usr/bin/env zsh
# tools/wo_pipeline/wo_executor.zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib_wo_common.zsh"

STATE_DIR="$REPO_ROOT/followup/state"

main() {
  ensure_dir "$STATE_DIR"

  local s
  for s in "$STATE_DIR"/*.json(.N); do
    local status
    status="$(python3 - "$s" <<'PY'
import json, sys
import pathlib

p = pathlib.Path(sys.argv[1])
data = json.loads(p.read_text(encoding="utf-8"))
print(data.get("status",""))
PY
"$s")"

    case "$status" in
      pending) ;;
      *) continue ;;
    esac

    log_info "Executing WO for state file: $s"
    mark_status "$s" "running"

    # CLS: Implement actual execution logic here (for now, stub as success)
    local ok=0

    if [[ "$ok" -eq 0 ]]; then
      mark_status "$s" "done"
    else
      mark_status "$s" "failed"
      update_state_field "$s" "last_error" "executor stub failed"
    fi
  done
}

main "$@"
```

**TODO for CLS:**
- Replace stub `ok=0` with real execution logic
- Inspect WO schema to determine execution pattern
- Route by category or executor field if present
- Handle errors and update `last_error` field

---

### Task 6: Implement followup_tracker.zsh (15 min)

**File:** `tools/wo_pipeline/followup_tracker.zsh`

```zsh
#!/usr/bin/env zsh
# tools/wo_pipeline/followup_tracker.zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib_wo_common.zsh"

STATE_DIR="$REPO_ROOT/followup/state"

main() {
  ensure_dir "$STATE_DIR"
  # CLS: Optionally mark stale items, compute age, etc.
  # This script can be very simple initially.
  log_info "followup_tracker: scanning state dir: $STATE_DIR"
}

main "$@"
```

**TODO for CLS:**
- Add stale detection logic if needed
- Compute age fields
- Add derived fields to state JSON

---

### Task 7: Implement wo_pipeline_guardrail.zsh (15 min)

**File:** `tools/wo_pipeline/wo_pipeline_guardrail.zsh`

```zsh
#!/usr/bin/env zsh
# tools/wo_pipeline/wo_pipeline_guardrail.zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib_wo_common.zsh"

check_file() {
  local path="$1"
  [[ -f "$path" ]] || { log_error "Missing critical file: $path"; return 1; }
}

main() {
  local rc=0

  check_file "$REPO_ROOT/tools/wo_pipeline/lib_wo_common.zsh" || rc=1
  check_file "$REPO_ROOT/tools/wo_pipeline/apply_patch_processor.zsh" || rc=1
  check_file "$REPO_ROOT/tools/wo_pipeline/json_wo_processor.zsh" || rc=1
  check_file "$REPO_ROOT/tools/wo_pipeline/wo_executor.zsh" || rc=1

  if [[ ! -d "$REPO_ROOT/followup/state" ]]; then
    log_error "Missing state dir: $REPO_ROOT/followup/state"
    rc=1
  fi

  exit "$rc"
}

main "$@"
```

**Verification:**
```bash
cd ~/02luka/g
./tools/wo_pipeline/wo_pipeline_guardrail.zsh
echo $?  # Should be 0
```

---

### Task 8: Implement test_wo_pipeline_e2e.zsh (20 min)

**File:** `tools/wo_pipeline/test_wo_pipeline_e2e.zsh`

```zsh
#!/usr/bin/env zsh
# tools/wo_pipeline/test_wo_pipeline_e2e.zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

INBOX_DIR="$REPO_ROOT/bridge/inbox/CLC"
STATE_DIR="$REPO_ROOT/followup/state"

main() {
  mkdir -p "$INBOX_DIR" "$STATE_DIR"

  local tmp_wo="$INBOX_DIR/WO-TEST-PIPELINE-E2E.yaml"
  cat > "$tmp_wo" <<EOF
id: WO-TEST-PIPELINE-E2E
title: "E2E test WO"
owner: "test"
priority: "normal"
category: "test"
EOF

  "$REPO_ROOT/tools/wo_pipeline/apply_patch_processor.zsh"
  "$REPO_ROOT/tools/wo_pipeline/json_wo_processor.zsh"
  "$REPO_ROOT/tools/wo_pipeline/wo_executor.zsh"

  local state_file="$STATE_DIR/WO-TEST-PIPELINE-E2E.json"
  if [[ ! -f "$state_file" ]]; then
    echo "State file not created: $state_file" >&2
    exit 1
  fi

  local status
  status="$(python3 - "$state_file" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1])
data = json.loads(p.read_text(encoding="utf-8"))
print(data.get("status",""))
PY
"$state_file")"

  if [[ "$status" != "done" ]]; then
    echo "Unexpected status in state file: $status" >&2
    exit 1
  fi

  echo "E2E test PASSED"
}

main "$@"
```

**Verification:**
```bash
cd ~/02luka/g
./tools/wo_pipeline/test_wo_pipeline_e2e.zsh
# Should output: "E2E test PASSED"
```

---

### Task 9: Create LaunchAgent Templates (20 min)

**Pattern for all 5 plists:**

**File:** `launchd/com.02luka.apply_patch_processor.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.02luka.apply_patch_processor</string>

  <key>ProgramArguments</key>
  <array>
    <string>/Users/icmini/02luka/g/tools/wo_pipeline/apply_patch_processor.zsh</string>
  </array>

  <key>StartInterval</key>
  <integer>60</integer>

  <key>StandardOutPath</key>
  <string>/Users/icmini/02luka/logs/wo_pipeline/apply_patch_processor.out.log</string>

  <key>StandardErrorPath</key>
  <string>/Users/icmini/02luka/logs/wo_pipeline/apply_patch_processor.err.log</string>
</dict>
</plist>
```

**Repeat for:**
- `com.02luka.json_wo_processor.plist`
- `com.02luka.wo_executor.plist`
- `com.02luka.followup_tracker.plist`
- `com.02luka.wo_pipeline_guardrail.plist`

**Change only:**
- `Label` value
- `ProgramArguments` script name
- Log file names

---

### Task 10: Create Documentation (20 min)

**File:** `docs/WO_PIPELINE_V2.md`

**Contents:**
- Pipeline flow diagram
- State JSON schema (documented)
- How to run E2E test
- How to install LaunchAgents (manual steps)
- Troubleshooting guide

---

### Task 11: Integration Testing (30 min)

**Steps:**
1. Run E2E test:
   ```bash
   cd ~/02luka/g
   ./tools/wo_pipeline/test_wo_pipeline_e2e.zsh
   ```

2. Test with real WO:
   ```bash
   # Drop a real WO into inbox
   cp some_real_wo.yaml ~/02luka/g/bridge/inbox/CLC/
   
   # Run processors
   ./tools/wo_pipeline/apply_patch_processor.zsh
   ./tools/wo_pipeline/json_wo_processor.zsh
   ./tools/wo_pipeline/wo_executor.zsh
   
   # Verify state created
   ls -lh followup/state/
   ```

3. Test dashboard integration:
   ```bash
   ./tools/claude_tools/generate_followup_data.zsh
   # Open dashboard and verify WO appears
   ```

4. Test guardrail:
   ```bash
   ./tools/wo_pipeline/wo_pipeline_guardrail.zsh
   echo $?  # Should be 0
   ```

---

## Test Strategy

### Unit Tests

**Test 1: Common Library Functions**
- `resolve_repo_root()` returns correct path
- `normalize_wo_id()` extracts ID correctly
- `write_state_json()` creates valid JSON
- `update_state_field()` updates correctly

**Test 2: Processors**
- `apply_patch_processor.zsh` creates state for new WOs
- `json_wo_processor.zsh` parses YAML/JSON correctly
- `wo_executor.zsh` updates status correctly

### Integration Tests

**Test 3: E2E Pipeline**
- Drop test WO → All processors run → State created → Status = "done"

**Test 4: Dashboard Integration**
- State files → `generate_followup_data.zsh` → Dashboard shows WOs

### Acceptance Tests

**Test 5: Guardrail**
- Healthy case: exit 0
- Missing script: exit non-zero
- Missing directory: exit non-zero

---

## Timeline

**Total Time:** 2.5-3 hours

| Task | Time | Dependencies |
|------|------|--------------|
| 1. Inspect schema | 15 min | None |
| 2. Common library | 20 min | Task 1 |
| 3. apply_patch_processor | 15 min | Task 2 |
| 4. json_wo_processor | 25 min | Task 2 |
| 5. wo_executor | 30 min | Task 2 |
| 6. followup_tracker | 15 min | Task 2 |
| 7. guardrail | 15 min | Task 2 |
| 8. E2E test | 20 min | Tasks 3-5 |
| 9. LaunchAgents | 20 min | Tasks 3-7 |
| 10. Documentation | 20 min | All tasks |
| 11. Integration test | 30 min | All tasks |

---

## Success Metrics

### Functional

✅ **E2E Test Passes:**
- Test WO → State created → Status = "done"

✅ **Real WO Processing:**
- Drop real WO → Processors run → State created → Dashboard shows WO

✅ **Guardrail Works:**
- Healthy: exit 0
- Broken: exit non-zero

### Technical

✅ **All scripts executable**
✅ **No hardcoded paths**
✅ **State schema matches dashboard**
✅ **LaunchAgent templates valid**

---

## Rollback Plan

```bash
# Revert PR
git revert <pr-commit>

# Remove LaunchAgents
launchctl unload ~/Library/LaunchAgents/com.02luka.*.plist
rm ~/Library/LaunchAgents/com.02luka.*.plist

# Remove scripts (move directory to trash, never run destructive shell commands)
# - ~/02luka/g/tools/wo_pipeline/

# Clear state (trash the JSON files after backups)
# - ~/02luka/g/followup/state/*.json
```

---

## Next Steps

1. **CLS Implementation:**
   - Copy PR description to GitHub PR
   - Implement all tasks in order
   - Run integration tests
   - Open PR

2. **Boss Review:**
   - Review PR
   - Test locally if needed
   - Approve and merge

3. **Post-Merge:**
   - Install LaunchAgents manually
   - Monitor guardrail
   - Verify dashboard shows WOs

---

**Ready for CLS Implementation:** ✅  
**PR Template:** Complete  
**Skeleton Code:** Provided  
**Timeline:** 2.5-3 hours

<!-- Sanitized for Codex Sandbox Mode (2025-11) -->
