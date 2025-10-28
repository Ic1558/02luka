#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EXPORTER_SCRIPT="${SCRIPT_DIR}/run_parquet_exporter.sh"
DEFAULT_REPORT_DIR="${REPO_ROOT}/g/reports/parquet"
DEFAULT_MANIFEST="${DEFAULT_REPORT_DIR}/export_manifest.json"
DUCKDB_BIN="${PARQUET_EXPORTER_DUCKDB_BIN:-duckdb}"

usage() {
  cat <<USAGE
Usage: ${BASH_SOURCE[0]} [options]

Options:
  --trigger            Run the exporter before verification
  --report <path>      Override verification report path (default: g/reports/parquet/verify_YYYYMMDD.md)
  --manifest <path>    Override manifest path (default: g/reports/parquet/export_manifest.json)
  --duckdb <path>      Override duckdb binary for row counts (default: duckdb)
  --help               Show this help message

All additional arguments are forwarded to run_parquet_exporter.sh when --trigger is provided.
USAGE
}

TRIGGER=0
REPORT_PATH=""
MANIFEST_PATH="${DEFAULT_MANIFEST}"
EXPORTER_ARGS=()

while (($# > 0)); do
  case "$1" in
    --trigger)
      TRIGGER=1
      shift
      ;;
    --report)
      if [[ $# -lt 2 ]]; then
        echo "--report requires a value" >&2
        exit 1
      fi
      REPORT_PATH="$2"
      shift 2
      ;;
    --manifest)
      if [[ $# -lt 2 ]]; then
        echo "--manifest requires a value" >&2
        exit 1
      fi
      MANIFEST_PATH="$2"
      shift 2
      ;;
    --duckdb)
      if [[ $# -lt 2 ]]; then
        echo "--duckdb requires a value" >&2
        exit 1
      fi
      DUCKDB_BIN="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      while (($# > 0)); do
        EXPORTER_ARGS+=("$1")
        shift
      done
      ;;
    *)
      EXPORTER_ARGS+=("$1")
      shift
      ;;
  esac
done

TODAY="$(date +"%Y%m%d")"
REPORT_DIR="${DEFAULT_REPORT_DIR}"
mkdir -p "${REPORT_DIR}"

if [[ -z "${REPORT_PATH}" ]]; then
  REPORT_PATH="${REPORT_DIR}/verify_${TODAY}.md"
else
  REPORT_DIR="$(cd "$(dirname "${REPORT_PATH}")" && pwd)"
  mkdir -p "${REPORT_DIR}"
fi

if [[ ${TRIGGER} -eq 1 ]]; then
  if [[ ! -x "${EXPORTER_SCRIPT}" ]]; then
    echo "[parquet-exporter] ERROR: exporter wrapper missing at ${EXPORTER_SCRIPT}" >&2
    exit 1
  fi
  "${EXPORTER_SCRIPT}" "${EXPORTER_ARGS[@]}"
fi

if [[ ! -f "${MANIFEST_PATH}" ]]; then
  echo "[parquet-exporter] ERROR: manifest not found at ${MANIFEST_PATH}" >&2
  exit 1
fi

if ! command -v "${DUCKDB_BIN}" >/dev/null 2>&1; then
  echo "[parquet-exporter] WARN: duckdb binary (${DUCKDB_BIN}) not found. Row counts will be skipped." >&2
  SKIP_ROWCOUNT=1
else
  SKIP_ROWCOUNT=0
fi

MANIFEST_ABS="$(cd "$(dirname "${MANIFEST_PATH}")" && pwd)/$(basename "${MANIFEST_PATH}")"
REPORT_ABS="$(cd "$(dirname "${REPORT_PATH}")" && pwd)/$(basename "${REPORT_PATH}")"

MANIFEST="${MANIFEST_ABS}" REPORT="${REPORT_ABS}" DUCKDB_BIN="${DUCKDB_BIN}" SKIP_ROWCOUNT="${SKIP_ROWCOUNT}" node <<'NODE'
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const manifestPath = process.env.MANIFEST;
const reportPath = process.env.REPORT;
const duckdbBin = process.env.DUCKDB_BIN;
const skipRowCount = process.env.SKIP_ROWCOUNT === '1';

if (!fs.existsSync(manifestPath)) {
  throw new Error(`Manifest missing: ${manifestPath}`);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const exportsList = Array.isArray(manifest.exports) ? manifest.exports : [];
const summary = manifest.summary || {};

if (exportsList.length === 0) {
  throw new Error('No export entries recorded in manifest');
}

const reportLines = [];
const isoDate = new Date().toISOString();
reportLines.push(`# Parquet Export Verification – ${isoDate.split('T')[0]}`);
reportLines.push('');
reportLines.push(`- Manifest Generated At: ${manifest.generatedAt || 'unknown'}`);
reportLines.push(`- DuckDB Version: ${manifest.duckdb ? manifest.duckdb.version : 'unknown'}`);
reportLines.push(`- Compression: ${manifest.compression || 'SNAPPY'}`);
reportLines.push(`- Mode: ${manifest.dryRun ? 'dry-run' : 'standard'}`);
reportLines.push(`- Sources Processed: ${summary.totalSources ?? exportsList.length}`);
reportLines.push(`- Exported: ${summary.exported ?? 0}`);
reportLines.push(`- Skipped: ${summary.skipped ?? 0}`);
reportLines.push(`- Dry-Run Entries: ${summary.dryRun ?? 0}`);
reportLines.push(`- Failed Entries: ${summary.failed ?? 0}`);
reportLines.push('');

function escapePipe(value) {
  return String(value).replace(/\|/g, '\\|');
}

function countRows(filePath) {
  if (skipRowCount) {
    return 'n/a';
  }
  const statement = `SELECT COUNT(*) AS cnt FROM read_parquet('${filePath.replace(/'/g, "''")}');`;
  const result = spawnSync(duckdbBin, [':memory:', '--csv', '-c', statement], { encoding: 'utf8' });
  if (result.status !== 0) {
    return 'error';
  }
  const lines = result.stdout.trim().split(/\r?\n/).filter(Boolean);
  if (lines.length === 0) {
    return '0';
  }
  return lines[lines.length - 1].trim();
}

reportLines.push('| Status | Source | Output | Rows | Size (bytes) | Notes |');
reportLines.push('| --- | --- | --- | ---: | ---: | --- |');

let failures = 0;

for (const entry of exportsList) {
  const status = entry.status || 'unknown';
  const source = entry.source || entry.sourceRelative || 'n/a';
  const output = entry.output || entry.outputRelative || 'n/a';
  const note = entry.message || '';
  if (status === 'failed') {
    failures += 1;
  }
  const outputPath = path.isAbsolute(output) ? output : path.join(manifest.repoRoot || process.cwd(), output);
  let size = '';
  if (entry.outputSizeBytes != null) {
    size = entry.outputSizeBytes;
  } else if (fs.existsSync(outputPath)) {
    size = fs.statSync(outputPath).size;
  } else {
    size = 'n/a';
  }
  let rows = 'n/a';
  if (fs.existsSync(outputPath) && status !== 'dry-run' && status !== 'failed' && !manifest.dryRun && !skipRowCount) {
    rows = countRows(outputPath);
  } else if (status === 'dry-run' || manifest.dryRun) {
    rows = 'dry-run';
  }
  const rowSegments = [
    escapePipe(status),
    `\`${escapePipe(source)}\``,
    `\`${escapePipe(output)}\``,
    rows,
    size,
    escapePipe(note),
  ];
  reportLines.push(`| ${rowSegments[0]} | ${rowSegments[1]} | ${rowSegments[2]} | ${rowSegments[3]} | ${rowSegments[4]} | ${rowSegments[5]} |`);
}

reportLines.push('');
reportLines.push(`Report generated at ${isoDate}`);

fs.writeFileSync(reportPath, `${reportLines.join('\n')}\n`, 'utf8');

if (failures > 0) {
  process.stderr.write(`[parquet-exporter] ${failures} item(s) reported as failed.\n`);
  process.exitCode = 1;
}
NODE

status=$?

if [[ ${status} -ne 0 ]]; then
  echo "[parquet-exporter] verification failed" >&2
  exit ${status}
fi

echo "[parquet-exporter] verification report written to ${REPORT_PATH}"

echo "[parquet-exporter] summary:" >&2
sed -n '1,20p' "${REPORT_PATH}" >&2

exit 0
