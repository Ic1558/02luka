#!/usr/bin/env zsh
# MLS Ledger Protection Script
# Prevents accidental deletion/corruption of critical audit trail files
set -euo pipefail

BASE="$HOME/02luka"
LEDGER_DIR="$BASE/mls/ledger"
TODAY="$(TZ=Asia/Bangkok date +%Y-%m-%d)"
TODAY_FILE="$LEDGER_DIR/${TODAY}.jsonl"

# Create directory if it doesn't exist
mkdir -p "$LEDGER_DIR"

# Function to check if file is valid JSONL
is_valid_jsonl() {
  local file="$1"
  [[ ! -f "$file" ]] && return 1
  [[ ! -s "$file" ]] && return 1
  
  # Check if all non-empty lines are valid JSON
  local invalid_lines=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if ! echo "$line" | jq -e . >/dev/null 2>&1; then
      ((invalid_lines++))
    fi
  done < "$file"
  
  [[ $invalid_lines -eq 0 ]]
}

# Function to backup file
backup_file() {
  local file="$1"
  local backup_dir="$BASE/mls/backups"
  mkdir -p "$backup_dir"
  
  if [[ -f "$file" ]]; then
    local basename=$(basename "$file")
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$file" "$backup_dir/${basename}.backup.${timestamp}"
    echo "📦 Backed up: $backup_dir/${basename}.backup.${timestamp}"
  fi
}

# Function to restore from git if available
restore_from_git() {
  local file="$1"
  local basename=$(basename "$file")
  
  # Try to find in git history
  local git_file="mls/ledger/$basename"
  if git cat-file -e HEAD:"$git_file" 2>/dev/null; then
    echo "🔄 Restoring from git: $git_file"
    git show HEAD:"$git_file" > "$file"
    return 0
  fi
  
  # Try recent commits
  local commit=$(git log --all --oneline --format="%H" -- "$git_file" 2>/dev/null | head -1)
  if [[ -n "$commit" ]]; then
    echo "🔄 Restoring from commit: $commit"
    git show "$commit:$git_file" > "$file"
    return 0
  fi
  
  return 1
}

# Main protection logic
main() {
  local action="${1:-check}"
  
  case "$action" in
    check)
      # Check if today's file exists and is valid
      if [[ ! -f "$TODAY_FILE" ]]; then
        echo "⚠️  WARNING: Today's ledger file missing: $TODAY_FILE"
        echo "   Attempting to restore from git..."
        if restore_from_git "$TODAY_FILE"; then
          echo "✅ Restored from git"
        else
          echo "   Creating empty file..."
          touch "$TODAY_FILE"
        fi
        exit 1
      fi
      
      if ! is_valid_jsonl "$TODAY_FILE"; then
        echo "⚠️  WARNING: Today's ledger file is corrupted: $TODAY_FILE"
        backup_file "$TODAY_FILE"
        echo "   Attempting to restore from git..."
        if restore_from_git "$TODAY_FILE"; then
          echo "✅ Restored from git"
        else
          echo "❌ Could not restore - manual intervention needed"
          exit 1
        fi
      fi
      
      echo "✅ Ledger file is valid: $TODAY_FILE"
      ;;
      
    backup)
      # Backup all ledger files
      echo "📦 Backing up all ledger files..."
      for file in "$LEDGER_DIR"/*.jsonl(N); do
        backup_file "$file"
      done
      echo "✅ Backup complete"
      ;;
      
    verify-all)
      # Verify all ledger files
      local errors=0
      for file in "$LEDGER_DIR"/*.jsonl(N); do
        if ! is_valid_jsonl "$file"; then
          echo "❌ Invalid: $file"
          ((errors++))
        fi
      done
      
      if [[ $errors -eq 0 ]]; then
        echo "✅ All ledger files are valid"
        exit 0
      else
        echo "❌ Found $errors invalid file(s)"
        exit 1
      fi
      ;;
      
    restore)
      # Restore today's file from git
      local file="${2:-$TODAY_FILE}"
      backup_file "$file"
      if restore_from_git "$file"; then
        echo "✅ Restored: $file"
      else
        echo "❌ Could not restore: $file"
        exit 1
      fi
      ;;
      
    *)
      cat <<USAGE
MLS Ledger Protection Tool

Usage: mls_ledger_protect.zsh <command>

Commands:
  check        Check if today's ledger file exists and is valid
  backup       Backup all ledger files
  verify-all   Verify all ledger files are valid JSONL
  restore [file]  Restore file from git history (default: today's file)

Examples:
  mls_ledger_protect.zsh check
  mls_ledger_protect.zsh backup
  mls_ledger_protect.zsh verify-all
  mls_ledger_protect.zsh restore mls/ledger/2025-11-13.jsonl

USAGE
      exit 1
      ;;
  esac
}

main "$@"
