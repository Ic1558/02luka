#!/usr/bin/env zsh
# Query Cursor Chat History from SQLite Database
# Usage: query_cursor_chat_history.zsh [workspace-hash] [--composers|--prompts|--all]
set -euo pipefail

CURSOR_STORAGE="$HOME/Library/Application Support/Cursor/User/workspaceStorage"
CURRENT_WORKSPACE_HASH="741cf08327b3b44a659383a965967d25"  # 02luka-cursor.code-workspace

# Parse arguments
WORKSPACE_HASH="$CURRENT_WORKSPACE_HASH"
MODE="--all"

for arg in "$@"; do
  case "$arg" in
    --composers|--prompts|--keys|--stats|--all)
      MODE="$arg"
      ;;
    --help|-h)
      echo "Usage: $0 [workspace-hash] [--composers|--prompts|--keys|--stats|--all]"
      echo ""
      echo "Modes:"
      echo "  --composers  Show conversation metadata only"
      echo "  --prompts    Show prompts/messages only"
      echo "  --keys       List all chat-related keys"
      echo "  --stats      Show database statistics only"
      echo "  --all        Show everything (default)"
      exit 0
      ;;
    *)
      # If it doesn't start with --, assume it's a workspace hash
      if [[ ! "$arg" =~ ^-- ]]; then
        WORKSPACE_HASH="$arg"
      fi
      ;;
  esac
done

DB_FILE="$CURSOR_STORAGE/$WORKSPACE_HASH/state.vscdb"

# Check if database exists
if [[ ! -f "$DB_FILE" ]]; then
  echo "❌ Database not found: $DB_FILE"
  echo ""
  echo "Available workspaces:"
  find "$CURSOR_STORAGE" -name "state.vscdb" -exec ls -lh {} \; 2>/dev/null | \
    awk '{print "  " $9}' | sed "s|$CURSOR_STORAGE/||" | sed "s|/state.vscdb||"
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 not found. Install with: brew install sqlite3"
  exit 1
fi

echo "📊 Querying Cursor Chat History"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Workspace: $WORKSPACE_HASH"
echo "Database: $DB_FILE"
echo "Mode: $MODE"
echo ""

# Function to query composers (conversation metadata)
query_composers() {
  echo "📝 Composer Conversations (Metadata)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  local composer_data=$(sqlite3 "$DB_FILE" "PRAGMA read_uncommitted=1; SELECT value FROM ItemTable WHERE key = 'composer.composerData';" 2>/dev/null)
  
  if [[ -z "$composer_data" ]]; then
    echo "⚠️  No composer data found"
    return
  fi
  
  # Use Python to parse and display JSON nicely
  echo "$composer_data" | python3 -c "
import json, sys
from datetime import datetime

try:
    data = json.load(sys.stdin)
    composers = data.get('allComposers', [])
    
    if not composers:
        print('⚠️  No composers found in data')
        sys.exit(0)
    
    print(f'Found {len(composers)} conversation(s):\\n')
    
    for i, comp in enumerate(composers, 1):
        name = comp.get('name', 'Untitled')
        comp_id = comp.get('composerId', 'unknown')
        created = comp.get('createdAt', 0)
        updated = comp.get('lastUpdatedAt', 0)
        subtitle = comp.get('subtitle', '')
        
        # Convert timestamps
        created_str = datetime.fromtimestamp(created/1000).strftime('%Y-%m-%d %H:%M:%S') if created else 'Unknown'
        updated_str = datetime.fromtimestamp(updated/1000).strftime('%Y-%m-%d %H:%M:%S') if updated else 'Unknown'
        
        print(f'{i}. {name}')
        print(f'   ID: {comp_id}')
        print(f'   Created: {created_str}')
        print(f'   Updated: {updated_str}')
        if subtitle:
            print(f'   Files: {subtitle}')
        print()
        
except Exception as e:
    print(f'⚠️  Error parsing composer data: {e}')
    print('Raw data (first 500 chars):')
    sys.stdin.seek(0)
    print(sys.stdin.read()[:500])
" 2>/dev/null || echo "⚠️  Could not parse composer data"
  
  echo ""
}

# Function to query prompts
query_prompts() {
  echo "💬 Prompts & Messages"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Try to get prompts using SQLite JSON functions if available, otherwise raw
  local prompts_data=$(sqlite3 "$DB_FILE" "PRAGMA read_uncommitted=1; SELECT json(value) FROM ItemTable WHERE key = 'aiService.prompts';" 2>/dev/null || \
    sqlite3 "$DB_FILE" "PRAGMA read_uncommitted=1; SELECT value FROM ItemTable WHERE key = 'aiService.prompts';" 2>/dev/null)
  
  if [[ -z "$prompts_data" ]]; then
    echo "⚠️  No prompts data found"
    echo ""
    echo "Trying alternative keys..."
    sqlite3 "$DB_FILE" "PRAGMA read_uncommitted=1; SELECT key FROM ItemTable WHERE key LIKE '%prompt%' OR key LIKE '%message%' OR key LIKE '%chat%' LIMIT 10;" 2>/dev/null | while read key; do
      echo "  - $key"
    done
    return
  fi
  
  # Parse and display prompts (handle escaped JSON from SQLite)
  echo "$prompts_data" | python3 <<'PYTHON_EOF'
import json, sys, re
from datetime import datetime

try:
    # Read raw input from stdin
    raw = sys.stdin.read().strip()
    
    # Fix invalid escape sequences in JSON
    # The issue: "Application\ Support" should be "Application\\ Support" in JSON
    # We need to escape backslashes that are followed by spaces or capital letters
    # But preserve valid JSON escapes like \n, \t, etc.
    
    # Strategy: Replace \ followed by space or capital letter with \\
    # Use regex with negative lookbehind to avoid double-escaping
    fixed = re.sub(r'(?<!\\)\\(?=[A-Z ])', r'\\\\', raw)
    
    # Try to parse as JSON
    try:
        prompts = json.loads(fixed)
    except json.JSONDecodeError as e:
        # If still failing, try a more aggressive fix
        # Replace all \X (where X is not a valid escape) with \\X
        fixed2 = re.sub(r'\\(?![nrtbfu"\\/])', r'\\\\', raw)
        try:
            prompts = json.loads(fixed2)
        except:
            # Last resort: show raw data
            print(f'⚠️  Could not parse JSON: {e}')
            print('\\nFirst 1000 chars of raw data:')
            print(raw[:1000])
            sys.exit(1)
    
    if not isinstance(prompts, list):
        print('⚠️  Prompts data is not a list')
        print(f'Type: {type(prompts)}')
        if isinstance(prompts, dict):
            print(f'Keys: {list(prompts.keys())[:10]}')
        print('Raw (first 500 chars):')
        print(raw[:500])
        sys.exit(0)
    
    if not prompts:
        print('⚠️  No prompts found')
        sys.exit(0)
    
    print(f'Found {len(prompts)} prompt(s):\\n')
    
    for i, prompt in enumerate(prompts, 1):
        # Extract common fields
        text = prompt.get('text', prompt.get('content', prompt.get('message', prompt.get('prompt', ''))))
        timestamp = prompt.get('timestamp', prompt.get('createdAt', prompt.get('time', 0)))
        role = prompt.get('role', prompt.get('type', 'user'))
        cmd_type = prompt.get('commandType', '')
        
        # Format timestamp
        if timestamp:
            try:
                if isinstance(timestamp, (int, float)):
                    ts_str = datetime.fromtimestamp(timestamp/1000 if timestamp > 1e10 else timestamp).strftime('%Y-%m-%d %H:%M:%S')
                else:
                    ts_str = str(timestamp)
            except:
                ts_str = str(timestamp)
        else:
            ts_str = 'Unknown'
        
        role_label = role.upper() if role else 'USER'
        if cmd_type:
            role_label += f' (type:{cmd_type})'
        
        print(f'{i}. [{role_label}] {ts_str}')
        if text:
            preview = str(text)[:200].replace('\\n', ' ')
            print(f'   {preview}...' if len(str(text)) > 200 else f'   {text}')
        print()
        
except Exception as e:
    print(f'⚠️  Error: {e}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON_EOF

  if [[ $? -ne 0 ]]; then
    echo ""
    echo "⚠️  Could not parse prompts data"
    echo "Raw prompts data (first 500 chars):"
    echo "$prompts_data" | head -c 500
    echo "..."
  fi
  
  echo ""
}

# Function to list all chat-related keys
list_chat_keys() {
  echo "🔑 Chat-Related Keys in Database"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  sqlite3 "$DB_FILE" "PRAGMA read_uncommitted=1; SELECT DISTINCT key FROM ItemTable WHERE key LIKE '%chat%' OR key LIKE '%composer%' OR key LIKE '%prompt%' OR key LIKE '%message%' OR key LIKE '%conversation%' ORDER BY key;" 2>/dev/null | while read key; do
    echo "  - $key"
  done
  
  echo ""
}

# Function to show database stats
show_stats() {
  echo "📈 Database Statistics"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  local total_keys=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM ItemTable;" 2>/dev/null || echo "0")
  local chat_keys=$(sqlite3 "$DB_FILE" "SELECT COUNT(DISTINCT key) FROM ItemTable WHERE key LIKE '%chat%' OR key LIKE '%composer%' OR key LIKE '%prompt%';" 2>/dev/null || echo "0")
  local db_size=$(ls -lh "$DB_FILE" | awk '{print $5}')
  
  echo "  Total keys: $total_keys"
  echo "  Chat-related keys: $chat_keys"
  echo "  Database size: $db_size"
  echo ""
}

# Main execution
case "$MODE" in
  --composers)
    query_composers
    ;;
  --prompts)
    query_prompts
    ;;
  --keys)
    list_chat_keys
    ;;
  --stats)
    show_stats
    ;;
  --all|*)
    show_stats
    query_composers
    query_prompts
    list_chat_keys
    ;;
esac

echo "✅ Query complete"
