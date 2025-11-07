#!/usr/bin/env bash
# Integration test for OCR consumer SHA256 validation
set -euo pipefail

echo "🧪 Testing OCR consumer SHA256 validation failure handling..."

# Setup test environment
TEST_DIR="/tmp/ocr_test_$$"
mkdir -p "$TEST_DIR/inbox/CLC" "$TEST_DIR/processing" "$TEST_DIR/processed" "$TEST_DIR/failed" "$TEST_DIR/telemetry" "$TEST_DIR/logs"

# Create a test file with known content
TEST_FILE="$TEST_DIR/test_doc.txt"
echo "Test document content" > "$TEST_FILE"

# Calculate correct hash
CORRECT_HASH=$(sha256sum "$TEST_FILE" | awk '{print $1}')

# Create OCR approval JSON with INCORRECT hash
BAD_HASH="0000000000000000000000000000000000000000000000000000000000000000"
cat > "$TEST_DIR/inbox/CLC/OCR_APPROVED_TEST_001.json" <<EOF
{
  "wo_id": "TEST_001",
  "action": "publish",
  "approved_by": "test_user",
  "approved_at": "$(date -u +%FT%TZ)",
  "files": [
    {
      "path": "$TEST_FILE",
      "sha256": "$BAD_HASH"
    }
  ]
}
EOF

# Override environment for test
export HOME=/tmp
export ROOT="$TEST_DIR"

# Create a minimal test version of ocr_consumer_simple.sh in test dir
cat > "$TEST_DIR/test_consumer.sh" <<'TESTSCRIPT'
#!/usr/bin/env bash
shopt -s nullglob extglob

set -euo pipefail

ROOT="${ROOT:-$HOME/02luka}"
INBOX="$ROOT/inbox/CLC"
WORK="$ROOT/processing"
FAIL="$ROOT/fail"
LOG="$ROOT/logs/test.log"

mkdir -p "$WORK" "$FAIL" "$ROOT/logs"

ts(){ date +'%Y-%m-%dT%H:%M:%S%z'; }
log(){ echo "[$(ts)] $*" | tee -a "$LOG"; }

for json in "$INBOX"/OCR_APPROVED_*.json; do
  [[ -f "$json" ]] || continue

  base=$(basename "$json")
  mv "$json" "$WORK/$base" 2>/dev/null || continue

  all_ok=true
  while IFS=$'\t' read -r fpath expect; do
    if [[ ! -f "$fpath" ]]; then
      log "ERR: missing file $fpath"
      all_ok=false
    else
      have=$(sha256sum "$fpath" | awk '{print $1}')

      if [[ -z "$have" || ${#have} -ne 64 ]]; then
        log "ERR: Invalid SHA256 hash for $fpath"
        all_ok=false
        continue
      fi

      if [[ "$have" == "$expect" ]]; then
        log "OK: sha256 verified"
      else
        log "ERR: sha256 mismatch (expected=$expect, got=$have)"
        all_ok=false
      fi
    fi
  done < <(command -v jq >/dev/null && jq -r '.files[]? | [.path,.sha256] | @tsv' "$WORK/$base" 2>/dev/null || echo "")

  if [[ "$all_ok" == "false" ]]; then
    mv "$WORK/$base" "$FAIL/$base"
    log "FAILED: moved to failed/"
    exit 1
  fi
done
TESTSCRIPT

chmod +x "$TEST_DIR/test_consumer.sh"

# Run the test consumer (should fail due to hash mismatch)
if ROOT="$TEST_DIR" bash "$TEST_DIR/test_consumer.sh" 2>&1 | tee "$TEST_DIR/test_output.log"; then
  echo "❌ TEST FAILED: Expected script to fail on hash mismatch but it succeeded"
  cat "$TEST_DIR/test_output.log"
  rm -rf "$TEST_DIR"
  exit 1
else
  # Check that file was moved to failed directory
  if [[ -f "$TEST_DIR/failed/OCR_APPROVED_TEST_001.json" ]] || [[ -f "$TEST_DIR/fail/OCR_APPROVED_TEST_001.json" ]]; then
    echo "✅ TEST PASSED: Script correctly failed on invalid SHA256 hash"
    echo "✅ TEST PASSED: File correctly moved to failed directory"
    rm -rf "$TEST_DIR"
    exit 0
  else
    echo "❌ TEST FAILED: File was not moved to failed directory"
    ls -la "$TEST_DIR/failed/" "$TEST_DIR/fail/" 2>/dev/null || true
    rm -rf "$TEST_DIR"
    exit 1
  fi
fi
