#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# Codex Performance Cleanup - Remove Tool-Generated Backup Noise
# ═══════════════════════════════════════════════════════════════════════
# Created: 2025-11-28 by CLC
# Purpose: Clean up large untracked directories that slow Codex CLI snapshots
#
# SAFETY: This script targets ONLY tool-generated artifacts, NOT governance backups
#
# Deletes:
#   - backups/apply_patch/ (~12k files, patch tool artifacts)
#   - backups/02luka-pre-unify-snapshot/ (large snapshot, tarball exists)
#   - logs/ files older than 30 days
#
# Preserves:
#   - backups/boss_archive/
#   - backups/boss_workspace/
#   - backups/context_migration_*/
#   - backups/hooks_*
#   - backups/*.tgz (compressed backups)
#   - All other backups/ subdirectories
#
# Usage:
#   # Dry run (show what would be deleted)
#   ./tools/codex_cleanup_backups.zsh --dry-run
#
#   # Actually delete
#   ./tools/codex_cleanup_backups.zsh --execute
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

ROOT="${HOME}/02luka"
DRY_RUN=true

# ═══════════════════════════════════════════════════════════════════════
# Parse Arguments
# ═══════════════════════════════════════════════════════════════════════
if [[ "${1:-}" == "--execute" ]]; then
    DRY_RUN=false
    echo "⚠️  EXECUTE MODE: Changes will be permanent!"
elif [[ "${1:-}" == "--dry-run" || -z "${1:-}" ]]; then
    DRY_RUN=true
    echo "🔍 DRY RUN MODE: No files will be deleted"
else
    echo "Usage: $0 [--dry-run|--execute]"
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║       Codex Performance Cleanup - Backup & Log Removal            ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Safety Checks
# ═══════════════════════════════════════════════════════════════════════
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ Safety Checks                                                    │"
echo "└─────────────────────────────────────────────────────────────────┘"

# Check we're in the right directory
if [[ ! -d "$ROOT" ]]; then
    echo "❌ ERROR: $ROOT not found"
    exit 1
fi

cd "$ROOT"

# Verify governance backups exist and won't be touched
GOVERNANCE_DIRS=(
    "backups/boss_archive"
    "backups/boss_workspace"
)

for dir in "${GOVERNANCE_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "   ✅ Governance backup preserved: $dir"
    else
        echo "   ℹ️  Governance backup not found (ok): $dir"
    fi
done

echo ""

# ═══════════════════════════════════════════════════════════════════════
# Phase 1: Remove apply_patch Artifacts
# ═══════════════════════════════════════════════════════════════════════
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ [1/3] Remove backups/apply_patch/ (~12k files)                  │"
echo "└─────────────────────────────────────────────────────────────────┘"

if [[ -d "backups/apply_patch" ]]; then
    FILE_COUNT=$(find backups/apply_patch -type f 2>/dev/null | wc -l | tr -d ' ')
    DIR_SIZE=$(du -sh backups/apply_patch 2>/dev/null | cut -f1)

    echo "   📊 Stats: $FILE_COUNT files, $DIR_SIZE total"

    if [[ "$DRY_RUN" == true ]]; then
        echo "   🔍 Would delete: backups/apply_patch/"
    else
        echo "   🗑️  Deleting: backups/apply_patch/"
        rm -rf backups/apply_patch/
        echo "   ✅ Deleted successfully"
    fi
else
    echo "   ℹ️  backups/apply_patch/ not found (already clean)"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════
# Phase 2: Remove pre-unify Snapshot
# ═══════════════════════════════════════════════════════════════════════
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ [2/3] Remove backups/02luka-pre-unify-snapshot/                 │"
echo "└─────────────────────────────────────────────────────────────────┘"

if [[ -d "backups/02luka-pre-unify-snapshot" ]]; then
    DIR_SIZE=$(du -sh backups/02luka-pre-unify-snapshot 2>/dev/null | cut -f1)
    SUBDIR_COUNT=$(find backups/02luka-pre-unify-snapshot -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

    echo "   📊 Stats: $SUBDIR_COUNT subdirectories, $DIR_SIZE total"

    # Check if tarball backup exists
    if [[ -f "backups/02luka_local_g-pre-unify.tgz" ]]; then
        TARBALL_SIZE=$(du -sh backups/02luka_local_g-pre-unify.tgz 2>/dev/null | cut -f1)
        echo "   ✅ Compressed backup exists: backups/02luka_local_g-pre-unify.tgz ($TARBALL_SIZE)"
    else
        echo "   ⚠️  WARNING: Compressed backup not found!"
        echo "   ℹ️  Consider creating backup before deletion:"
        echo "       tar -czf backups/02luka_local_g-pre-unify.tgz backups/02luka-pre-unify-snapshot/"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "   🔍 Would delete: backups/02luka-pre-unify-snapshot/"
    else
        echo "   🗑️  Deleting: backups/02luka-pre-unify-snapshot/"
        rm -rf backups/02luka-pre-unify-snapshot/
        echo "   ✅ Deleted successfully"
    fi
else
    echo "   ℹ️  backups/02luka-pre-unify-snapshot/ not found (already clean)"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════
# Phase 3: Clean Old Logs
# ═══════════════════════════════════════════════════════════════════════
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ [3/3] Clean logs/ (files older than 30 days)                    │"
echo "└─────────────────────────────────────────────────────────────────┘"

if [[ -d "logs" ]]; then
    OLD_LOGS=$(find logs/ -type f \( -name "*.log" -o -name "*.out" -o -name "*.err" \) -mtime +30 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$OLD_LOGS" -gt 0 ]]; then
        echo "   📊 Found $OLD_LOGS log files older than 30 days"

        if [[ "$DRY_RUN" == true ]]; then
            echo "   🔍 Would delete $OLD_LOGS old log files"
            echo "   Sample files that would be deleted:"
            find logs/ -type f \( -name "*.log" -o -name "*.out" -o -name "*.err" \) -mtime +30 2>/dev/null | head -5 | sed 's/^/      • /'
        else
            echo "   🗑️  Deleting $OLD_LOGS old log files..."
            find logs/ -type f \( -name "*.log" -o -name "*.out" -o -name "*.err" \) -mtime +30 -delete
            echo "   ✅ Deleted successfully"
        fi
    else
        echo "   ✅ No old log files found (already clean)"
    fi

    # Optional: Compress logs 7-30 days old
    COMPRESS_LOGS=$(find logs/ -type f \( -name "*.log" -o -name "*.out" -o -name "*.err" \) -mtime +7 -mtime -30 ! -name "*.gz" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$COMPRESS_LOGS" -gt 0 ]]; then
        echo "   💡 Optional: $COMPRESS_LOGS log files could be compressed (7-30 days old)"
        echo "      Run: find logs/ -type f \( -name '*.log' -o -name '*.out' -o -name '*.err' \) -mtime +7 -mtime -30 -exec gzip {} \;"
    fi
else
    echo "   ℹ️  logs/ directory not found"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════
echo "╔═══════════════════════════════════════════════════════════════════╗"
if [[ "$DRY_RUN" == true ]]; then
    echo "║  🔍 DRY RUN COMPLETE - No changes made                            ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "To actually delete files, run:"
    echo "  $0 --execute"
else
    echo "║  ✅ CLEANUP COMPLETE                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo "  1. Verify git status: git status --untracked-files=all | wc -l"
    echo "  2. Check disk space: du -sh ~/02luka/backups ~/02luka/logs"
    echo "  3. Test Codex: codex status (or your usual command)"
fi
echo ""
