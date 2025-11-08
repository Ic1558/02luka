#!/usr/bin/env zsh
# Phase 15 – RAG Query with Vector Search (FAISS/HNSW)
# Supports vector search with caching and ripgrep fallback

set -euo pipefail

# Configuration
BASE="${LUKA_HOME:-$HOME/02luka}"
VECTOR_CONFIG="${BASE}/config/rag_vector.yaml"
LEGACY_CONFIG="${BASE}/config/rag_pipeline.yaml"
TELEMETRY_DIR="${BASE}/telemetry_unified/rag"
TELEMETRY_SINK="${BASE}/g/telemetry_unified/unified.jsonl"
VECTOR_INDEX_PY="${BASE}/tools/vector_index.py"
VECTOR_BUILD="${BASE}/tools/vector_build.zsh"

# Parse flags
USE_CACHE=1
BUILD_IF_MISSING=0
FORCE_FALLBACK=0

# Parse YAML config
parse_yaml() {
    local key=$1
    local config=$2
    if command -v yq >/dev/null 2>&1; then
        yq eval "$key" "$config" 2>/dev/null || echo ""
    else
        # Fallback: simple grep-based parsing
        grep "^${key##*.}:" "$config" | sed 's/^[^:]*: *//' | tr -d '"' || echo ""
    fi
}

# Get config values
get_config() {
    local key=$1
    local default=$2

    case "$key" in
        index_path)
            local val=$(parse_yaml '.index_path' "$VECTOR_CONFIG")
            ;;
        mapping_path)
            local val=$(parse_yaml '.mapping_path' "$VECTOR_CONFIG")
            ;;
        model)
            local val=$(parse_yaml '.model' "$VECTOR_CONFIG")
            ;;
        top_k)
            local val=$(parse_yaml '.query.top_k' "$VECTOR_CONFIG")
            ;;
        ef_search)
            local val=$(parse_yaml '.query.ef_search' "$VECTOR_CONFIG")
            ;;
        min_score)
            local val=$(parse_yaml '.query.min_score' "$VECTOR_CONFIG")
            ;;
        cache_dir)
            local val=$(parse_yaml '.cache_dir' "$VECTOR_CONFIG")
            ;;
        *)
            local val=""
            ;;
    esac

    echo "${val:-$default}"
}

# Emit telemetry event
emit_telemetry() {
    local event=$1
    shift
    local ts=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

    local json="{\"event\":\"$event\",\"ts\":\"$ts\",\"__source\":\"rag_query\",\"__normalized\":true"

    # Add extra fields
    for arg in "$@"; do
        json="$json,\"$arg\""
    done
    json="$json}"

    mkdir -p "$(dirname "$TELEMETRY_SINK")"
    echo "$json" >> "$TELEMETRY_SINK"
}

# Generate cache key
cache_key() {
    local query=$1
    local top_k=$2
    echo -n "${query}|${top_k}" | tr '[:upper:]' '[:lower:]' | sha256sum | awk '{print $1}'
}

# Parse arguments
QUERY_TEXT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-cache)
            USE_CACHE=0
            shift
            ;;
        --cache)
            USE_CACHE=1
            shift
            ;;
        --build-if-missing)
            BUILD_IF_MISSING=1
            shift
            ;;
        --force-fallback)
            FORCE_FALLBACK=1
            shift
            ;;
        --help|-h)
            cat <<USAGE
Usage: $(basename "$0") [options] "query text"

Options:
    --cache             Enable caching (default)
    --no-cache          Disable caching
    --build-if-missing  Build index if it doesn't exist
    --force-fallback    Use ripgrep fallback instead of vector search
    -h, --help          Show this help

Environment:
    LUKA_HOME           Base directory (default: \$HOME/02luka)
USAGE
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 64
            ;;
        *)
            QUERY_TEXT="$*"
            break
            ;;
    esac
done

if [[ -z "$QUERY_TEXT" ]]; then
    echo "Usage: $(basename "$0") \"question...\"" >&2
    echo "Try --help for more information" >&2
    exit 64
fi

# Setup telemetry
mkdir -p "${TELEMETRY_DIR}"
mkdir -p "$(dirname "$TELEMETRY_SINK")"

zmodload zsh/datetime
START_TIME=${EPOCHREALTIME}

# Get config
INDEX_PATH="${BASE}/$(get_config index_path 'artifacts/vector/faiss.index')"
MAPPING_PATH="${BASE}/$(get_config mapping_path 'artifacts/vector/mapping.json')"
TOP_K=$(get_config top_k '24')
EF_SEARCH=$(get_config ef_search '50')
MIN_SCORE=$(get_config min_score '0.15')
CACHE_DIR="${BASE}/$(get_config cache_dir 'g/bridge/rag_cache')"

# Emit start event
emit_telemetry "rag.ctx.start" "query:\"$(echo "$QUERY_TEXT" | sed 's/"/\\"/g')\"" "top_k:$TOP_K"

# Vector search function
vector_search() {
    local query=$1
    local output_file=$2

    python3 "$VECTOR_INDEX_PY" query \
        --index "$INDEX_PATH" \
        --mapping "$MAPPING_PATH" \
        --query "$query" \
        --top-k "$TOP_K" \
        --ef-search "$EF_SEARCH" \
        --min-score "$MIN_SCORE" > "$output_file" 2>&1
}

# Ripgrep fallback function
ripgrep_fallback() {
    local query=$1

    echo "rag.ctx.fallback: using ripgrep demo (vector index not available)" >&2
    emit_telemetry "rag.ctx.fallback" "reason:\"missing_index\""

    # Simple ripgrep-based search (demo mode)
    local RESULTS='[]'
    if command -v rg >/dev/null 2>&1; then
        # Search in docs or README files
        if [[ -d "${BASE}/docs" ]]; then
            RESULTS=$(rg -i "$query" "${BASE}/docs" --max-count 5 2>/dev/null | head -10 || echo "")
        elif [[ -f "${BASE}/README.md" ]]; then
            RESULTS=$(rg -i "$query" "${BASE}/README.md" --max-count 5 2>/dev/null | head -10 || echo "")
        fi
    fi

    echo "$RESULTS"
}

# Check cache
CACHE_KEY=$(cache_key "$QUERY_TEXT" "$TOP_K")
CACHE_FILE="${CACHE_DIR}/${CACHE_KEY}.json"
CACHE_USED=0

if [[ $USE_CACHE -eq 1 && -f "$CACHE_FILE" ]]; then
    # Cache hit
    CACHE_USED=1
    RESULTS=$(cat "$CACHE_FILE")

    END_TIME=${EPOCHREALTIME}
    LATENCY=$(python3 -c "print(int(($END_TIME - $START_TIME) * 1000))")

    emit_telemetry "rag.ctx.hit" \
        "query:\"$(echo "$QUERY_TEXT" | sed 's/"/\\"/g')\"" \
        "latency_ms:$LATENCY" \
        "cache_used:true"

else
    # Cache miss - perform search
    CACHE_USED=0

    # Check if vector index exists
    if [[ $FORCE_FALLBACK -eq 0 && -f "$INDEX_PATH" && -f "$MAPPING_PATH" ]]; then
        # Use vector search
        TMPFILE=$(mktemp)
        if vector_search "$QUERY_TEXT" "$TMPFILE"; then
            # Format results as JSON array
            RESULTS=$(cat "$TMPFILE" | jq -s '.')
            rm -f "$TMPFILE"

            HIT_COUNT=$(echo "$RESULTS" | jq 'length')

            END_TIME=${EPOCHREALTIME}
            LATENCY=$(python3 -c "print(int(($END_TIME - $START_TIME) * 1000))")

            emit_telemetry "rag.ctx.miss" \
                "query:\"$(echo "$QUERY_TEXT" | sed 's/"/\\"/g')\"" \
                "hit_count:$HIT_COUNT" \
                "latency_ms:$LATENCY" \
                "cache_used:false"

        else
            # Vector search failed, use fallback
            RESULTS=$(ripgrep_fallback "$QUERY_TEXT")
            HIT_COUNT=0
            END_TIME=${EPOCHREALTIME}
            LATENCY=$(python3 -c "print(int(($END_TIME - $START_TIME) * 1000))")
        fi

    elif [[ $BUILD_IF_MISSING -eq 1 ]]; then
        # Build index if requested
        echo "rag.ctx: building missing index..." >&2
        if bash "$VECTOR_BUILD" build >&2; then
            echo "rag.ctx: index built, retrying query..." >&2
            # Retry with vector search
            TMPFILE=$(mktemp)
            if vector_search "$QUERY_TEXT" "$TMPFILE"; then
                RESULTS=$(cat "$TMPFILE" | jq -s '.')
                rm -f "$TMPFILE"
                HIT_COUNT=$(echo "$RESULTS" | jq 'length')
            else
                RESULTS=$(ripgrep_fallback "$QUERY_TEXT")
                HIT_COUNT=0
            fi
        else
            echo "rag.ctx: build failed, using fallback..." >&2
            RESULTS=$(ripgrep_fallback "$QUERY_TEXT")
            HIT_COUNT=0
        fi

        END_TIME=${EPOCHREALTIME}
        LATENCY=$(python3 -c "print(int(($END_TIME - $START_TIME) * 1000))")

    else
        # Use fallback
        RESULTS=$(ripgrep_fallback "$QUERY_TEXT")
        HIT_COUNT=0

        END_TIME=${EPOCHREALTIME}
        LATENCY=$(python3 -c "print(int(($END_TIME - $START_TIME) * 1000))")
    fi

    # Cache results if enabled
    if [[ $USE_CACHE -eq 1 ]]; then
        mkdir -p "$CACHE_DIR"
        echo "$RESULTS" > "$CACHE_FILE"
    fi
fi

# Generate answer (stub)
ANSWER="(Vector search completed for: ${QUERY_TEXT})"

# Generate context preview
if [[ "$RESULTS" == "[]" || -z "$RESULTS" ]]; then
    CONTEXT_PREVIEW="No results found"
    HIT_COUNT=0
else
    CONTEXT_PREVIEW=$(echo "$RESULTS" | jq -r '.[0:3] | .[] | .text // .content // "N/A"' 2>/dev/null | head -3 | paste -sd '; ' || echo "Results available")
    HIT_COUNT=$(echo "$RESULTS" | jq 'length' 2>/dev/null || echo 0)
fi

# Emit final events
emit_telemetry "rag.ctx.answer" \
    "query:\"$(echo "$QUERY_TEXT" | sed 's/"/\\"/g')\"" \
    "hit_count:$HIT_COUNT" \
    "cache_used:$CACHE_USED"

emit_telemetry "rag.ctx.end" \
    "latency_ms:$LATENCY" \
    "cache_used:$CACHE_USED"

# Output JSON response
OUTPUT=$(cat <<JSON
{
  "query": "$QUERY_TEXT",
  "hits": $RESULTS,
  "context_preview": "$CONTEXT_PREVIEW",
  "answer": "$ANSWER",
  "meta": {
    "latency_ms": $LATENCY,
    "hit_count": $HIT_COUNT,
    "cache_used": $CACHE_USED,
    "top_k": $TOP_K
  }
}
JSON
)

echo "$OUTPUT"
