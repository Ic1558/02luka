# Telemetry Aggregation System - Implementation Plan

**Feature:** Telemetry Aggregation System  
**Spec:** [251206_telemetry_aggregation_SPEC_v01.md](file:///Users/icmini/02luka/g/reports/feature-dev/telemetry_aggregation/251206_telemetry_aggregation_SPEC_v01.md)  
**Date:** 2025-12-06 (Restored 2025-12-07)

---

## Phased Approach

### Phase 1: CLI Tool (1.5 hours) ✅

**Create:** `g/tools/telemetry_summary.py`

```
Functions:
- read_audit_files() - Parse all *_audit.jsonl
- filter_by_time() - Time range filtering
- generate_summary() - Aggregate metrics
- format_output() - Console/JSON/JSONL output
```

**Usage:**
```bash
python3 g/tools/telemetry_summary.py --last 30min
python3 g/tools/telemetry_summary.py --agent liam --format json
```

---

### Phase 2: Automation (1 hour) ✅

**Create:**
1. `tools/telemetry_aggregator.zsh` - Wrapper script
2. `Library/LaunchAgents/com.02luka.telemetry-aggregator.plist`

**Automation:**
- Runs every 30 minutes
- Outputs to `g/telemetry/summaries/`
- Logs to `logs/telemetry_aggregator.log`

---

### Phase 3: LAC Integration (Future)

**Add to LAC ecosystem:**
- Docs Agent can query summaries
- Dashboard integration
- Alert on anomalies

---

## File Locations

| Component | Path |
|-----------|------|
| CLI Tool | `g/tools/telemetry_summary.py` |
| Wrapper | `tools/telemetry_aggregator.zsh` |
| LaunchAgent | `Library/LaunchAgents/com.02luka.telemetry-aggregator.plist` |
| Summaries | `g/telemetry/summaries/summary_*.jsonl` |
| Logs | `logs/telemetry_aggregator.log` |

---

## Verification Commands

```bash
# Check automation
launchctl list | grep telemetry-aggregator

# View status
launchctl print gui/$(id -u)/com.02luka.telemetry-aggregator

# Force run
launchctl kickstart gui/$(id -u)/com.02luka.telemetry-aggregator

# Check output
ls -la ~/02luka/g/telemetry/summaries/
tail -20 ~/02luka/logs/telemetry_aggregator.log
```

---

## Status

- [x] Phase 1: CLI Tool ✅
- [x] Phase 2: Automation ✅
- [ ] Phase 3: LAC Integration (Future)

**Production Ready:** ✅

---

**Restored from:** liam_251206.md chat archive
