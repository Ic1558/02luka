# Work Order: Grafana Dashboard Helper for Performance Reports
- **ID:** WO-251022-GG-PERF-GRAFANA
- **Requested by:** GG
- **Goal:** Pre-built Grafana dashboards + DuckDB datasource helper for visualizing query performance trends.

## Background
After WO-7 delivers Parquet files, we want visual dashboards for:
- **Latency trends:** p50/p95/p99 over time
- **Slow query alerts:** Patterns exceeding 100ms threshold
- **Query frequency:** Top patterns by sample count
- **Week-over-week comparisons:** Performance regressions

## Prerequisites
- Grafana installed locally or accessible instance
- DuckDB CLI installed (`brew install duckdb`)
- WO-7 completed (Parquet files in `g/reports/`)

## Scope

### 1. Create `knowledge/grafana/` directory structure
```bash
mkdir -p knowledge/grafana/{datasources,dashboards,queries}
```

### 2. DuckDB Datasource Configuration

**File: `knowledge/grafana/datasources/duckdb_perf.yaml`**

```yaml
apiVersion: 1

datasources:
  - name: DuckDB Performance Reports
    type: grafana-duckdb-datasource
    access: proxy
    url: file:///path/to/02luka-repo/g/reports/perf.duckdb
    isDefault: true
    editable: true
    jsonData:
      path: /path/to/02luka-repo/g/reports/perf.duckdb
    version: 1
```

**Installation:**
```bash
# Install DuckDB datasource plugin for Grafana
grafana-cli plugins install grafana-duckdb-datasource

# Or use Docker with pre-installed plugin
docker run -d \
  -p 3000:3000 \
  -v $(pwd)/knowledge/grafana/datasources:/etc/grafana/provisioning/datasources \
  -v $(pwd)/knowledge/grafana/dashboards:/etc/grafana/provisioning/dashboards \
  -v $(pwd)/g/reports:/data/reports \
  --name grafana \
  grafana/grafana:latest
```

### 3. Pre-built Dashboard: Query Performance Overview

**File: `knowledge/grafana/dashboards/query_perf_overview.json`**

**Panels:**
1. **P95 Latency Trend (Time Series)**
   - Query: Weekly p95_ms by pattern (top 10)
   - X-axis: Week number
   - Y-axis: Latency (ms)
   - Alert: Red line at 100ms

2. **Slow Query Count (Stat Panel)**
   - Query: Count of patterns where slow_flag = true
   - Current week vs last week comparison
   - Color: Red if increasing

3. **Top 10 Slow Patterns (Bar Chart)**
   - Query: Patterns ordered by p95_ms DESC
   - Current week only

4. **Query Volume (Time Series)**
   - Query: Total samples per week
   - Stacked by pattern (top 5)

5. **P50 vs P95 vs P99 (Multi-line Time Series)**
   - Query: All percentiles for a selected pattern
   - Dropdown variable: pattern selection

**Sample Dashboard JSON Structure:**
```json
{
  "dashboard": {
    "title": "02luka Query Performance",
    "panels": [
      {
        "title": "P95 Latency Trend",
        "type": "timeseries",
        "targets": [
          {
            "rawSql": "SELECT week, pattern, p95_ms FROM 'g/reports/query_perf_weekly_*.parquet' WHERE pattern IN (SELECT pattern FROM 'g/reports/query_perf_weekly_*.parquet' ORDER BY p95_ms DESC LIMIT 10)",
            "format": "time_series"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "ms"
          }
        }
      }
    ]
  }
}
```

### 4. Query Template Library

**File: `knowledge/grafana/queries/perf_queries.sql`**

```sql
-- Query 1: Top 10 slowest patterns (current week)
SELECT pattern, p95_ms, samples
FROM 'g/reports/query_perf_weekly_202543.parquet'
ORDER BY p95_ms DESC
LIMIT 10;

-- Query 2: Week-over-week p95 comparison
WITH current_week AS (
  SELECT pattern, p95_ms
  FROM 'g/reports/query_perf_weekly_202543.parquet'
),
last_week AS (
  SELECT pattern, p95_ms
  FROM 'g/reports/query_perf_weekly_202542.parquet'
)
SELECT
  c.pattern,
  c.p95_ms as current_p95,
  l.p95_ms as last_p95,
  ((c.p95_ms - l.p95_ms) / l.p95_ms * 100) as pct_change
FROM current_week c
LEFT JOIN last_week l ON c.pattern = l.pattern
ORDER BY pct_change DESC;

-- Query 3: Slow query alert count (last 4 weeks)
SELECT
  COUNT(DISTINCT pattern) as slow_patterns,
  SUM(samples) as total_slow_queries
FROM 'g/reports/query_perf_weekly_*.parquet'
WHERE slow_flag = true
  AND week >= (SELECT MAX(week) - 3 FROM 'g/reports/query_perf_weekly_*.parquet');

-- Query 4: Pattern frequency over time
SELECT week, pattern, SUM(samples) as total_samples
FROM 'g/reports/query_perf_weekly_*.parquet'
WHERE pattern IN ($selected_patterns)
GROUP BY week, pattern
ORDER BY week ASC;

-- Query 5: Percentile distribution (current week)
SELECT
  pattern,
  p50_ms,
  p95_ms,
  p99_ms,
  (p99_ms - p50_ms) as latency_spread
FROM 'g/reports/query_perf_weekly_202543.parquet'
ORDER BY latency_spread DESC
LIMIT 20;
```

### 5. Dashboard Provisioning Script

**File: `knowledge/grafana/provision_dashboards.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_API_KEY="${GRAFANA_API_KEY:-admin:admin}"

# Create datasource
curl -X POST "$GRAFANA_URL/api/datasources" \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_API_KEY" \
  -d @knowledge/grafana/datasources/duckdb_perf.yaml

# Upload dashboard
curl -X POST "$GRAFANA_URL/api/dashboards/db" \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_API_KEY" \
  -d @knowledge/grafana/dashboards/query_perf_overview.json

echo "✅ Grafana dashboards provisioned"
echo "📊 Access: $GRAFANA_URL/d/query-perf-overview"
```

### 6. Optional: DuckDB View Helper

**File: `knowledge/grafana/create_views.sql`**

Create materialized views for faster Grafana queries:

```sql
-- Create a unified view across all weekly reports
CREATE OR REPLACE VIEW perf_all_weeks AS
SELECT * FROM read_parquet('g/reports/query_perf_weekly_*.parquet');

-- Create a "slow patterns" view
CREATE OR REPLACE VIEW perf_slow_patterns AS
SELECT * FROM perf_all_weeks WHERE slow_flag = true;

-- Create a "top patterns" view (by sample count)
CREATE OR REPLACE VIEW perf_top_patterns AS
SELECT pattern, SUM(samples) as total_samples, AVG(p95_ms) as avg_p95
FROM perf_all_weeks
GROUP BY pattern
ORDER BY total_samples DESC
LIMIT 50;
```

**Run once:**
```bash
duckdb g/reports/perf.duckdb < knowledge/grafana/create_views.sql
```

### 7. Alternative: JSON API for Custom Dashboards

**File: `knowledge/grafana/api_server.cjs`**

Simple Express server that wraps DuckDB queries as JSON API (if Grafana plugin unavailable):

```js
import express from 'express';
import duckdb from 'duckdb';

const app = express();
const db = new duckdb.Database('g/reports/perf.duckdb');

app.get('/api/perf/weekly/:week', (req, res) => {
  db.all(
    `SELECT * FROM read_parquet('g/reports/query_perf_weekly_${req.params.week}.parquet')`,
    (err, rows) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(rows);
    }
  );
});

app.get('/api/perf/slow', (req, res) => {
  db.all(
    `SELECT * FROM read_parquet('g/reports/query_perf_weekly_*.parquet') WHERE slow_flag = true ORDER BY p95_ms DESC LIMIT 20`,
    (err, rows) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(rows);
    }
  );
});

app.listen(3001, () => console.log('📊 Perf API running on :3001'));
```

**Use with Grafana JSON datasource plugin:**
```bash
npm install express duckdb
node knowledge/grafana/api_server.cjs &

# Configure Grafana JSON datasource → http://localhost:3001
```

## Acceptance Criteria

1. **Datasource connection:**
   - Grafana connects to DuckDB database (local or API)
   - Test query returns data: `SELECT * FROM perf_all_weeks LIMIT 5`

2. **Dashboard loads:**
   - Query Performance Overview dashboard displays in Grafana
   - All 5 panels render without errors
   - Time range selector works (filter by week)

3. **Alerts functional:**
   - P95 threshold alert triggers when > 100ms
   - Notification sent to configured channel (email/Slack)

4. **Variables work:**
   - Pattern dropdown populates from data
   - Selecting pattern updates all panels

5. **Performance:**
   - Dashboard loads in < 2 seconds
   - Query refresh completes in < 500ms

## Documentation

Create `docs/GRAFANA_PERF_DASHBOARDS.md`:
- Installation guide (Grafana + DuckDB plugin)
- Dashboard screenshot tour
- Query customization examples
- Alerting rule templates
- MotherDuck cloud integration

## Estimated Effort
- Datasource config: 15 minutes
- Dashboard JSON creation: 45 minutes
- Query library: 30 minutes
- Provisioning script: 15 minutes
- Documentation: 30 minutes
- **Total: ~2 hours**

## Dependencies
- Grafana (local or cloud instance)
- `grafana-duckdb-datasource` plugin OR
- `grafana-json-datasource` plugin + custom API server
- DuckDB CLI (for view creation)

## Optional Enhancements
- **MotherDuck integration:** Replace local DuckDB with cloud instance
- **Slack alerts:** Webhook notifications for slow queries
- **CSV export button:** Download dashboard data as CSV
- **Drill-down panels:** Click pattern → view individual query details

## Next Steps
After verification:
- Add custom dashboards for specific agent performance
- Integrate with 02luka health monitoring system
- Create alerting runbooks for slow query resolution
