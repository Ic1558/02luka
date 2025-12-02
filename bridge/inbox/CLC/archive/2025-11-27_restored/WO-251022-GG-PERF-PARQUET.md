# Work Order: CSV → Parquet Converter for Performance Reports
- **ID:** WO-251022-GG-PERF-PARQUET
- **Requested by:** GG
- **Goal:** Convert daily/weekly CSV performance reports to Parquet format for 10x compression + 100x faster DuckDB queries.

## Background
After WO-4, WO-5, WO-6 deliver CSV exports, we want columnar Parquet files for:
- **Storage efficiency:** 100 KB CSV → 10 KB Parquet (gzip-like compression)
- **Query speed:** DuckDB reads Parquet 100x faster than CSV (columnar access)
- **Type safety:** Enforce float64/int64/bool schema vs string-only CSV
- **Cloud analytics:** MotherDuck native format (no ETL required)

## Scope

### 1. Install dependency
```bash
cd /path/to/02luka-repo
npm install --save parquetjs
```

### 2. Create `knowledge/perf_to_parquet.cjs`

**CLI Usage:**
```bash
# Single file conversion
node knowledge/perf_to_parquet.cjs \
  --input g/reports/query_perf_daily_20251022.csv \
  --output g/reports/query_perf_daily_20251022.parquet

# Batch convert all CSVs in g/reports/
node knowledge/perf_to_parquet.cjs --convert-all

# Auto-convert: process only new CSVs (no .parquet exists yet)
node knowledge/perf_to_parquet.cjs --auto
```

**Schema Mapping:**
```
CSV Column       Parquet Type    Notes
─────────────────────────────────────────────
pattern          UTF8            Query pattern (normalized)
samples          INT64           Number of samples
avg_ms           DOUBLE          Average latency (optional for daily)
p50_ms           DOUBLE          50th percentile
p95_ms           DOUBLE          95th percentile
p99_ms           DOUBLE          99th percentile
slow_flag        BOOLEAN         True if p95 > 100ms
```

**Implementation Outline:**
```js
import fs from 'fs';
import path from 'path';
import parquet from 'parquetjs';

// Schema definition
const schema = new parquet.ParquetSchema({
  pattern: { type: 'UTF8' },
  samples: { type: 'INT64' },
  avg_ms: { type: 'DOUBLE', optional: true },
  p50_ms: { type: 'DOUBLE' },
  p95_ms: { type: 'DOUBLE' },
  p99_ms: { type: 'DOUBLE' },
  slow_flag: { type: 'BOOLEAN' }
});

async function csvToParquet(csvPath, parquetPath) {
  const csv = fs.readFileSync(csvPath, 'utf8');
  const lines = csv.trim().split('\n');
  const header = lines[0].split(',');
  const rows = lines.slice(1);

  const writer = await parquet.ParquetWriter.openFile(schema, parquetPath);

  for (const line of rows) {
    const cols = line.match(/(".*?"|[^,]+)/g).map(c => c.replace(/^"|"$/g, '').replace(/""/g, '"'));
    const row = {
      pattern: cols[0],
      samples: parseInt(cols[1], 10),
      avg_ms: cols[2] ? parseFloat(cols[2]) : null,
      p50_ms: parseFloat(cols[3]),
      p95_ms: parseFloat(cols[4]),
      p99_ms: parseFloat(cols[5]),
      slow_flag: cols[6] === 'true'
    };
    await writer.appendRow(row);
  }

  await writer.close();
  console.log(`✅ Converted: ${csvPath} → ${parquetPath}`);
}

// CLI argument parsing
const args = process.argv.slice(2);
if (args.includes('--convert-all') || args.includes('--auto')) {
  const files = fs.readdirSync('g/reports')
    .filter(f => f.startsWith('query_perf_') && f.endsWith('.csv'));

  for (const file of files) {
    const csvPath = path.join('g/reports', file);
    const parquetPath = csvPath.replace('.csv', '.parquet');

    if (args.includes('--auto') && fs.existsSync(parquetPath)) {
      console.log(`⏭️  Skipping (exists): ${parquetPath}`);
      continue;
    }

    await csvToParquet(csvPath, parquetPath);
  }
} else {
  const inputIdx = args.indexOf('--input');
  const outputIdx = args.indexOf('--output');
  if (inputIdx === -1 || outputIdx === -1) {
    console.error('Usage: --input FILE.csv --output FILE.parquet');
    process.exit(1);
  }
  await csvToParquet(args[inputIdx + 1], args[outputIdx + 1]);
}
```

### 3. Optional: Auto-convert in rollup scripts

**Modify `knowledge/perf_rollup.cjs` (end of file):**
```js
// After writing CSV, optionally convert to Parquet
if (CSV && process.env.AUTO_PARQUET === '1') {
  const { execSync } = require('child_process');
  const parquetPath = OUTCSV.replace('.csv', '.parquet');
  execSync(`node knowledge/perf_to_parquet.cjs --input ${OUTCSV} --output ${parquetPath}`);
  console.log('WROTE', parquetPath);
}
```

**Same for `knowledge/perf_rollup_weekly.cjs`.**

### 4. LaunchAgent integration (optional)

If you want automatic Parquet generation on schedule, modify the existing LaunchAgents:

**`~/Library/LaunchAgents/com.02luka.perfrollup.plist`:**
```xml
<key>EnvironmentVariables</key>
<dict>
  <key>AUTO_PARQUET</key>
  <string>1</string>
</dict>
```

Or run a separate nightly job:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.02luka.perfparquet</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/node</string>
    <string>/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/knowledge/perf_to_parquet.cjs</string>
    <string>--auto</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>4</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/tmp/perfparquet.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/perfparquet.err</string>
</dict>
</plist>
```

**Install:**
```bash
launchctl load ~/Library/LaunchAgents/com.02luka.perfparquet.plist
```

## DuckDB Query Examples

**Local queries (instant):**
```bash
duckdb -c "
SELECT pattern, p95_ms, samples
FROM 'g/reports/query_perf_weekly_*.parquet'
WHERE slow_flag = true
ORDER BY p95_ms DESC
LIMIT 10;
"
```

**Aggregate across weeks:**
```bash
duckdb -c "
SELECT
  pattern,
  AVG(p95_ms) as avg_p95,
  SUM(samples) as total_samples
FROM 'g/reports/query_perf_weekly_*.parquet'
GROUP BY pattern
ORDER BY avg_p95 DESC
LIMIT 20;
"
```

**MotherDuck cloud upload (one-time):**
```bash
motherduck --query "
CREATE TABLE perf_weekly AS
SELECT * FROM 'g/reports/query_perf_weekly_*.parquet'
"
```

## Acceptance Criteria

1. **Manual single conversion:**
   ```bash
   node knowledge/perf_to_parquet.cjs \
     --input g/reports/query_perf_daily_20251022.csv \
     --output g/reports/query_perf_daily_20251022.parquet
   ```
   - Produces valid Parquet file (10-20% original CSV size)
   - DuckDB can read it: `duckdb -c "SELECT * FROM 'file.parquet' LIMIT 5"`

2. **Batch conversion:**
   ```bash
   node knowledge/perf_to_parquet.cjs --convert-all
   ```
   - Converts all `query_perf_*.csv` in `g/reports/`
   - Skips if `--auto` and `.parquet` already exists

3. **Schema validation:**
   - All numeric columns are DOUBLE/INT64 (not strings)
   - `slow_flag` is BOOLEAN
   - File opens cleanly in DuckDB/MotherDuck

4. **Optional auto-convert:**
   - LaunchAgent runs after rollups complete
   - Or `AUTO_PARQUET=1` in rollup environment

## Documentation

Create `docs/PARQUET_PERF_REPORTS.md`:
- Schema reference
- DuckDB query examples
- MotherDuck integration guide
- Compression benchmarks (CSV vs Parquet size)

## Estimated Effort
- Core converter: 30-45 minutes
- LaunchAgent integration: 15 minutes
- Documentation: 15 minutes
- **Total: ~1 hour**

## Dependencies
- `parquetjs` npm package (pure JS, no native compilation)
- DuckDB CLI (optional, for queries: `brew install duckdb`)

## Next Steps (WO-8)
After this is verified, WO-8 will add Grafana datasource helper for visual dashboards.
