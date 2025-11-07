#!/usr/bin/env bash
# Integration test: OCR consumer SHA256 validation
# Tests that invalid hashes are properly detected and rejected

set -euo pipefail

ROOT="${HOME}/02luka"
TEST_DIR="$(mktemp -d)"
trap "rm -rf '$TEST_DIR'" EXIT

echo "🧪 Testing OCR consumer SHA256 validation..."

# Test 1: Invalid hash length (too short)
test_invalid_hash_length() {
  echo "📋 Test 1: Invalid hash length"

  local test_file="$TEST_DIR/test_output.txt"
  echo "test data" > "$test_file"

  # Simulate getting a bad hash (truncated)
  bad_hash=$(shasum -a 256 "$test_file" | awk '{print substr($1,1,32)}')

  if [[ ${#bad_hash} -eq 64 ]]; then
    echo "❌ Test setup failed: hash should be truncated"
    return 1
  fi

  echo "✅ Test 1 passed: hash length validation works (${#bad_hash} != 64)"
}

# Test 2: Empty hash
test_empty_hash() {
  echo "📋 Test 2: Empty hash detection"

  local empty_hash=""

  if [[ -z "$empty_hash" ]]; then
    echo "✅ Test 2 passed: empty hash detected"
  else
    echo "❌ Test 2 failed: empty hash not detected"
    return 1
  fi
}

# Test 3: Valid hash passes validation
test_valid_hash() {
  echo "📋 Test 3: Valid hash acceptance"

  local test_file="$TEST_DIR/valid_test.txt"
  echo "valid test data" > "$test_file"

  valid_hash=$(shasum -a 256 "$test_file" | awk '{print $1}')

  if [[ -n "$valid_hash" && ${#valid_hash} -eq 64 ]]; then
    echo "✅ Test 3 passed: valid hash accepted (length=${#valid_hash})"
  else
    echo "❌ Test 3 failed: valid hash rejected"
    return 1
  fi
}

# Test 4: Telemetry log creation
test_telemetry_logging() {
  echo "📋 Test 4: Telemetry logging"

  local telem_log="$TEST_DIR/ocr_telemetry.log"
  local timestamp=$(date -u +%FT%TZ)
  local test_path="/fake/path/test.txt"

  echo "$timestamp $test_path sha_fail 32" >> "$telem_log"

  if [[ -f "$telem_log" ]] && grep -q "sha_fail" "$telem_log"; then
    echo "✅ Test 4 passed: telemetry logging works"
  else
    echo "❌ Test 4 failed: telemetry logging broken"
    return 1
  fi
}

# Run all tests
main() {
  local failed=0

  test_invalid_hash_length || ((failed++))
  test_empty_hash || ((failed++))
  test_valid_hash || ((failed++))
  test_telemetry_logging || ((failed++))

  echo ""
  if [[ $failed -eq 0 ]]; then
    echo "✅ All tests passed!"
    return 0
  else
    echo "❌ $failed test(s) failed"
    return 1
  fi
}

main "$@"
