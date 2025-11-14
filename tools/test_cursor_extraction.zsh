#!/usr/bin/env zsh
# Test Cursor Conversation Extraction
# Phase 1: Investigation & Schema Discovery
set -euo pipefail

BASE="$HOME/02luka"
CURSOR_STORAGE="$HOME/Library/Application Support/Cursor/User/workspaceStorage"
TARGET_WORKSPACE="$HOME/02luka"

echo "=== Phase 1: Cursor SQLite Schema Investigation ==="
echo ""

# Step 1: Locate all workspace storage directories
echo "1. Locating workspace storage directories..."
if [[ ! -d "$CURSOR_STORAGE" ]]; then
  echo "   ❌ Cursor storage directory not found: $CURSOR_STORAGE"
  exit 1
fi

WORKSPACE_DIRS=($(find "$CURSOR_STORAGE" -type d -maxdepth 1 2>/dev/null | grep -v "^$CURSOR_STORAGE$" || true))
echo "   ✅ Found ${#WORKSPACE_DIRS[@]} workspace directories"
for dir in "${WORKSPACE_DIRS[@]}"; do
  echo "      - $(basename "$dir")"
done
echo ""

# Step 2: Workspace Detection - Map hash to workspace path
echo "2. Mapping workspace hash to workspace path..."
TARGET_DB=""
for ws_dir in "${WORKSPACE_DIRS[@]}"; do
  ws_hash=$(basename "$ws_dir")
  db_file="$ws_dir/state.vscdb"
  
  if [[ ! -f "$db_file" ]]; then
    continue
  fi
  
  echo "   Checking workspace: $ws_hash"
  
  # Try to find workspace path in database
  if command -v sqlite3 >/dev/null 2>&1; then
    # Check for workspace metadata
    workspace_path=$(sqlite3 "$db_file" "SELECT value FROM ItemTable WHERE key LIKE '%workspace%' OR key LIKE '%folder%' LIMIT 1;" 2>/dev/null | head -1 || echo "")
    
    # Also check for any path references
    if [[ -z "$workspace_path" ]]; then
      workspace_path=$(sqlite3 "$db_file" "SELECT value FROM ItemTable WHERE value LIKE '%02luka%' LIMIT 1;" 2>/dev/null | head -1 || echo "")
    fi
    
    if [[ -n "$workspace_path" ]] && [[ "$workspace_path" == *"02luka"* ]]; then
      echo "      ✅ Found 02luka workspace: $ws_hash"
      TARGET_DB="$db_file"
      break
    fi
  fi
  
  # Fallback: Check if workspace.json exists
  if [[ -f "$ws_dir/workspace.json" ]]; then
    if grep -q "02luka" "$ws_dir/workspace.json" 2>/dev/null; then
      echo "      ✅ Found 02luka workspace via workspace.json: $ws_hash"
      TARGET_DB="$db_file"
      break
    fi
  fi
done

if [[ -z "$TARGET_DB" ]]; then
  echo "   ⚠️  Could not identify 02luka workspace, using most recent state.vscdb"
  TARGET_DB=$(find "$CURSOR_STORAGE" -name "state.vscdb" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- || echo "")
fi

if [[ -z "$TARGET_DB" ]] || [[ ! -f "$TARGET_DB" ]]; then
  echo "   ❌ No state.vscdb found"
  exit 1
fi

echo "   ✅ Target database: $TARGET_DB"
echo ""

# Step 3: Inspect SQLite schema
echo "3. Inspecting SQLite schema..."
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "   ❌ sqlite3 not available"
  exit 1
fi

echo "   Tables:"
sqlite3 "$TARGET_DB" ".tables" 2>/dev/null | tr ' ' '\n' | grep -v '^$' | while read table; do
  echo "      - $table"
done
echo ""

echo "   ItemTable schema:"
sqlite3 "$TARGET_DB" "PRAGMA table_info(ItemTable);" 2>/dev/null || echo "      ⚠️  Could not read ItemTable schema"
echo ""

# Step 4: Look for conversation-related keys
echo "4. Searching for conversation-related keys..."
CONV_KEYS=$(sqlite3 "$TARGET_DB" "SELECT DISTINCT key FROM ItemTable WHERE key LIKE '%chat%' OR key LIKE '%conversation%' OR key LIKE '%composer%' OR key LIKE '%message%' LIMIT 20;" 2>/dev/null || echo "")
if [[ -n "$CONV_KEYS" ]]; then
  echo "$CONV_KEYS" | while read key; do
    echo "      - $key"
  done
else
  echo "      ⚠️  No conversation-related keys found"
fi
echo ""

# Step 5: Sample data extraction
echo "5. Sample data extraction..."
SAMPLE=$(sqlite3 "$TARGET_DB" "SELECT key, substr(value, 1, 100) FROM ItemTable WHERE key LIKE '%composer%' OR key LIKE '%chat%' LIMIT 3;" 2>/dev/null || echo "")
if [[ -n "$SAMPLE" ]]; then
  echo "$SAMPLE" | while IFS='|' read key value; do
    echo "      Key: $key"
    echo "      Value (first 100 chars): ${value:0:100}..."
    echo ""
  done
else
  echo "      ⚠️  No sample data found"
fi

echo ""
echo "=== Phase 1 Investigation Complete ==="
echo "Target DB: $TARGET_DB"
