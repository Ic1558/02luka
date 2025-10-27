#!/usr/bin/env node
/* Parquet exporter: finds latest daily/weekly rollups and converts to Parquet via DuckDB CLI */
const { execSync } = require('child_process');
const { existsSync, readdirSync, mkdirSync, appendFileSync } = require('fs');
const path = require('path');

const ROOT = path.join(process.env.HOME || '', '02luka');
const G = p => path.join(ROOT, p);
const OUTDIR = G('g/analytics');
const LOG = G('g/logs/parquet_exporter.log');
const DUCKDB = process.env.DUCKDB_BIN || 'duckdb';

function latest(globDir, prefix) {
  if (!existsSync(globDir)) return null;
  const list = readdirSync(globDir).filter(f => f.startsWith(prefix)).sort().reverse();
  return list.length ? path.join(globDir, list[0]) : null;
}

function main() {
  const d0 = new Date();
  const ymd = d0.toISOString().slice(0, 10).replace(/-/g, '');
  const outFolder = path.join(OUTDIR, 'parquet', ymd);
  if (!existsSync(outFolder)) mkdirSync(outFolder, { recursive: true });

  const CSV_DIR = G('g/reports');
  const JSON_DIR = G('g/reports');
  const NDJSON_DIR = G('g/telemetry');

  const dailyCsv = latest(CSV_DIR, 'query_perf_daily_');
  const weeklyCsv = latest(CSV_DIR, 'query_perf_weekly_');
  const dailyJson = latest(JSON_DIR, 'query_perf_daily_');
  const weeklyJson = latest(JSON_DIR, 'query_perf_weekly_');
  const ndjsonPath = path.join(NDJSON_DIR, 'rollup_daily.ndjson');
  const ndjson = existsSync(ndjsonPath) ? ndjsonPath : null;

  const sources = [];
  if (dailyCsv) sources.push(`SELECT * FROM read_csv_auto('${dailyCsv}')`);
  if (weeklyCsv) sources.push(`SELECT * FROM read_csv_auto('${weeklyCsv}')`);
  if (dailyJson) sources.push(`SELECT * FROM read_json_auto('${dailyJson}')`);
  if (weeklyJson) sources.push(`SELECT * FROM read_json_auto('${weeklyJson}')`);
  if (ndjson) sources.push(`SELECT * FROM read_ndjson_auto('${ndjson}')`);

  if (!sources.length) {
    console.log('[ParquetExporter] No inputs found; skipping.');
    process.exit(0);
  }

  const unionSQL = sources.join('\nUNION ALL\n');
  const outFile = path.join(outFolder, `query_perf_${ymd}.parquet`);
  const sql = `
    .mode json
    COPY (
      ${unionSQL}
    )
    TO '${outFile}' (FORMAT PARQUET, COMPRESSION 'SNAPPY');
  `;

  try {
    const t0 = Date.now();
    const res = execSync(`${DUCKDB} -c ${JSON.stringify(sql)}`, {
      stdio: ['ignore', 'pipe', 'pipe']
    }).toString();
    const ms = Date.now() - t0;
    console.log('[ParquetExporter] Wrote', outFile, `in ${ms}ms`);
    appendFileSync(LOG, `[${new Date().toISOString()}] ${res}\n`);
  } catch (err) {
    console.error('[ParquetExporter] DuckDB error:', err.message);
    process.exit(1);
  }
}

main();
