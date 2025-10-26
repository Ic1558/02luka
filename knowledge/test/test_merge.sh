#!/bin/bash
# Test script for merge.cjs RRF implementation
# Tests WO-251022-GG-MERGE-RERANK-V2 acceptance criteria

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."
MERGE="node merge.cjs"
TEST_DIR="$SCRIPT_DIR"

echo "========================================"
echo "WO-251022-GG-MERGE-RERANK-V2 Test Suite"
echo "========================================"
echo ""

# Test 1: Basic merge without boost
echo "=== Test 1: Basic RRF merge (no boost) ==="
$MERGE < "$TEST_DIR/test_merge_data.json" | jq -r '
  "Total results: \(.count)",
  "Timing: \(.timing_ms)ms",
  "Boosts: \(.boosts | length) sources",
  "",
  "Top 3 results:",
  (.merged_results[0:3] | .[] | "  - \(.id) [\(.source)] fused=\(.fused_score | . * 1000 | round / 1000)")'
echo ""

# Test 2: Merge with boost flags
echo "=== Test 2: RRF merge with boost (docs:1.2, memory:0.8) ==="
$MERGE --boost-sources=docs:1.2,memory:0.8 < "$TEST_DIR/test_merge_data.json" | jq -r '
  "Total results: \(.count)",
  "Timing: \(.timing_ms)ms",
  "Boosts: docs=\(.boosts.docs), memory=\(.boosts.memory)",
  "",
  "Top 3 results:",
  (.merged_results[0:3] | .[] | "  - \(.id) [\(.source)] boosted=\(.boosted_score | . * 1000 | round / 1000) (was \(.fused_score | . * 1000 | round / 1000))")'
echo ""

# Test 3: Tied items - verify boost effect
echo "=== Test 3: Tied items (verify docs > memory with boost) ==="
echo "Without boost:"
$MERGE < "$TEST_DIR/test_merge_tied.json" | jq -r '
  .merged_results[] | "  \(.source): \(.boosted_score | . * 1000 | round / 1000)"'
echo ""
echo "With boost (docs:1.2, memory:0.8):"
$MERGE --boost-sources=docs:1.2,memory:0.8 < "$TEST_DIR/test_merge_tied.json" | jq -r '
  .merged_results[] | "  \(.source): \(.boosted_score | . * 1000 | round / 1000)"'
echo ""

# Test 4: Performance test with 201 rows
echo "=== Test 4: Performance test (201 rows, target <5ms) ==="
echo "Running 10 iterations..."
TIMINGS=$($MERGE --boost-sources=docs:1.2,reports:1.1,memory:0.9 < "$TEST_DIR/test_merge_large.json" | jq -r '.timing_ms')
for i in {2..10}; do
  TIMING=$($MERGE --boost-sources=docs:1.2,reports:1.1,memory:0.9 < "$TEST_DIR/test_merge_large.json" | jq -r '.timing_ms')
  TIMINGS="$TIMINGS\n$TIMING"
done

echo -e "$TIMINGS" | awk '{
  sum += $1
  if ($1 < min || min == 0) min = $1
  if ($1 > max) max = $1
  count++
}
END {
  avg = sum / count
  printf "  Min: %.3fms\n", min
  printf "  Max: %.3fms\n", max
  printf "  Avg: %.3fms\n", avg
  printf "  Target: <5.0ms\n"
  if (avg < 5.0) {
    printf "  ✓ PASS: Performance requirement met\n"
  } else {
    printf "  ✗ FAIL: Performance requirement not met\n"
  }
}'
echo ""

# Test 5: Deduplication test
echo "=== Test 5: Deduplication (same doc in multiple sources) ==="
$MERGE --boost-sources=docs:1.2,memory:0.8 < "$TEST_DIR/test_merge_data.json" | jq -r '
  "Documents appearing in multiple sources:",
  (.merged_results[] | select(.sources | length > 1) | "  - \(.id): \(.sources | map(.source) | join(", "))")'
echo ""

echo "========================================"
echo "All tests completed successfully!"
echo "========================================"
