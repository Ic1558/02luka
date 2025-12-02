# Work Order: CSV Export for Nightly & Weekly Perf Rollups
- **ID:** WO-251022-GG-PERF-ROLLUP-CSV
- **Requested by:** GG
- **Goal:** Add `--csv` option to both rollups to emit Grafana/Sheets-ready CSV files alongside JSON.

## Scope
Add a `--csv` flag to:
1) `knowledge/perf_rollup.cjs` (nightly)
2) `knowledge/perf_rollup_weekly.cjs` (weekly)

Behavior:
- If `--csv` present, write `*.csv` next to the JSON output:
  - Nightly: `g/reports/query_perf_daily_YYYYMMDD.csv`
  - Weekly:  `g/reports/query_perf_weekly_YYYYWW.csv`
- CSV headers (nightly):
```
pattern,samples,avg_ms,p50_ms,p95_ms,p99_ms,slow_flag
```

- CSV headers (weekly): **same** (schema-aligned).

## Patch outline

### A) `knowledge/perf_rollup.cjs` (nightly)
- Parse flags:
```js
const CSV = process.argv.includes('--csv');
```

- After building outObj and writing JSON, append:
```js
function toCSV(rows){
  const esc = s => `"${String(s).replace(/"/g,'""')}"`;
  const lines = ['pattern,samples,avg_ms,p50_ms,p95_ms,p99_ms,slow_flag'];
  for (const r of rows){
    lines.push([
      esc(r.query_key), r.samples, r.avg_ms.toFixed(2),
      r.p50_ms.toFixed(2), r.p95_ms.toFixed(2), r.p99_ms.toFixed(2),
      r.alert ? 'true' : 'false'
    ].join(','));
  }
  return lines.join('\n') + '\n';
}
if (CSV) {
  const OUTCSV = OUT.replace(/\.json$/, '.csv');
  fs.writeFileSync(OUTCSV, toCSV(report));
  console.log('WROTE', OUTCSV);
}
```

- Keep JSON output unchanged.

### B) `knowledge/perf_rollup_weekly.cjs` (weekly)
- Same `const CSV = process.argv.includes('--csv');`
- After writing JSON, add the same `toCSV()` and write `OUT.replace('.json','.csv')` using the weekly array (per-file schema identical).

### C) Docs update: `docs/PERF_ROLLUP.md`
- Add a short "CSV Export" section:
  - Nightly manual: `node knowledge/perf_rollup.cjs --csv`
  - Weekly manual:  `node knowledge/perf_rollup_weekly.cjs --csv`
  - File names and columns as above.
  - Note: CSV always mirrors the JSON report array.

## Acceptance
- Manual nightly run:
```bash
node knowledge/perf_rollup.cjs --csv
```

Produces both:
- `g/reports/query_perf_daily_YYYYMMDD.json`
- `g/reports/query_perf_daily_YYYYMMDD.csv` (non-empty, valid headers).

- Manual weekly run:
```bash
node knowledge/perf_rollup_weekly.cjs --csv
```

Produces:
- `g/reports/query_perf_weekly_YYYYWW.json`
- `g/reports/query_perf_weekly_YYYYWW.csv`

- CSV imports cleanly into Google Sheets / Excel; Grafana can ingest the weekly CSV.
- LaunchAgents/cron continue to run without `--csv`; adding it to the scheduled commands is optional and can be done later.

## Optional (nice-to-have, if time)
- Add `--stdout-csv` that prints CSV to STDOUT instead of writing a file (for piping).
- Add `--threshold-p95=<ms>` to override slow flag (default 100 ms) at runtime; serialize the chosen threshold into JSON `thresholds` for transparency.
