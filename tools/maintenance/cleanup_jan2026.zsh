#!/bin/zsh
set -euo pipefail

# === Configuration ===
ARCHIVE_ROOT="tools/archive"
ROLLBACK_ARCHIVE="$ARCHIVE_ROOT/rollback"
PHASE_ARCHIVE="$ARCHIVE_ROOT/phases"
BACKUP_ARCHIVE="$ARCHIVE_ROOT/_bak"
MODE="dry-run"

# === Helper Functions ===
log() { echo "[$MODE] $*"; }
warn() { echo "[$MODE] ⚠️  $*"; }

ensure_repo_root() {
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null || true)
    if [[ -z "$root" || "$PWD" != "$root" ]]; then
        echo "Error: Must run from repo root."
        exit 1
    fi
}

usage() {
    echo "Usage: $0 [--dry-run | --apply]"
    exit 1
}

safe_move() {
    local src="$1"
    local dest_dir="$2"
    
    if [[ ! -e "$src" ]]; then
        return
    fi
    
    mkdir -p "$dest_dir"
    if [[ "$MODE" == "apply" ]]; then
        mv "$src" "$dest_dir/"
        echo "  Moved: $src -> $dest_dir/"
    else
        echo "  Would move: $src -> $dest_dir/"
    fi
}

safe_chmod() {
    local target="$1"
    if [[ ! -e "$target" ]]; then
        return
    fi
    
    if [[ "$MODE" == "apply" ]]; then
        chmod +x "$target"
        echo "  Fixed perm: $target"
    else
        echo "  Would fix perm: $target"
    fi
}

# === Parse Args ===
if [[ $# -eq 0 ]]; then
    MODE="dry-run"
elif [[ "$1" == "--apply" ]]; then
    MODE="apply"
elif [[ "$1" == "--dry-run" ]]; then
    MODE="dry-run"
else
    usage
fi

# === Main Execution ===
ensure_repo_root

echo "== System Cleanup Tool v2 (Mode: $MODE) =="

# 1. Handle Backups (.bak) -> tools/archive/_bak/
log "Scanning for .bak files..."
# Find files safely, excluding .git
found_backups=($(find . -path './.git' -prune -o -type f -name "*.bak*" -print))
for f in "${found_backups[@]}"; do
    # Skip if loop finds nothing/directory
    [[ -f "$f" ]] || continue
    safe_move "$f" "$BACKUP_ARCHIVE"
done

# 2. Archive Rollbacks -> tools/archive/rollback/
log "Scanning for legacy rollback scripts..."
# Use zsh globbing for rollback scripts in tools/
setopt NULL_GLOB
for f in tools/rollback_*.zsh; do
    safe_move "$f" "$ROLLBACK_ARCHIVE"
done

# 3. Archive Phase Scripts -> tools/archive/phases/
log "Scanning for completed phase scripts..."
for f in tools/phase[1-6]*; do
    safe_move "$f" "$PHASE_ARCHIVE"
done

# 4. Fix Permissions
log "Checking script permissions..."
targets=(
    "tools/complete_recovery_blocks.sh"
    "tools/run_recovery_now.sh"
    "tools/verify_recovery.sh"
    "tools/lib/ci_rebase_smart.sh"
    "tools/lib/validation_smart.sh"
)

for f in "${targets[@]}"; do
    safe_chmod "$f"
done

log "Operation Complete."
