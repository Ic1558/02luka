#!/usr/bin/env zsh
# Phase 15 – FAISS Vector Index Build & Management
# Build, refresh, and manage FAISS/HNSW vector indexes for RAG pipeline

set -euo pipefail

# Configuration
BASE="${LUKA_HOME:-$HOME/02luka}"
CONFIG="${BASE}/config/rag_vector.yaml"
VECTOR_INDEX_PY="${BASE}/tools/vector_index.py"
TELEMETRY_SINK="${BASE}/g/telemetry_unified/unified.jsonl"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[vector_build]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[vector_build]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[vector_build]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[vector_build]${NC} $*" >&2
}

# Emit telemetry event
emit_telemetry() {
    local event=$1
    shift
    local ts=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

    local json="{\"event\":\"$event\",\"ts\":\"$ts\",\"__source\":\"vector_build\",\"__normalized\":true"

    # Add extra fields
    for arg in "$@"; do
        json="$json,\"$arg\""
    done
    json="$json}"

    mkdir -p "$(dirname "$TELEMETRY_SINK")"
    echo "$json" >> "$TELEMETRY_SINK"
}

# Parse YAML config
parse_yaml() {
    local key=$1
    if command -v yq >/dev/null 2>&1; then
        yq eval "$key" "$CONFIG" 2>/dev/null || echo ""
    else
        # Fallback: simple grep-based parsing
        grep "^${key##*.}:" "$CONFIG" | sed 's/^[^:]*: *//' | tr -d '"' || echo ""
    fi
}

# Get config values
get_config() {
    local key=$1
    local default=$2

    case "$key" in
        index_path)
            local val=$(parse_yaml '.index_path')
            ;;
        mapping_path)
            local val=$(parse_yaml '.mapping_path')
            ;;
        model)
            local val=$(parse_yaml '.model')
            ;;
        dim)
            local val=$(parse_yaml '.dim')
            ;;
        source)
            local val=$(parse_yaml '.build.source')
            ;;
        text_field)
            local val=$(parse_yaml '.build.text_field')
            ;;
        id_field)
            local val=$(parse_yaml '.build.id_field')
            ;;
        M)
            local val=$(parse_yaml '.build.hnsw.M')
            ;;
        ef_construction)
            local val=$(parse_yaml '.build.hnsw.ef_construction')
            ;;
        *)
            local val=""
            ;;
    esac

    echo "${val:-$default}"
}

# Build command
cmd_build() {
    log_info "Starting FAISS index build..."

    # Check config exists
    if [[ ! -f "$CONFIG" ]]; then
        log_error "Config not found: $CONFIG"
        emit_telemetry "rag.index.error" "error_type:\"missing_config\""
        exit 78
    fi

    # Get config values
    local INDEX_PATH="${BASE}/$(get_config index_path 'artifacts/vector/faiss.index')"
    local MAPPING_PATH="${BASE}/$(get_config mapping_path 'artifacts/vector/mapping.json')"
    local SOURCE="${BASE}/$(get_config source 'memory/index_unified/unified.jsonl')"
    local MODEL=$(get_config model 'sentence-transformers/all-MiniLM-L6-v2')
    local DIM=$(get_config dim '384')
    local TEXT_FIELD=$(get_config text_field 'content')
    local ID_FIELD=$(get_config id_field 'id')
    local M=$(get_config M '32')
    local EF_CONSTRUCTION=$(get_config ef_construction '200')

    log_info "Config loaded:"
    log_info "  Source: $SOURCE"
    log_info "  Index: $INDEX_PATH"
    log_info "  Model: $MODEL"
    log_info "  Dim: $DIM"

    # Check source exists
    if [[ ! -f "$SOURCE" ]]; then
        log_error "Source file not found: $SOURCE"
        emit_telemetry "rag.index.error" "error_type:\"missing_source\""
        exit 66
    fi

    # Count documents
    local DOC_COUNT=$(wc -l < "$SOURCE" | tr -d ' ')
    log_info "Documents in source: $DOC_COUNT"

    if [[ "$DOC_COUNT" -eq 0 ]]; then
        log_warn "Source file is empty, creating minimal corpus..."
        # Create minimal corpus for testing
        mkdir -p "$(dirname "$SOURCE")"
        cat > "$SOURCE" <<'JSONL'
{"id":"doc1","content":"Vector search with FAISS enables efficient similarity search in high-dimensional spaces"}
{"id":"doc2","content":"HNSW algorithm provides approximate nearest neighbor search with high recall"}
{"id":"doc3","content":"Sentence transformers generate embeddings for semantic text similarity"}
JSONL
        DOC_COUNT=3
        log_info "Created minimal corpus with $DOC_COUNT documents"
    fi

    # Emit start event
    local START_TS=$(date +%s)
    emit_telemetry "rag.index.start" "doc_count:$DOC_COUNT" "model:\"$MODEL\""

    # Create output directory
    mkdir -p "$(dirname "$INDEX_PATH")"

    # Build index
    log_info "Building index with Python script..."
    local BUILD_OUTPUT
    if BUILD_OUTPUT=$(python3 "$VECTOR_INDEX_PY" build \
        --source "$SOURCE" \
        --index "$INDEX_PATH" \
        --mapping "$MAPPING_PATH" \
        --model "$MODEL" \
        --dim "$DIM" \
        --text-field "$TEXT_FIELD" \
        --id-field "$ID_FIELD" \
        --index-type hnsw \
        --M "$M" \
        --ef-construction "$EF_CONSTRUCTION" 2>&1); then

        log_success "Index built successfully"
        echo "$BUILD_OUTPUT" | head -20

        # Parse result
        local STATUS=$(echo "$BUILD_OUTPUT" | jq -r '.status' 2>/dev/null || echo "unknown")
        local COUNT=$(echo "$BUILD_OUTPUT" | jq -r '.count' 2>/dev/null || echo "0")

        # Generate manifest
        local MANIFEST_PATH="${INDEX_PATH%/*}/manifest.json"
        local INDEX_SHA256=$(sha256sum "$INDEX_PATH" | awk '{print $1}')
        local MAPPING_SHA256=$(sha256sum "$MAPPING_PATH" | awk '{print $1}')
        local END_TS=$(date +%s)
        local BUILD_TIME=$((END_TS - START_TS))

        cat > "$MANIFEST_PATH" <<JSON
{
  "version": "1.0",
  "build_timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "build_time_seconds": $BUILD_TIME,
  "source": "$SOURCE",
  "source_doc_count": $DOC_COUNT,
  "indexed_count": $COUNT,
  "model": "$MODEL",
  "dim": $DIM,
  "hnsw_M": $M,
  "hnsw_ef_construction": $EF_CONSTRUCTION,
  "index_sha256": "$INDEX_SHA256",
  "mapping_sha256": "$MAPPING_SHA256",
  "index_path": "$INDEX_PATH",
  "mapping_path": "$MAPPING_PATH"
}
JSON

        log_success "Manifest written to: $MANIFEST_PATH"

        # Emit success event
        emit_telemetry "rag.index.end" \
            "status:\"success\"" \
            "count:$COUNT" \
            "build_time_s:$BUILD_TIME"

        return 0
    else
        log_error "Index build failed"
        echo "$BUILD_OUTPUT"

        # Emit error event
        emit_telemetry "rag.index.error" \
            "error_type:\"build_failed\"" \
            "output:\"$(echo "$BUILD_OUTPUT" | head -1 | sed 's/"/\\"/g')\""

        return 1
    fi
}

# Status command
cmd_status() {
    log_info "Checking index status..."

    if [[ ! -f "$CONFIG" ]]; then
        log_error "Config not found: $CONFIG"
        exit 78
    fi

    local INDEX_PATH="${BASE}/$(get_config index_path 'artifacts/vector/faiss.index')"
    local MAPPING_PATH="${BASE}/$(get_config mapping_path 'artifacts/vector/mapping.json')"
    local MANIFEST_PATH="${INDEX_PATH%/*}/manifest.json"

    # Get stats from Python
    if [[ -f "$VECTOR_INDEX_PY" ]]; then
        log_info "Index statistics:"
        python3 "$VECTOR_INDEX_PY" stats \
            --index "$INDEX_PATH" \
            --mapping "$MAPPING_PATH" 2>/dev/null || true
    fi

    # Show manifest if exists
    if [[ -f "$MANIFEST_PATH" ]]; then
        log_info ""
        log_info "Build manifest:"
        cat "$MANIFEST_PATH"
    else
        log_warn "No manifest found at: $MANIFEST_PATH"
    fi

    # Show file info
    log_info ""
    log_info "File information:"
    if [[ -f "$INDEX_PATH" ]]; then
        local SIZE=$(du -h "$INDEX_PATH" | cut -f1)
        local MODIFIED=$(date -r "$INDEX_PATH" "+%Y-%m-%d %H:%M:%S")
        log_info "  Index: $SIZE (modified: $MODIFIED)"
    else
        log_warn "  Index: NOT FOUND"
    fi

    if [[ -f "$MAPPING_PATH" ]]; then
        local SIZE=$(du -h "$MAPPING_PATH" | cut -f1)
        local MODIFIED=$(date -r "$MAPPING_PATH" "+%Y-%m-%d %H:%M:%S")
        log_info "  Mapping: $SIZE (modified: $MODIFIED)"
    else
        log_warn "  Mapping: NOT FOUND"
    fi
}

# Clean command
cmd_clean() {
    log_info "Cleaning vector artifacts..."

    if [[ ! -f "$CONFIG" ]]; then
        log_error "Config not found: $CONFIG"
        exit 78
    fi

    local INDEX_PATH="${BASE}/$(get_config index_path 'artifacts/vector/faiss.index')"
    local MAPPING_PATH="${BASE}/$(get_config mapping_path 'artifacts/vector/mapping.json')"
    local MANIFEST_PATH="${INDEX_PATH%/*}/manifest.json"

    local REMOVED=0

    if [[ -f "$INDEX_PATH" ]]; then
        rm -f "$INDEX_PATH"
        log_success "Removed: $INDEX_PATH"
        ((REMOVED++))
    fi

    if [[ -f "$MAPPING_PATH" ]]; then
        rm -f "$MAPPING_PATH"
        log_success "Removed: $MAPPING_PATH"
        ((REMOVED++))
    fi

    if [[ -f "$MANIFEST_PATH" ]]; then
        rm -f "$MANIFEST_PATH"
        log_success "Removed: $MANIFEST_PATH"
        ((REMOVED++))
    fi

    if [[ $REMOVED -eq 0 ]]; then
        log_info "No artifacts to clean"
    else
        log_success "Cleaned $REMOVED file(s)"
    fi

    emit_telemetry "rag.index.clean" "removed:$REMOVED"
}

# Usage
usage() {
    cat <<USAGE
Usage: $(basename "$0") <command>

Commands:
    build    Build/refresh FAISS index from config
    status   Show index statistics and status
    clean    Remove index and mapping files

Environment:
    LUKA_HOME    Base directory (default: \$HOME/02luka)

Configuration:
    Reads from: config/rag_vector.yaml
USAGE
}

# Main
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 64
    fi

    local CMD=$1
    shift

    case "$CMD" in
        build)
            cmd_build "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        clean)
            cmd_clean "$@"
            ;;
        help|--help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown command: $CMD"
            usage
            exit 64
            ;;
    esac
}

main "$@"
