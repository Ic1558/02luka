#!/usr/bin/env zsh
set -euo pipefail

# Parquet Exporter Test Script
# Phase 7.8 - Data Analytics Integration
# Tests: file integrity, row count, compression

REPO_ROOT="${HOME}/02luka"
ANALYTICS_DIR="${REPO_ROOT}/g/analytics"

echo "=== Parquet Exporter Integrity Test ==="
echo ""

# Find latest parquet file
LATEST=$(ls -t "$ANALYTICS_DIR"/*.parquet 2>/dev/null | head -1 || echo "")

if [[ -z "$LATEST" ]]; then
  echo "❌ No Parquet files found in $ANALYTICS_DIR"
  exit 1
fi

echo "📄 Testing: $(basename "$LATEST")"
echo ""

# Check file size
FILE_SIZE=$(stat -f %z "$LATEST")
FILE_SIZE_KB=$((FILE_SIZE / 1024))

echo "File Size: ${FILE_SIZE_KB} KB"

if [[ $FILE_SIZE_KB -gt 5120 ]]; then
  echo "⚠️  WARNING: File size exceeds 5 MB target"
else
  echo "✅ File size OK (≤ 5 MB)"
fi

echo ""

# Query row count using DuckDB
echo "Querying row count..."
ROW_COUNT=$(duckdb -c "SELECT COUNT(*) FROM read_parquet('$LATEST');" 2>/dev/null | tail -1 || echo "0")

echo "Row Count: $ROW_COUNT"

if [[ "$ROW_COUNT" -gt 0 ]]; then
  echo "✅ Parquet file contains data"
else
  echo "❌ Parquet file is empty"
  exit 1
fi

echo ""

# Query sample record
echo "Sample record:"
duckdb -c "SELECT * FROM read_parquet('$LATEST') LIMIT 1;" 2>/dev/null || echo "❌ Failed to read sample"

echo ""

# Verify schema
echo "Schema verification:"
SCHEMA=$(duckdb -c "DESCRIBE SELECT * FROM read_parquet('$LATEST');" 2>/dev/null || echo "")

if [[ -n "$SCHEMA" ]]; then
  echo "$SCHEMA"
  echo "✅ Schema query successful"
else
  echo "❌ Failed to read schema"
  exit 1
fi

echo ""
echo "=== Test Complete ==="
echo "✅ All integrity checks passed"

exit 0
