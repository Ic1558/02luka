#!/usr/bin/env zsh
# Build Ops Mirror
# Fetches ops data from API or cache and generates static files for GitHub Pages
# Usage: ./g/tools/build_ops_mirror.zsh [--from-cache|--from-api=URL]

set -euo pipefail

OUTPUT_DIR="${PWD}/dist/ops"
CACHE_DIR="${HOME}/Library/02luka_runtime/ops"
SOURCE_MODE="api"
API_URL="https://ops.theedges.work/api/ops/latest"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-cache)
      SOURCE_MODE="cache"
      shift
      ;;
    --from-api=*)
      SOURCE_MODE="api"
      API_URL="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--from-cache|--from-api=URL]"
      exit 1
      ;;
  esac
done

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

echo "🚀 Building Ops Mirror..."
echo "📁 Output: $OUTPUT_DIR"
echo "📦 Source: $SOURCE_MODE"

# Fetch data based on mode
if [[ "$SOURCE_MODE" == "cache" ]]; then
  echo "📂 Reading from cache: $CACHE_DIR"
  
  if [[ ! -d "$CACHE_DIR" ]] || [[ -z "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]]; then
    echo "❌ Cache directory empty or missing: $CACHE_DIR"
    exit 1
  fi
  
  # Copy from cache
  if [[ -f "$CACHE_DIR/latest.json" ]]; then
    cp "$CACHE_DIR/latest.json" "$OUTPUT_DIR/latest.json"
    echo "✅ Copied latest.json from cache"
  fi
  
  if [[ -f "$CACHE_DIR/dashboard.html" ]]; then
    cp "$CACHE_DIR/dashboard.html" "$OUTPUT_DIR/dashboard.html"
    echo "✅ Copied dashboard.html from cache"
  fi
else
  echo "🌐 Fetching from API: $API_URL"
  
  # Fetch latest.json
  if curl -s -f "$API_URL" -o "$OUTPUT_DIR/latest.json"; then
    echo "✅ Fetched latest.json"
  else
    echo "⚠️  Failed to fetch latest.json from API"
    # Try cache as fallback
    if [[ -f "$CACHE_DIR/latest.json" ]]; then
      cp "$CACHE_DIR/latest.json" "$OUTPUT_DIR/latest.json"
      echo "✅ Using cached latest.json as fallback"
    else
      echo "⚠️  No API data and no cache available - continuing with manifest/health only"
      # Don't exit - allow manifest and health files to be generated
    fi
  fi
  
  # Fetch dashboard
  DASHBOARD_URL="${API_URL%/latest}/dashboard"
  if curl -s -f "$DASHBOARD_URL" -o "$OUTPUT_DIR/dashboard.html"; then
    echo "✅ Fetched dashboard.html"
  else
    echo "⚠️  Failed to fetch dashboard.html from API"
    # Try cache as fallback
    if [[ -f "$CACHE_DIR/dashboard.html" ]]; then
      cp "$CACHE_DIR/dashboard.html" "$OUTPUT_DIR/dashboard.html"
      echo "✅ Using cached dashboard.html as fallback"
    fi
  fi
fi

# Generate TSV from JSON if latest.json exists
if [[ -f "$OUTPUT_DIR/latest.json" ]]; then
  if command -v jq >/dev/null 2>&1; then
    # Convert JSON to TSV (simplified - assumes array of objects)
    jq -r 'if type == "array" then 
      (.[0] | keys_unsorted | @tsv),
      (.[] | [.[]] | flatten | @tsv)
    else
      (. | keys_unsorted | @tsv),
      (. | [.[]] | flatten | @tsv)
    end' "$OUTPUT_DIR/latest.json" > "$OUTPUT_DIR/latest.tsv" 2>/dev/null || {
      echo "⚠️  Could not convert JSON to TSV (non-fatal)"
    }
    echo "✅ Generated latest.tsv"
  fi
fi

# Generate manifest.json
MANIFEST_JSON=$(cat <<EOF
{
  "status": "ok",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source": "$SOURCE_MODE",
  "api_url": "$API_URL",
  "files": {
    "latest.json": $([ -f "$OUTPUT_DIR/latest.json" ] && echo "true" || echo "false"),
    "latest.tsv": $([ -f "$OUTPUT_DIR/latest.tsv" ] && echo "true" || echo "false"),
    "dashboard.html": $([ -f "$OUTPUT_DIR/dashboard.html" ] && echo "true" || echo "false")
  }
}
EOF
)
echo "$MANIFEST_JSON" > "$OUTPUT_DIR/manifest.json"
echo "✅ Generated manifest.json"

# Generate _health.html
HEALTH_HTML=$(cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>02luka Ops Mirror Health</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0d1117;
      color: #c9d1d9;
      padding: 40px;
      text-align: center;
    }
    h1 { color: #58a6ff; margin-bottom: 20px; }
    .status { font-size: 2em; color: #238636; margin: 20px 0; }
    .info { color: #8b949e; margin-top: 20px; }
  </style>
</head>
<body>
  <h1>02luka Ops Mirror Health</h1>
  <div class="status">✅ OPERATIONAL</div>
  <div class="info">
    <p>Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")</p>
    <p>Source: $SOURCE_MODE</p>
  </div>
</body>
</html>
EOF
)
echo "$HEALTH_HTML" > "$OUTPUT_DIR/_health.html"
echo "✅ Generated _health.html"

echo ""
echo "✨ Ops Mirror build complete!"
echo "📁 Output directory: $OUTPUT_DIR"
echo "📊 Files generated:"
ls -lh "$OUTPUT_DIR" | tail -n +2 | awk '{print "   " $9 " (" $5 ")"}'

