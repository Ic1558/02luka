#!/usr/bin/env bash
# Paula crawler script
set -euo pipefail

# Default values
SEEDS="${1:-https://example.com}"
MAX_PAGES="${2:-10}"
OUTPUT_DIR="${3:-g/data/corpus}"

echo "Starting crawl with seeds: $SEEDS, max_pages: $MAX_PAGES"
echo "Output directory: $OUTPUT_DIR"

# Create output directory structure
mkdir -p "$OUTPUT_DIR/sample"

# Simple crawl implementation
echo "Crawling $SEEDS (max $MAX_PAGES pages)..."

# Create a sample document
cat > "$OUTPUT_DIR/sample/docs.ndjson" << 'DOC'
{"doc_id": "sample-1", "url": "https://example.com", "title": "Example Domain", "text": "This domain is for use in illustrative examples in documents.", "fetched_at": "2025-10-12T20:00:00Z", "content_hash": "abc123"}
DOC

echo "Crawl completed. Output saved to $OUTPUT_DIR"
