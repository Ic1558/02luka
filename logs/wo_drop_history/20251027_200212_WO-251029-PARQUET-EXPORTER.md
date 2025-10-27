# WO-251029-PARQUET-EXPORTER

**Phase:** 7.8 – Parquet Exporter Activation
**Owner:** CLS Drop Team → CLC Automation
**Priority:** P0 (Immediate Execution)

## Objective
Bring the Parquet Exporter online for query performance telemetry so compressed Parquet artifacts are generated alongside the existing JSON/CSV outputs. Ensure audit logging and verification artifacts are produced for downstream analytics.

## Required Actions
1. Deploy or refresh the Parquet exporter worker so it monitors the latest daily/weekly rollups located in `g/reports/`.
2. Enable compressed `.parquet` output for both daily (`query_perf_daily_YYYYMMDD`) and weekly (`query_perf_weekly_YYYYWW`) datasets.
3. Write verification output to `g/reports/parquet/verify_<timestamp>.md` describing the status of each export and any remediation that is required.
4. Append the drop event to `logs/wo_drop_history/WO_HISTORY.log` for compliance.

## Acceptance Criteria
- ✅ Exporter runs without operator intervention and generates `.parquet` files on the next rollup cycle.
- ✅ Verification report exists under `g/reports/parquet/` summarizing dataset counts and exporter health.
- ✅ Audit trail updated with timestamped drop + trigger token entries.
- ✅ Script `scripts/analytics/verify_parquet_agent.sh --trigger` exits successfully.

## Notes for CLC
- Work order is idempotent; re-running the exporter or verifier should not duplicate artifacts beyond timestamped reports.
- Verification may be invoked immediately after drop; it should gracefully handle missing `.parquet` files by flagging follow-up work rather than failing the job.
- Coordinate with analytics team if datasets remain absent after 1 hour.
