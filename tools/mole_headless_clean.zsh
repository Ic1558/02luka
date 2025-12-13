 #!/usr/bin/env zsh
# Mole-Inspired Headless Cleanup
# Based on tw93/Mole v1.11.34
# Designed for LaunchAgent automation (non-interactive)

set -euo pipefail

# ============================================
# Configuration
# ============================================

DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"
LOG_FILE="${LOG_FILE:-/dev/null}"

# Track stats
TOTAL_CLEANED_KB=0
TOTAL_ITEMS=0
TOTAL_ERRORS=0

# ============================================
# Whitelist (Protected Paths)
# ============================================

# Patterns to NEVER delete (02luka specific + Mole defaults)
PROTECTED_PATTERNS=(
  "*/Cursor/*"
  "*/VSCode/*"
  "*/code-server/*"
  "*/Antigravity/*"
  "*/Claude/*"
  "*/com.apple.commerce/*"
  "*/1Password/*"
  "*/ClashX/*"
  "*/Surge/*"
  "*/iTerm*/*"
  "*/Warp/*"
  "*/JetBrains/*"
)

# Service Worker protected domains (web editors)
PROTECTED_SW_DOMAINS=(
  "capcut.com"
  "photopea.com"
  "pixlr.com"
  "figma.com"
  "canva.com"
)

# ============================================
# Helper Functions
# ============================================

log() {
  echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] $*" | /usr/bin/tee -a "$LOG_FILE"
}

debug_log() {
  [[ "$VERBOSE" == "true" ]] && log "DEBUG: $*"
}

is_protected() {
  local path="$1"
  for pattern in "${PROTECTED_PATTERNS[@]}"; do
    if [[ "$path" == $~pattern ]]; then
      debug_log "Protected: $path (matches $pattern)"
      return 0
    fi
  done
  return 1
}

get_size_kb() {
  local path="$1"
  if [[ -e "$path" ]]; then
    # Use timeout to prevent hanging
    /usr/bin/timeout 5 /usr/bin/du -sk "$path" 2>/dev/null | /usr/bin/awk '{print $1}' || echo "0"
  else
    echo "0"
  fi
}

safe_remove() {
  local path="$1"
  local description="${2:-Unknown}"
  
  # Safety checks
  [[ -z "$path" ]] && return 1
  [[ "$path" == "/" ]] && return 1
  [[ "$path" == "$HOME" ]] && return 1
  
  # Check if protected
  if is_protected "$path"; then
    debug_log "Skipped (protected): $description"
    return 0
  fi
  
  # Check if exists
  [[ ! -e "$path" ]] && return 0
  
  # Get size before deletion
  local size_kb=$(get_size_kb "$path")
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would remove: $description ($(( size_kb / 1024 ))MB)"
  else
    if rm -rf "$path" 2>/dev/null; then
      TOTAL_CLEANED_KB=$((TOTAL_CLEANED_KB + size_kb))
      TOTAL_ITEMS=$((TOTAL_ITEMS + 1))
      log "Cleaned: $description ($(( size_kb / 1024 ))MB)"
    else
      TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
      log "ERROR: Failed to remove $description"
    fi
  fi
}

# ============================================
# Cleanup Functions (from Mole user.sh)
# ============================================

clean_user_essentials() {
  log "=== User Essentials ==="
  
  # User caches (safe patterns only)
  safe_remove "$HOME/Library/Caches/com.apple.Safari/fsCachedData" "Safari cached data"
  safe_remove "$HOME/Library/Caches/com.apple.WebKit.WebContent" "WebKit content cache"
  safe_remove "$HOME/Library/Caches/com.apple.WebKit.Networking" "WebKit network cache"
}

clean_browsers() {
  log "=== Browser Caches ==="
  
  # Chrome
  safe_remove "$HOME/Library/Caches/Google/Chrome/Default/Cache" "Chrome default cache"
  safe_remove "$HOME/Library/Application Support/Google/Chrome/Default/GPUCache" "Chrome GPU cache"
  
  # Safari
  safe_remove "$HOME/Library/Caches/com.apple.Safari" "Safari cache"
  
  # Firefox
  safe_remove "$HOME/Library/Caches/Firefox" "Firefox cache"
  
  # Edge
  safe_remove "$HOME/Library/Caches/com.microsoft.edgemac" "Edge cache"
  
  # Arc
  safe_remove "$HOME/Library/Caches/company.thebrowser.Browser" "Arc cache"
  
  # Brave
  safe_remove "$HOME/Library/Caches/BraveSoftware/Brave-Browser" "Brave cache"
}

clean_cloud_storage() {
  log "=== Cloud Storage Caches ==="
  
  safe_remove "$HOME/Library/Caches/com.dropbox.dropbox" "Dropbox cache"
  safe_remove "$HOME/Library/Caches/com.google.GoogleDrive" "Google Drive cache"
  safe_remove "$HOME/Library/Caches/com.microsoft.OneDrive" "OneDrive cache"
}

clean_dev_tools() {
  log "=== Developer Tools ==="
  
  # Node/npm (only safe patterns)
  safe_remove "$HOME/.npm/_cacache" "npm cache"
  
  # Yarn
  safe_remove "$HOME/Library/Caches/Yarn" "Yarn cache"
  
  # Not cleaning Xcode - too risky
}

clean_system_logs() {
  log "=== System Logs ==="
  
  # Only clean old logs (>7 days)
  find "$HOME/Library/Logs" -type f -mtime +7 -name "*.log" 2>/dev/null | while read -r log_file; do
    safe_remove "$log_file" "Old log: $(basename "$log_file")"
  done
}

# ============================================
# Main Cleanup
# ============================================

main() {
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "Mole-Inspired Headless Cleanup"
  log "Mode: $([[ "$DRY_RUN" == "true" ]] && echo "DRY-RUN" || echo "LIVE")"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Run cleanup modules
  clean_user_essentials
  clean_browsers
  clean_cloud_storage
  clean_dev_tools
  clean_system_logs
  
  # Summary
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "Summary:"
  log "  Items cleaned: $TOTAL_ITEMS"
  log "  Space freed: $(( TOTAL_CLEANED_KB / 1024 ))MB"
  log "  Errors: $TOTAL_ERRORS"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Exit code
  [[ $TOTAL_ERRORS -gt 5 ]] && exit 1 || exit 0
}

# Handle arguments
case "${1:-}" in
  --dry-run)
    DRY_RUN=true
    main
    ;;
  --verbose)
    VERBOSE=true
    main
    ;;
  --help)
    cat <<EOF
Mole-Inspired Headless Cleanup

Usage:
  $0              # Run cleanup
  $0 --dry-run    # Preview what would be cleaned
  $0 --verbose    # Show debug info
  $0 --help       # Show this help

Environment:
  DRY_RUN=true    # Preview mode
  VERBOSE=true    # Debug logging
  LOG_FILE=path   # Log output file
EOF
    ;;
  *)
    main
    ;;
esac
