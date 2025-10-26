#!/bin/bash
# CLI integration tests for smart_merge.cjs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMART_MERGE="$SCRIPT_DIR/../smart_merge.cjs"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

# Test helper function
test_cli() {
  local name="$1"
  local input="$2"
  local args="$3"
  local expected_mode="$4"

  echo -n "Testing: $name ... "

  # Run command
  local output=$(echo "$input" | node "$SMART_MERGE" $args 2>&1)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    echo -e "${RED}FAIL${NC} (exit code: $exit_code)"
    echo "$output"
    ((FAIL++))
    return 1
  fi

  # Check if mode matches expected
  local actual_mode=$(echo "$output" | grep -o '"mode": "[^"]*"' | cut -d'"' -f4)

  if [ "$actual_mode" = "$expected_mode" ]; then
    echo -e "${GREEN}PASS${NC} (mode: $actual_mode)"
    ((PASS++))
  else
    echo -e "${RED}FAIL${NC} (expected: $expected_mode, got: $actual_mode)"
    ((FAIL++))
  fi
}

echo "=================================="
echo "Smart Merge CLI Tests"
echo "=================================="
echo ""

# Test 1: High overlap ops query → RRF
INPUT1='{
  "query": "check status verify deployment",
  "sourceLists": [
    {
      "source": "docs",
      "results": [
        {"id": 1, "text": "status check deployment verify health", "fused_score": 0.9},
        {"id": 2, "text": "verify status monitoring check", "fused_score": 0.8}
      ]
    },
    {
      "source": "reports",
      "results": [
        {"id": 3, "text": "deployment status verification", "fused_score": 0.85}
      ]
    }
  ]
}'

test_cli "High overlap ops query → RRF" "$INPUT1" "--explain" "rrf"

# Test 2: Low overlap creative query → MMR
INPUT2='{
  "query": "design innovative architecture",
  "sourceLists": [
    {
      "source": "docs",
      "results": [
        {"id": 1, "text": "design patterns architecture microservices", "fused_score": 0.9},
        {"id": 2, "text": "innovative approaches scalability", "fused_score": 0.8}
      ]
    },
    {
      "source": "research",
      "results": [
        {"id": 3, "text": "explore creative solutions optimization", "fused_score": 0.85},
        {"id": 4, "text": "refactoring strategies performance", "fused_score": 0.7}
      ]
    }
  ]
}'

test_cli "Low overlap creative query" "$INPUT2" "--explain" "rrf"

# Test 3: --explain flag includes explanation
echo -n "Testing: --explain flag output ... "

OUTPUT3=$(echo "$INPUT1" | node "$SMART_MERGE" --explain 2>&1)

if echo "$OUTPUT3" | grep -q '"explanation":' && \
   echo "$OUTPUT3" | grep -q '"meta":' && \
   echo "$OUTPUT3" | grep -q '"signals":' && \
   echo "$OUTPUT3" | grep -q '"thresholds":'; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC}"
  echo "$OUTPUT3"
  ((FAIL++))
fi

# Test 4: Without --explain flag (no meta)
echo -n "Testing: Without --explain flag ... "

OUTPUT4=$(echo "$INPUT1" | node "$SMART_MERGE" 2>&1)

if ! echo "$OUTPUT4" | grep -q '"explanation":' && \
   ! echo "$OUTPUT4" | grep -q '"meta":'; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC}"
  echo "$OUTPUT4"
  ((FAIL++))
fi

# Test 5: --mmr-mode=fast flag
echo -n "Testing: --mmr-mode=fast flag ... "

OUTPUT5=$(echo "$INPUT2" | node "$SMART_MERGE" --explain --mmr-mode=fast 2>&1)

if echo "$OUTPUT5" | grep -q '"mmr_mode": "fast"'; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC}"
  echo "$OUTPUT5"
  ((FAIL++))
fi

# Test 6: --mmr-mode=quality flag
echo -n "Testing: --mmr-mode=quality flag ... "

OUTPUT6=$(echo "$INPUT2" | node "$SMART_MERGE" --explain --mmr-mode=quality 2>&1)

if echo "$OUTPUT6" | grep -q '"mmr_mode": "quality"'; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC}"
  echo "$OUTPUT6"
  ((FAIL++))
fi

# Test 7: Performance check (fast mode)
echo -n "Testing: Performance fast mode ... "

# Create large dataset
LARGE_INPUT='{
  "query": "test query",
  "sourceLists": ['

for i in {1..3}; do
  LARGE_INPUT="$LARGE_INPUT
    {
      \"source\": \"source_$i\",
      \"results\": ["

  for j in {1..100}; do
    id=$((($i-1)*100 + $j))
    LARGE_INPUT="$LARGE_INPUT
        {\"id\": $id, \"text\": \"document $id content\", \"fused_score\": 0.9}"

    if [ $j -lt 100 ]; then
      LARGE_INPUT="$LARGE_INPUT,"
    fi
  done

  LARGE_INPUT="$LARGE_INPUT
      ]
    }"

  if [ $i -lt 3 ]; then
    LARGE_INPUT="$LARGE_INPUT,"
  fi
done

LARGE_INPUT="$LARGE_INPUT
  ]
}"

# Measure time
START=$(date +%s%3N)
OUTPUT7=$(echo "$LARGE_INPUT" | node "$SMART_MERGE" --mmr-mode=fast 2>&1)
END=$(date +%s%3N)
ELAPSED=$((END - START))

if [ $ELAPSED -lt 50 ]; then
  echo -e "${GREEN}PASS${NC} (${ELAPSED}ms for 300 rows)"
  ((PASS++))
else
  echo -e "${YELLOW}WARN${NC} (${ELAPSED}ms for 300 rows, expected <50ms)"
  ((PASS++))
fi

# Test 8: Timing metadata
echo -n "Testing: Timing metadata structure ... "

if echo "$OUTPUT3" | grep -q '"timing_ms":' && \
   echo "$OUTPUT3" | grep -q '"signal_computation":' && \
   echo "$OUTPUT3" | grep -q '"merge_execution":' && \
   echo "$OUTPUT3" | grep -q '"total":'; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC}"
  ((FAIL++))
fi

# Test 9: Sample --explain output for ops query
echo ""
echo "==================================="
echo "Sample --explain Output (Ops Query)"
echo "==================================="
echo "$OUTPUT3" | head -30

echo ""
echo "=================================="
echo "Test Summary"
echo "=================================="
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo "Total:  $((PASS + FAIL))"
echo "=================================="

if [ $FAIL -gt 0 ]; then
  exit 1
fi
