#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# Archive Legacy CLC Backlog
# ═══════════════════════════════════════════════════════════════════════
# Archives pre-v5 CLC Work Orders to clear backlog and mark as legacy.
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

ROOT="${LUKA_SOT:-${HOME}/02luka}"
CLC_INBOX="${ROOT}/bridge/inbox/CLC"
ARCHIVE_DIR="${ROOT}/bridge/archive/CLC/legacy_before_v5"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# ═══════════════════════════════════════════
# Archive Function
# ═══════════════════════════════════════════

archive_legacy_wo() {
    local wo_file="$1"
    local wo_id=$(basename "$wo_file" .yaml)
    
    # Create archive directory
    mkdir -p "$ARCHIVE_DIR"
    
    # Move to archive with timestamp prefix
    local archive_path="${ARCHIVE_DIR}/${TIMESTAMP}_${wo_id}.yaml"
    mv "$wo_file" "$archive_path"
    
    echo "Archived: $wo_id → $archive_path"
}

# ═══════════════════════════════════════════
# Main
# ═══════════════════════════════════════════

main() {
    local dry_run="${1:-false}"
    
    if [[ ! -d "$CLC_INBOX" ]]; then
        echo "❌ CLC inbox not found: $CLC_INBOX"
        exit 1
    fi
    
    # Find all YAML files in CLC inbox
    local wo_files=($(find "$CLC_INBOX" -name "*.yaml" -type f 2>/dev/null))
    local count=${#wo_files[@]}
    
    if [[ $count -eq 0 ]]; then
        echo "✅ No Work Orders in CLC inbox to archive"
        exit 0
    fi
    
    echo "📦 Found $count Work Order(s) in CLC inbox"
    echo "📁 Archive destination: $ARCHIVE_DIR"
    
    if [[ "$dry_run" == "true" ]]; then
        echo ""
        echo "🔍 DRY RUN - Would archive:"
        for wo_file in "${wo_files[@]}"; do
            echo "   - $(basename "$wo_file")"
        done
        echo ""
        echo "Run without --dry-run to actually archive"
        exit 0
    fi
    
    echo ""
    echo "🔄 Archiving..."
    
    local archived=0
    for wo_file in "${wo_files[@]}"; do
        archive_legacy_wo "$wo_file"
        ((archived++))
    done
    
    echo ""
    echo "✅ Archived $archived Work Order(s)"
    echo "📁 Location: $ARCHIVE_DIR"
}

# ═══════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════

if [[ "${1:-}" == "--dry-run" ]]; then
    main "true"
else
    main "false"
fi

