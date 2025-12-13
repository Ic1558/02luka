# System Truth Sync P0 — Read-Only Snapshot Tool

**Date:** 2025-12-10  
**Status:** ✅ IMPLEMENTED (P0 Complete)  
**Work Order:** WO-20251113-SYSTEM-TRUTH-SYNC  
**Priority:** P0 (Sandbox-Safe, Read-Only)

---

## 🎯 Core Principle

**Read-Only System Truth Snapshot:**
- No writes to `02luka.md` or any documentation files
- Reads from allowlisted paths only
- Generates JSON summary + Markdown block for manual paste
- Sandbox-safe (no side effects)

---

## 📋 Requirements

### Functional Requirements

1. **Read Sandbox Health Reports**
   - Source: `g/sandbox/os_l0_l1/logs/liam_reports/health_*.json`
   - Extract: latest status, message, timestamp
   - Handle: missing files, parse errors gracefully

2. **Read Gateway v3 Telemetry**
   - Source: `g/telemetry/gateway_v3_router.jsonl`
   - Extract: latest event, total count, status
   - Handle: missing file, malformed JSONL

3. **Read Key Work Orders**
   - Source: `bridge/outbox/CLC/WO-*.yaml`
   - Focus: 6 key WOs (see list below)
   - Extract: status, priority, owner, title
   - Handle: missing files, YAML parse errors

4. **Generate Output**
   - JSON summary (structured data)
   - Markdown block (ready for paste into `02luka.md`)
   - Clear markers: `<!-- SYSTEM_TRUTH_SYNC_P0_START -->` ... `<!-- SYSTEM_TRUTH_SYNC_P0_END -->`

### Non-Functional Requirements

1. **Safety (P0)**
   - ✅ No file writes (read-only)
   - ✅ Path validation (safe_under check)
   - ✅ Graceful error handling
   - ✅ No dependencies on external services

2. **Performance**
   - Fast execution (< 1 second)
   - Limit JSONL tail reading (2000 lines max)
   - Efficient file globbing

3. **Usability**
   - CLI flags: `--json`, `--md`, `--mode`
   - Default: both JSON + Markdown
   - Clear error messages

---

## 🔧 Technical Specification

### Data Models

```python
@dataclass
class SandboxStatus:
    status: str  # "GREEN" | "RED" | "UNKNOWN"
    message: str
    latest_report: Optional[str]
    report_ts: Optional[str]

@dataclass
class GatewayStatus:
    telemetry_file: Optional[str]
    latest_event_ts: Optional[str]
    latest_level: Optional[str]
    latest_message: Optional[str]
    total_events: int

@dataclass
class WorkOrderStatus:
    id: str
    path: str
    status: Optional[str]
    priority: Optional[str]
    owner: Optional[str]
    title: Optional[str]
```

### Key Work Orders Tracked

1. `WO-20251113-SYSTEM-TRUTH-SYNC.yaml`
2. `WO-20251206-GATEWAY-V3-CORE.yaml`
3. `WO-20251206-SANDBOX-FIX-V1.yaml`
4. `WO-20251206-LOCAL-AGENT-REVIEW-PHASE1.yaml`
5. `WO-TEST-GATEWAY-V3.yaml`
6. `WO-20251206-LAR-GITDROP-SAVECHAIN-V1.yaml`

### CLI Interface

```bash
# Full output (JSON + Markdown)
python g/tools/system_truth_sync_p0.py

# JSON only
python g/tools/system_truth_sync_p0.py --json

# Markdown only
python g/tools/system_truth_sync_p0.py --md

# Mode selection (future use)
python g/tools/system_truth_sync_p0.py --mode core --md
```

---

## ✅ Acceptance Criteria

- [x] Script reads sandbox health reports correctly
- [x] Script reads gateway telemetry correctly
- [x] Script reads work order statuses correctly
- [x] JSON output is valid and structured
- [x] Markdown block has clear markers
- [x] No file writes (read-only verified)
- [x] Path validation prevents directory traversal
- [x] Graceful error handling for missing files
- [x] CLI flags work as specified

---

## 🚀 Implementation Status

**Status:** ✅ **COMPLETE**

**File:** `/Users/icmini/02luka/g/tools/system_truth_sync_p0.py`

**Test Results:**
- ✅ Markdown output: Valid format with markers
- ✅ JSON output: Valid structure
- ✅ Sandbox status: Correctly reads latest health report
- ✅ Gateway status: Correctly reads telemetry
- ✅ Work orders: Correctly extracts status from YAML

**Next Steps (P1):**
- Design writer flow (CLC/pipeline) to update `02luka.md` automatically
- Consider scheduled execution (LaunchAgent)
- Add more data sources (agents, queues, etc.)

---

## 📝 Usage Examples

### Example 1: Generate Markdown for Manual Paste

```bash
cd ~/02luka
python g/tools/system_truth_sync_p0.py --md > /tmp/snapshot.md
# Then manually paste into 02luka.md
```

### Example 2: JSON for Automation

```bash
python g/tools/system_truth_sync_p0.py --json | jq '.sandbox.status'
# Output: "RED"
```

### Example 3: Full Output

```bash
python g/tools/system_truth_sync_p0.py
# Outputs both JSON and Markdown (separated)
```

---

## 🔒 Security Considerations

1. **Path Safety**
   - All paths validated with `safe_under()` check
   - No directory traversal possible
   - Only allowlisted paths accessed

2. **Read-Only**
   - No file writes in P0
   - No network calls
   - No subprocess execution

3. **Error Handling**
   - All file operations wrapped in try/except
   - Graceful degradation (UNKNOWN status)
   - No sensitive data exposure in errors

---

## 📚 Related Documents

- Work Order: `bridge/outbox/CLC/WO-20251113-SYSTEM-TRUTH-SYNC.yaml`
- Gateway v3: `g/reports/gateway_v3_phase0_implementation_complete_20251206.md`
- Sandbox Health: `g/sandbox/os_l0_l1/tools/healthcheck.zsh`


