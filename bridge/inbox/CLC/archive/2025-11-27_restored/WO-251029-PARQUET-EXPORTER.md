## 🧠 WORK ORDER: WO-251029-PARQUET-EXPORTER
**Phase:** 7.8 – Data Analytics Integration  
**Origin:** GG Orchestrator  
**Assigned To:** CLC (Claude Code)  
**Priority:** P1 – Core Analytics Enablement  
**Created:** 2025-10-28  

### 🎯 Objective
Implement a robust Parquet data exporter and DuckDB bridge for OPS-Atomic telemetry.  
This enables fast local analytics and compressed archiving of system reports.

---

### 🧩 Requirements

1. **Create module:** `run/parquet_exporter.cjs`  
   - Read all `.md` reports in `~/02luka/g/reports/`  
   - Convert to structured JSON → Parquet using DuckDB or Arrow  
   - Output: `~/02luka/g/analytics/ops_atomic_YYYYMMDD.parquet`  
   - Compress with `snappy`  

2. **Create control scripts:**  
   - `scripts/analytics/run_parquet_exporter.sh` – one-shot runner  
   - `scripts/analytics/test_parquet_exporter.sh` – integrity test (count rows, size)  

3. **Create LaunchAgent:**  
   - Label: `com.02luka.analytics.parquet`  
   - Schedule: 02:30 daily (after ops_atomic_daily 02:00)  
   - WorkingDirectory: `~/02luka`  
   - StandardOutPath / StandardErrorPath → `g/logs/parquet_exporter.log`  

4. **Add summary report generator:**  
   - `g/reports/parquet/parquet_export_summary_YYYYMMDD.md`  
   - Include row count, file size, export duration, success status  

5. **Validation:**  
   - Dry-run mode (`--dry`)  
   - Verify DuckDB table schema matches telemetry JSON keys  
   - Idempotent reruns (overwrite same date file safely)

---

### 🧮 Acceptance Criteria
| Metric | Target |
|---------|--------|
| Export frequency | 1× daily (02:30) |
| Compression | Snappy |
| File size | ≤ 5 MB/day |
| Validation time | < 2 s |
| Schema mismatch | 0 errors |
| LaunchAgent | loads & runs automatically |

---

### 🧱 Dependencies
- Phase 7.7 Monitoring: ✅ complete  
- Redis Auth: ✅ fixed  
- Loop Monitor: ✅ verified  
- DuckDB lib: install via `npm i duckdb` if not present  

---

### 🧩 Deliverables
1. `run/parquet_exporter.cjs`
2. `scripts/analytics/run_parquet_exporter.sh`
3. `scripts/analytics/test_parquet_exporter.sh`
4. `LaunchAgents/com.02luka.analytics.parquet.plist`
5. `g/reports/parquet_export_summary_YYYYMMDD.md`

---

### 🧾 Verification
After deployment:
```bash
launchctl list | grep parquet
ls -lh ~/02luka/g/analytics/*.parquet
```

⸻

Next Phase (after 24 h of data):
WO-251030-GRAFANA-BRIDGE – connect DuckDB + Grafana for live dashboards.

Authorization: GG (Main Orchestrator)
Ready for Execution by: CLC Agent
