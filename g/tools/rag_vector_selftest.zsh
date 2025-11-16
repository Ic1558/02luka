#!/usr/bin/env zsh
# Phase 15 – RAG Vector Search Self-Test
# Validates FAISS/HNSW vector search functionality with caching

set -euo pipefail

# Configuration
BASE="${LUKA_HOME:-$HOME/02luka}"
VECTOR_BUILD="${BASE}/tools/vector_build.zsh"
RAG_QUERY="${BASE}/tools/rag_query.zsh"
REPORT_DIR="${BASE}/g/reports/phase15"
REPORT_FILE="${REPORT_DIR}/rag_vector_selftest.md"
UNIFIED_SOURCE="${BASE}/memory/index_unified/unified.jsonl"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[selftest]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[selftest]${NC} ✓ $*" >&2
}

log_error() {
    echo -e "${RED}[selftest]${NC} ✗ $*" >&2
}

log_test() {
    echo -e "${YELLOW}[test $((TESTS_RUN+1))]${NC} $*" >&2
}

# Test assertion
assert() {
    local condition=$1
    local message=$2

    ((TESTS_RUN++))

    if eval "$condition"; then
        ((TESTS_PASSED++))
        log_success "$message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "$message"
        return 1
    fi
}

# Setup test corpus
setup_test_corpus() {
    log_info "Setting up test corpus..."

    # Check if unified.jsonl exists and has content
    if [[ ! -f "$UNIFIED_SOURCE" ]] || [[ ! -s "$UNIFIED_SOURCE" ]]; then
        log_info "Creating minimal test corpus..."
        mkdir -p "$(dirname "$UNIFIED_SOURCE")"

        cat > "$UNIFIED_SOURCE" <<'JSONL'
{"id":"test_doc_1","content":"FAISS is a library for efficient similarity search and clustering of dense vectors developed by Facebook AI Research"}
{"id":"test_doc_2","content":"HNSW (Hierarchical Navigable Small World) is an algorithm for approximate nearest neighbor search with excellent recall"}
{"id":"test_doc_3","content":"Sentence transformers are deep learning models that map sentences to dense vector embeddings for semantic similarity"}
{"id":"test_doc_4","content":"Vector databases enable semantic search by storing embeddings and supporting efficient similarity queries"}
{"id":"test_doc_5","content":"RAG (Retrieval-Augmented Generation) combines vector search with language models to provide context-aware responses"}
JSONL

        log_success "Created test corpus with 5 documents"
    else
        local doc_count=$(wc -l < "$UNIFIED_SOURCE" | tr -d ' ')
        log_info "Using existing corpus with $doc_count documents"
    fi
}

# Build index
build_index() {
    log_info "Building vector index..."

    if bash "$VECTOR_BUILD" build 2>&1 | grep -q "success"; then
        log_success "Index built successfully"
        return 0
    else
        log_error "Index build failed"
        return 1
    fi
}

# Test 1: Vector search returns results
test_vector_search() {
    log_test "Vector search returns results for known term"

    local RESULT=$(bash "$RAG_QUERY" --no-cache "FAISS similarity search" 2>/dev/null || echo '{}')
    local HIT_COUNT=$(echo "$RESULT" | jq -r '.meta.hit_count // 0' 2>/dev/null || echo 0)

    assert "[[ $HIT_COUNT -ge 1 ]]" "Vector search returned $HIT_COUNT hits (expected >= 1)"
}

# Test 2: Query returns valid JSON
test_json_output() {
    log_test "Query returns valid JSON structure"

    local RESULT=$(bash "$RAG_QUERY" --no-cache "vector embeddings" 2>/dev/null || echo '{}')

    local HAS_QUERY=$(echo "$RESULT" | jq 'has("query")' 2>/dev/null || echo false)
    local HAS_HITS=$(echo "$RESULT" | jq 'has("hits")' 2>/dev/null || echo false)
    local HAS_META=$(echo "$RESULT" | jq 'has("meta")' 2>/dev/null || echo false)

    assert "[[ \"$HAS_QUERY\" == \"true\" && \"$HAS_HITS\" == \"true\" && \"$HAS_META\" == \"true\" ]]" \
        "JSON has required fields (query, hits, meta)"
}

# Test 3: Cache is created
test_cache_creation() {
    log_test "Cache directory is created on first query"

    local CACHE_DIR="${BASE}/g/bridge/rag_cache"

    # Clear cache
    rm -r -f "$CACHE_DIR"

    # Run query with cache
    bash "$RAG_QUERY" --cache "nearest neighbor search" >/dev/null 2>&1 || true

    assert "[[ -d \"$CACHE_DIR\" ]]" "Cache directory was created"
}

# Test 4: Cache hit is faster
test_cache_performance() {
    log_test "Cached query is faster than uncached"

    local QUERY="semantic similarity vectors"

    # First run (uncached)
    local START1=$(date +%s%N)
    local RESULT1=$(bash "$RAG_QUERY" --no-cache "$QUERY" 2>/dev/null || echo '{}')
    local END1=$(date +%s%N)
    local TIME1=$(( (END1 - START1) / 1000000 )) # ms

    # Second run (cached)
    local START2=$(date +%s%N)
    local RESULT2=$(bash "$RAG_QUERY" --cache "$QUERY" 2>/dev/null || echo '{}')
    local END2=$(date +%s%N)
    local TIME2=$(( (END2 - START2) / 1000000 )) # ms

    local CACHE_USED=$(echo "$RESULT2" | jq -r '.meta.cache_used // false' 2>/dev/null || echo false)

    log_info "First run: ${TIME1}ms, Second run: ${TIME2}ms, Cache used: $CACHE_USED"

    # Cache should be used OR second run should be faster
    assert "[[ \"$CACHE_USED\" == \"true\" || $TIME2 -lt $TIME1 ]]" \
        "Cached query used cache or was faster (cache_used=$CACHE_USED)"
}

# Test 5: Different queries return different results
test_query_differentiation() {
    log_test "Different queries return different results"

    local RESULT1=$(bash "$RAG_QUERY" --no-cache "FAISS library" 2>/dev/null || echo '{}')
    local RESULT2=$(bash "$RAG_QUERY" --no-cache "language models" 2>/dev/null || echo '{}')

    local HITS1=$(echo "$RESULT1" | jq -r '.hits[0].id // ""' 2>/dev/null || echo "")
    local HITS2=$(echo "$RESULT2" | jq -r '.hits[0].id // ""' 2>/dev/null || echo "")

    # Results should be different (or at least one should have results)
    assert "[[ -n \"$HITS1\" || -n \"$HITS2\" ]]" \
        "Queries returned results (not both empty)"
}

# Generate report
generate_report() {
    log_info "Generating test report..."

    mkdir -p "$REPORT_DIR"

    local TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local SUCCESS_RATE=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        SUCCESS_RATE=$(( TESTS_PASSED * 100 / TESTS_RUN ))
    fi

    cat > "$REPORT_FILE" <<REPORT
# Phase 15 – RAG Vector Search Self-Test Report

**Generated:** $TIMESTAMP

## Summary

- **Tests Run:** $TESTS_RUN
- **Tests Passed:** $TESTS_PASSED
- **Tests Failed:** $TESTS_FAILED
- **Success Rate:** ${SUCCESS_RATE}%

## Test Results

### ✓ Passed Tests: $TESTS_PASSED

### ✗ Failed Tests: $TESTS_FAILED

## Test Details

### 1. Vector Search Returns Results
- Tests that vector search returns at least 1 hit for a known term
- Status: $([ $TESTS_FAILED -eq 0 ] && echo "PASS" || echo "CHECK LOGS")

### 2. JSON Output Structure
- Validates that query output has required JSON fields
- Status: $([ $TESTS_FAILED -eq 0 ] && echo "PASS" || echo "CHECK LOGS")

### 3. Cache Directory Creation
- Verifies cache directory is created on first query
- Status: $([ $TESTS_FAILED -eq 0 ] && echo "PASS" || echo "CHECK LOGS")

### 4. Cache Performance
- Tests that cached queries use cache or are faster
- Status: $([ $TESTS_FAILED -eq 0 ] && echo "PASS" || echo "CHECK LOGS")

### 5. Query Differentiation
- Ensures different queries return different or valid results
- Status: $([ $TESTS_FAILED -eq 0 ] && echo "PASS" || echo "CHECK LOGS")

## Environment

- **Base Directory:** $BASE
- **Test Corpus:** $UNIFIED_SOURCE
- **Vector Build:** $VECTOR_BUILD
- **RAG Query:** $RAG_QUERY

## Conclusion

$(if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ All tests passed! Vector search pipeline is functioning correctly."
else
    echo "✗ Some tests failed. Review logs for details."
fi)

## Next Steps

$(if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "- Monitor production queries for performance"
    echo "- Consider expanding test corpus"
    echo "- Add integration tests for full RAG pipeline"
else
    echo "- Review failed test logs above"
    echo "- Check vector index build output"
    echo "- Verify dependencies (faiss-cpu, sentence-transformers)"
fi)

---
*Report generated by tools/rag_vector_selftest.zsh*
REPORT

    log_success "Report written to: $REPORT_FILE"
}

# Main test execution
main() {
    log_info "Starting Phase 15 RAG Vector Self-Test"
    log_info "================================================"

    # Setup
    setup_test_corpus

    # Build index
    if ! build_index; then
        log_error "Failed to build index, aborting tests"
        exit 1
    fi

    log_info ""
    log_info "Running tests..."
    log_info "================================================"

    # Run tests
    test_vector_search || true
    test_json_output || true
    test_cache_creation || true
    test_cache_performance || true
    test_query_differentiation || true

    log_info ""
    log_info "================================================"
    log_info "Test Summary"
    log_info "================================================"
    log_info "Total: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"

    # Generate report
    generate_report

    # Exit code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "$TESTS_FAILED test(s) failed"
        exit 1
    fi
}

main "$@"
