#!/usr/bin/env bash
###############################################################################
# Apply Indexes Script
#
# Reads recommendations from index_advisor_report.json and applies indexes
# to the database with safety checks and rollback support.
#
# Features:
# - Dry-run mode (--dry-run)
# - Automatic backup before applying
# - Rollback support (--rollback)
# - Verbose logging (--verbose)
###############################################################################

set -euo pipefail

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_FILE="$ROOT_DIR/g/reports/index_advisor_report.json"
DB_PATH="$ROOT_DIR/knowledge/02luka.db"
BACKUP_DIR="$ROOT_DIR/g/reports/db_backups"
LOG_FILE="$ROOT_DIR/g/reports/apply_indexes.log"

# Options
DRY_RUN=false
ROLLBACK=false
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

###############################################################################
# Functions
###############################################################################

log() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ✅ $*" | tee -a "$LOG_FILE"
}

log_error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ❌ $*" | tee -a "$LOG_FILE"
}

log_warn() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ⚠️  $*" | tee -a "$LOG_FILE"
}

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Apply database indexes recommended by index_advisor.cjs

OPTIONS:
  --dry-run      Show what would be done without applying
  --rollback     Restore database from latest backup
  --verbose      Show detailed output
  --help         Show this help message

EXAMPLES:
  $0 --dry-run         # Preview recommendations
  $0                   # Apply indexes
  $0 --rollback        # Restore from backup
EOF
  exit 0
}

create_backup() {
  log "Creating database backup..."

  # Create backup directory
  mkdir -p "$BACKUP_DIR"

  # Backup filename with timestamp
  BACKUP_FILE="$BACKUP_DIR/02luka_$(date +'%Y%m%d_%H%M%S').db"

  # Copy database
  cp "$DB_PATH" "$BACKUP_FILE"

  # Verify backup
  if [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log_success "Backup created: $BACKUP_FILE ($BACKUP_SIZE)"
    echo "$BACKUP_FILE" > "$BACKUP_DIR/latest_backup.txt"
  else
    log_error "Backup failed"
    exit 1
  fi
}

rollback_database() {
  log "Rolling back database..."

  # Find latest backup
  if [ ! -f "$BACKUP_DIR/latest_backup.txt" ]; then
    log_error "No backup found"
    exit 1
  fi

  LATEST_BACKUP=$(cat "$BACKUP_DIR/latest_backup.txt")

  if [ ! -f "$LATEST_BACKUP" ]; then
    log_error "Backup file not found: $LATEST_BACKUP"
    exit 1
  fi

  # Restore backup
  cp "$LATEST_BACKUP" "$DB_PATH"

  log_success "Database restored from: $LATEST_BACKUP"
}

apply_indexes() {
  log "Applying indexes from advisor report..."

  # Check if report exists
  if [ ! -f "$REPORT_FILE" ]; then
    log_error "Advisor report not found: $REPORT_FILE"
    log "Run: node knowledge/optimize/index_advisor.cjs"
    exit 1
  fi

  # Read recommendations count
  REC_COUNT=$(jq '.recommendations | length' "$REPORT_FILE")

  if [ "$REC_COUNT" -eq 0 ]; then
    log_success "No index recommendations to apply"
    exit 0
  fi

  log "Found $REC_COUNT index recommendation(s)"

  # Extract SQL statements
  SQL_STATEMENTS=$(jq -r '.recommendations[].sql' "$REPORT_FILE")

  if [ "$DRY_RUN" = true ]; then
    log "📋 DRY-RUN MODE - Would execute:"
    echo "$SQL_STATEMENTS" | nl -w2 -s'. '
    exit 0
  fi

  # Create backup before applying
  create_backup

  # Apply each SQL statement
  INDEX_NUM=0
  while IFS= read -r sql; do
    INDEX_NUM=$((INDEX_NUM + 1))

    if [ "$VERBOSE" = true ]; then
      log "Executing [$INDEX_NUM/$REC_COUNT]: $sql"
    fi

    # Execute SQL
    if sqlite3 "$DB_PATH" "$sql" 2>&1 | tee -a "$LOG_FILE"; then
      log_success "Index $INDEX_NUM/$REC_COUNT applied"
    else
      log_error "Failed to apply index $INDEX_NUM/$REC_COUNT"
      log_warn "Rolling back..."
      rollback_database
      exit 1
    fi
  done <<< "$SQL_STATEMENTS"

  log_success "All $REC_COUNT indexes applied successfully"

  # Verify indexes
  verify_indexes
}

verify_indexes() {
  log "Verifying indexes..."

  INDEX_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='index';")
  log_success "Total indexes in database: $INDEX_COUNT"

  if [ "$VERBOSE" = true ]; then
    log "Index list:"
    sqlite3 "$DB_PATH" "SELECT name, tbl_name FROM sqlite_master WHERE type='index';" | nl -w2 -s'. '
  fi
}

###############################################################################
# Main
###############################################################################

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --rollback)
      ROLLBACK=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      usage
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      ;;
  esac
done

# Initialize log
log "===== Apply Indexes Script ====="

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
  log_error "Database not found: $DB_PATH"
  exit 1
fi

# Execute requested action
if [ "$ROLLBACK" = true ]; then
  rollback_database
else
  apply_indexes
fi

log "===== Complete ====="
