# WO-251029-PARQUET-EXPORTER

**Status:** 📋 DRAFT (Ready for execution post-validation)
**Priority:** Medium
**Phase:** 7.8 - Analytics Layer Foundation
**Prerequisites:** ✅ Phase 7.7 stable (24h verification required)

---

## Goal

Implement Parquet export pipeline to compress CSV/JSONL performance data into columnar format for efficient DuckDB analytics and dashboard visualization.

## Scope

**In Scope:**
- Create `knowledge/optimize/export_to_parquet.cjs` converter
- Export query_perf CSV → Parquet (~80% compression)
- Export index_advisor JSON → Parquet (structured analytics)
- Export optimization_summary → Parquet time-series
- DuckDB schema generation and validation
- Integration with existing rollup pipelines
- Scheduled conversion (daily at 05:00, after optimizer)

**Out of Scope:**
- Grafana dashboard (separate WO-251029-GRAFANA-BRIDGE)
- Real-time streaming (future Phase 8.x)
- Historical data migration (one-time manual)
- NAS archival (future Phase 8.x)

---

## Background

### Current State (Phase 7.7)

**Performance Data Files:**
```
g/reports/query_perf_daily_YYYYMMDD.csv     (~50-200 KB/day)
g/reports/query_perf_weekly_YYYYWW.csv      (~300-800 KB/week)
knowledge/optimize/index_advisor_report.json (~10-50 KB)
knowledge/optimize/optimization_summary.txt  (varies)
```

**Issues:**
1. CSV files accumulate (50+ MB/year per metric)
2. Not optimized for analytical queries
3. Row-oriented format inefficient for aggregations
4. Manual analysis required (no dashboard)
5. No schema enforcement

### Desired State (Phase 7.8)

**Parquet Pipeline:**
```
CSV/JSON → Parquet → DuckDB → Analytics/Grafana
           (80% smaller)  (fast queries)  (visualization)
```

**Benefits:**
- 70-80% storage reduction
- 10-100x faster analytical queries
- Schema validation and type safety
- Direct Grafana integration ready
- Historical trend analysis enabled

---

## Technical Design

### Architecture

```
Daily Flow (05:00 after optimizer completes):
┌─────────────────────────────────────────┐
│  Input: CSV/JSON from Day 2 OPS        │
│  - query_perf_daily_YYYYMMDD.csv       │
│  - index_advisor_report.json           │
│  - optimization_summary.txt            │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  export_to_parquet.cjs                  │
│  - Parse and validate inputs           │
│  - Apply schema transformations        │
│  - Write Parquet with compression      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Output: Parquet files                  │
│  knowledge/optimize/parquet/            │
│  ├── query_perf_YYYYMMDD.parquet       │
│  ├── index_advisor_YYYYMMDD.parquet    │
│  └── optimization_summary_YYYYMMDD.pqt │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  DuckDB Analytics (future)              │
│  SELECT * FROM 'query_perf_*.parquet'  │
│  WHERE date >= '2025-10-01'            │
└─────────────────────────────────────────┘
```

### Schema Definitions

**query_perf.parquet:**
```typescript
{
  timestamp: TIMESTAMP,
  query_hash: VARCHAR,
  query_type: VARCHAR,
  execution_time_ms: DOUBLE,
  rows_examined: BIGINT,
  rows_returned: BIGINT,
  cache_hit: BOOLEAN,
  table_name: VARCHAR,
  index_used: VARCHAR,
  cpu_time_ms: DOUBLE,
  io_wait_ms: DOUBLE,
  date_partition: DATE
}
```

**index_advisor.parquet:**
```typescript
{
  timestamp: TIMESTAMP,
  table_name: VARCHAR,
  recommended_index: VARCHAR,
  query_pattern: VARCHAR,
  estimated_speedup: DOUBLE,
  estimated_cost: DOUBLE,
  priority: VARCHAR,
  status: VARCHAR,
  date_partition: DATE
}
```

**optimization_summary.parquet:**
```typescript
{
  timestamp: TIMESTAMP,
  event_type: VARCHAR,
  metric_name: VARCHAR,
  metric_value: DOUBLE,
  metadata: JSON,
  date_partition: DATE
}
```

### File Organization

```
knowledge/optimize/
├── parquet/
│   ├── query_perf/
│   │   ├── year=2025/
│   │   │   ├── month=10/
│   │   │   │   ├── query_perf_20251027.parquet
│   │   │   │   ├── query_perf_20251028.parquet
│   │   │   │   └── ...
│   ├── index_advisor/
│   │   ├── year=2025/
│   │   │   ├── month=10/
│   │   │   │   └── index_advisor_20251028.parquet
│   └── optimization_summary/
│       ├── year=2025/
│       │   ├── month=10/
│       │   │   └── optimization_summary_20251028.parquet
├── export_to_parquet.cjs
└── parquet_schema.json
```

---

## Implementation Plan

### Phase 1: Dependencies & Setup

**Install Requirements:**
```bash
npm install --save parquet-js
npm install --save duckdb
```

**Verify Availability:**
```bash
node -e "require('parquet-js'); console.log('Parquet OK')"
node -e "require('duckdb'); console.log('DuckDB OK')"
```

### Phase 2: Core Exporter Script

**Create:** `knowledge/optimize/export_to_parquet.cjs`

**Features:**
- Parse CSV using fast-csv
- Parse JSON with schema validation
- Transform to columnar format
- Write Parquet with Snappy compression
- Partitioning by year/month
- Idempotent (skip if Parquet newer than source)
- Comprehensive error handling
- Progress logging

**CLI Interface:**
```bash
# Export latest files
node knowledge/optimize/export_to_parquet.cjs

# Export specific date
node knowledge/optimize/export_to_parquet.cjs --date 2025-10-28

# Export all historical (batch)
node knowledge/optimize/export_to_parquet.cjs --historical

# Dry run
node knowledge/optimize/export_to_parquet.cjs --dry-run
```

### Phase 3: LaunchAgent Integration

**Create:** `LaunchAgents/com.02luka.parquet_export.plist`

**Schedule:** Daily at 05:00 (after optimizer at 04:00)

**Configuration:**
```xml
<key>Label</key>
<string>com.02luka.parquet_export</string>
<key>StartCalendarInterval</key>
<dict><key>Hour</key><integer>5</integer><key>Minute</key><integer>0</integer></dict>
```

**Rationale:**
- 04:00 - optimizer runs (generates data)
- 05:00 - parquet export runs (converts data)
- 1-hour gap ensures optimizer completion

### Phase 4: Validation & Testing

**Test Suite:**
1. Parse sample CSV → verify schema
2. Parse sample JSON → verify schema
3. Write Parquet → verify compression ratio
4. Read Parquet with DuckDB → verify integrity
5. Test partitioning logic
6. Test idempotency
7. Test error handling (missing files, corrupt data)

**Validation Query:**
```sql
SELECT
  date_partition,
  COUNT(*) as query_count,
  AVG(execution_time_ms) as avg_execution_ms,
  MAX(execution_time_ms) as max_execution_ms
FROM read_parquet('knowledge/optimize/parquet/query_perf/**/*.parquet')
GROUP BY date_partition
ORDER BY date_partition DESC
LIMIT 30;
```

---

## Acceptance Criteria

### Must Have ✅

1. **Script Execution:**
   - [ ] `export_to_parquet.cjs` runs without errors
   - [ ] Processes query_perf CSV successfully
   - [ ] Processes index_advisor JSON successfully
   - [ ] Handles missing input files gracefully

2. **Output Quality:**
   - [ ] Parquet files created in correct directory structure
   - [ ] Compression ratio ≥ 70% vs original CSV
   - [ ] Schema matches specification
   - [ ] Data integrity verified (row counts match)

3. **DuckDB Integration:**
   - [ ] DuckDB can read Parquet files
   - [ ] Schema recognized correctly
   - [ ] Sample analytical query succeeds
   - [ ] Performance acceptable (< 1 sec for 30-day query)

4. **LaunchAgent:**
   - [ ] LaunchAgent loads successfully
   - [ ] First scheduled run completes (tomorrow 05:00)
   - [ ] Logs show successful execution
   - [ ] No errors in stderr

5. **Idempotency:**
   - [ ] Rerun produces no errors
   - [ ] Doesn't recreate existing Parquet files
   - [ ] Log shows "already exists, skipping"

### Nice to Have 🎯

- [ ] Progress bar for large datasets
- [ ] Email notification on completion
- [ ] Slack/Discord integration
- [ ] Historical migration script
- [ ] Automatic schema evolution detection
- [ ] Data quality metrics

---

## Testing Plan

### Test 1: Manual Execution (Before LaunchAgent)

```bash
# Dry run first
cd 02luka-repo
node knowledge/optimize/export_to_parquet.cjs --dry-run

# Expected output:
# ✓ Found query_perf_daily_20251028.csv (127 KB)
# ✓ Found index_advisor_report.json (23 KB)
# → Would create query_perf_20251028.parquet
# → Would create index_advisor_20251028.parquet
# DRY RUN - no files written

# Live run
node knowledge/optimize/export_to_parquet.cjs

# Expected output:
# ✓ Parsed 1,234 rows from query_perf_daily_20251028.csv
# ✓ Wrote knowledge/optimize/parquet/query_perf/.../query_perf_20251028.parquet (22 KB)
# ✓ Compression: 127 KB → 22 KB (82.7% reduction)
# ✓ Schema validated
```

### Test 2: DuckDB Validation

```sql
-- Connect to DuckDB
duckdb

-- Load Parquet
SELECT * FROM 'knowledge/optimize/parquet/query_perf/**/*.parquet' LIMIT 10;

-- Verify schema
DESCRIBE SELECT * FROM 'knowledge/optimize/parquet/query_perf/**/*.parquet';

-- Test analytical query
SELECT
  date_partition,
  COUNT(*) as queries,
  ROUND(AVG(execution_time_ms), 2) as avg_ms
FROM read_parquet('knowledge/optimize/parquet/query_perf/**/*.parquet')
GROUP BY date_partition
ORDER BY date_partition DESC;
```

### Test 3: Idempotency

```bash
# Run twice - second should skip existing files
node knowledge/optimize/export_to_parquet.cjs
node knowledge/optimize/export_to_parquet.cjs

# Expected second run output:
# ⊘ query_perf_20251028.parquet already exists, skipping
# ⊘ index_advisor_20251028.parquet already exists, skipping
# ✓ Export complete (0 new files)
```

### Test 4: LaunchAgent

```bash
# Deploy LaunchAgent
cp LaunchAgents/com.02luka.parquet_export.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.02luka.parquet_export.plist

# Verify loaded
launchctl list | grep com.02luka.parquet_export

# Manual trigger (test before scheduled run)
launchctl start com.02luka.parquet_export

# Check logs
tail -50 g/logs/parquet_export.log
```

---

## Risks & Mitigations

### Risk 1: Parquet Library Issues

**Risk:** `parquet-js` may have compatibility issues with large files

**Mitigation:**
- Test with sample data first
- Fallback: Use Python's `pyarrow` if Node.js fails
- Chunk processing for large files (>100MB)

**Contingency:** Keep CSV files as source of truth

### Risk 2: Schema Evolution

**Risk:** CSV/JSON format changes break Parquet export

**Mitigation:**
- Schema validation before export
- Graceful degradation (log warnings, continue)
- Version tracking in Parquet metadata

**Contingency:** Manual schema update and re-export

### Risk 3: Disk Space

**Risk:** Parquet accumulation over months

**Mitigation:**
- Report rotation system already in place
- Compress old Parquet (gzip on top of Parquet)
- Archive to NAS (future phase)

**Monitoring:** Alert if `knowledge/optimize/parquet/` > 5GB

### Risk 4: Performance Impact

**Risk:** Export at 05:00 conflicts with system resources

**Mitigation:**
- Runs after optimizer (no DB contention)
- Nice/ionice for low priority I/O
- Timeout: 10 minutes max

**Fallback:** Reschedule to 06:00 if needed

---

## Rollout Strategy

### Stage 1: Development (Tonight - Draft Only)

- [x] Create WO document
- [ ] Design schema
- [ ] Research parquet-js API
- [ ] Plan test cases

### Stage 2: Implementation (Tomorrow 09:10+)

**Prerequisites Check:**
```bash
# Verify 24h stability
grep "Monitor Complete" g/logs/ops_monitor.log | wc -l  # Should be ~30+
grep "rotate:archived" g/reports/_rotate_reports.log | tail -3  # Check rotations
tail -50 g/logs/optimizer.log  # Verify 04:00 run succeeded
```

**If green:**
1. Install dependencies (npm install)
2. Create export_to_parquet.cjs
3. Test with dry-run
4. Test live with today's data
5. Validate with DuckDB
6. Create LaunchAgent
7. Deploy (but don't load yet - wait for tomorrow 05:00)

### Stage 3: Validation (Tomorrow 09:30)

1. Review test results
2. Verify compression ratios
3. Test DuckDB queries
4. Document findings

### Stage 4: Deployment (Tomorrow PM)

1. Load LaunchAgent (scheduled for next 05:00)
2. Monitor first scheduled run (day after tomorrow)
3. Verify results
4. Mark WO complete

---

## Success Metrics

### Performance

- **Compression Ratio:** ≥ 70% reduction
- **Export Time:** < 5 minutes for daily data
- **Query Performance:** < 1 second for 30-day aggregation
- **Storage Growth:** Linear, not exponential

### Reliability

- **Success Rate:** ≥ 99% (daily exports)
- **Idempotency:** 100% (no duplicate exports)
- **Error Recovery:** Graceful (doesn't crash on bad data)

### Quality

- **Data Integrity:** 100% (row counts match)
- **Schema Compliance:** 100% (all fields present)
- **Compression:** No data loss
- **Partitioning:** Correct year/month structure

---

## Integration Points

### Upstream (Data Sources)

**From Day 2 OPS:**
- `g/reports/query_perf_daily_YYYYMMDD.csv` (perf rollups)
- `g/reports/query_perf_weekly_YYYYWW.csv` (weekly rollups)

**From Optimizer:**
- `knowledge/optimize/index_advisor_report.json` (recommendations)
- `knowledge/optimize/optimization_summary.txt` (events)

### Downstream (Consumers)

**Immediate:**
- DuckDB analytical queries (manual)
- Data quality validation scripts

**Future (Phase 7.8-B):**
- Grafana dashboards (visualization)
- Alert rules (anomaly detection)
- API endpoints (dashboard.theedges.work)

**Future (Phase 8.x):**
- ML model training (predictive analytics)
- Capacity planning tools
- Cost optimization analysis

---

## Monitoring & Observability

### Logs

**Export Logs:**
- `g/logs/parquet_export.log` (stdout)
- `g/logs/parquet_export.err` (stderr)

**Log Format:**
```
[TIMESTAMP] [LEVEL] export:parquet file=query_perf_20251028.parquet rows=1234 compressed_kb=22 ratio=82.7%
```

### Metrics to Track

1. **Export Success Rate:** % successful exports
2. **Compression Ratio:** Average % reduction
3. **Processing Time:** Seconds per export
4. **File Count:** Total Parquet files
5. **Storage Used:** Total KB in parquet/

### Health Checks

**Daily (automated):**
```bash
# Verify yesterday's export exists
DATE_YESTERDAY=$(date -v-1d +%Y%m%d)
ls knowledge/optimize/parquet/query_perf/**/query_perf_${DATE_YESTERDAY}.parquet
```

**Weekly (manual):**
```sql
-- Query performance trends
SELECT
  date_partition,
  COUNT(*) as queries,
  AVG(execution_time_ms) as avg_ms
FROM read_parquet('knowledge/optimize/parquet/query_perf/**/*.parquet')
WHERE date_partition >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY date_partition
ORDER BY date_partition;
```

---

## Documentation Deliverables

1. **Implementation Report:** `g/reports/251029_PARQUET_EXPORTER_DEPLOYED.md`
2. **Operations Guide:** `knowledge/optimize/PARQUET_README.md`
3. **Schema Reference:** `knowledge/optimize/parquet_schema.json`
4. **Query Examples:** `knowledge/optimize/example_queries.sql`

---

## Timeline

### Optimistic (All Green)

```
Day 1 (Tonight):     WO draft complete ✅
Day 2 (Tomorrow):    09:05 - Validation
                     09:10 - Implementation start
                     10:00 - Testing complete
                     10:30 - LaunchAgent deployed
Day 3:               05:00 - First scheduled export
                     09:00 - Verify results
                     Phase 7.8 complete ✅
```

### Realistic (Some Issues)

```
Day 1 (Tonight):     WO draft complete ✅
Day 2 (Tomorrow):    09:05 - Validation
                     09:10 - Implementation start
                     11:00 - Testing (with debugging)
                     12:00 - LaunchAgent deployed
Day 3:               05:00 - First scheduled export
                     09:00 - Debug any issues
Day 4:               05:00 - Second export (verify stable)
                     Phase 7.8 complete ✅
```

### Conservative (Major Issues)

```
Day 1 (Tonight):     WO draft complete ✅
Day 2 (Tomorrow):    09:05 - Validation reveals issues
                     10:00 - Troubleshoot Phase 7.7
Day 3:               09:05 - Re-validate
                     09:10 - Implementation start
                     11:00 - Testing
Day 4:               05:00 - First scheduled export
Day 5:               09:00 - Verify, iterate if needed
                     Phase 7.8 complete ✅
```

---

## Appendices

### A. Sample Data

**query_perf_daily_20251028.csv:**
```csv
timestamp,query_hash,query_type,execution_time_ms,rows_examined,rows_returned,cache_hit,table_name,index_used
2025-10-28T00:15:23Z,a1b2c3,SELECT,45.2,1234,10,false,embeddings,idx_namespace
2025-10-28T00:16:01Z,d4e5f6,INSERT,12.8,1,1,false,query_log,PRIMARY
...
```

**index_advisor_report.json:**
```json
{
  "timestamp": "2025-10-28T04:00:00Z",
  "recommendations": [
    {
      "table": "embeddings",
      "index": "idx_embedding_vector",
      "query_pattern": "WHERE namespace = ? AND vector LIKE ?",
      "estimated_speedup": 3.5,
      "priority": "high"
    }
  ]
}
```

### B. DuckDB Schema DDL

```sql
-- Create view over Parquet files (no data copy)
CREATE VIEW query_performance AS
SELECT * FROM read_parquet('knowledge/optimize/parquet/query_perf/**/*.parquet');

CREATE VIEW index_recommendations AS
SELECT * FROM read_parquet('knowledge/optimize/parquet/index_advisor/**/*.parquet');

-- Common queries
CREATE MACRO avg_query_time(days INT) AS (
  SELECT AVG(execution_time_ms)
  FROM query_performance
  WHERE date_partition >= CURRENT_DATE - days
);

CREATE MACRO slow_queries(threshold_ms DOUBLE) AS (
  SELECT *
  FROM query_performance
  WHERE execution_time_ms > threshold_ms
  ORDER BY execution_time_ms DESC
);
```

### C. Future Enhancements

**Phase 8.1: Real-Time Streaming**
- Replace batch export with streaming ingestion
- Sub-second latency for dashboard updates
- Kafka/Redpanda integration

**Phase 8.2: Predictive Analytics**
- ML models for query performance prediction
- Anomaly detection for unusual patterns
- Capacity forecasting

**Phase 8.3: Multi-Tenant Analytics**
- Per-namespace performance tracking
- Customer-facing analytics dashboards
- Cost allocation and billing data

---

## Notes

- **Dependencies:** Requires stable Phase 7.7 (verify tomorrow 09:05)
- **Integration:** Fits between Day 2 OPS (04:00) and Digest (09:00)
- **Reversibility:** Non-destructive (keeps CSV source files)
- **Compatibility:** macOS LaunchAgent, Asia/Bangkok timezone
- **Owner:** CLC (Claude Code)
- **Reviewer:** GG (Governance)

---

**Work Order Status:** 📋 DRAFT
**Ready for Execution:** After 24h Phase 7.7 validation
**Estimated Duration:** 2-3 hours (implementation + testing)
**Risk Level:** Low (non-destructive, incremental)

**Tags:** `#phase-7.8` `#parquet` `#analytics` `#duckdb` `#data-pipeline` `#work-order`
