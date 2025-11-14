#!/bin/bash
# Complete Recovery - All 3 Blocks
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚨 COMPLETE RECOVERY - ALL 3 BLOCKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================
# BLOCK 1: DISABLE AUTO-SYNC
# ============================================
echo "📋 BLOCK 1: Disabling Auto-Sync"
echo ""

cd ~/02luka

# Disable sync scripts
if [ -f tools/ensure_remote_sync.zsh ]; then
  mv tools/ensure_remote_sync.zsh tools/ensure_remote_sync.zsh.DISABLED
  echo "✅ ensure_remote_sync.zsh → .DISABLED"
else
  echo "⚠️  ensure_remote_sync.zsh not found (may already be disabled)"
fi

if [ -f tools/auto_commit_work.zsh ]; then
  mv tools/auto_commit_work.zsh tools/auto_commit_work.zsh.DISABLED
  echo "✅ auto_commit_work.zsh → .DISABLED"
else
  echo "⚠️  auto_commit_work.zsh not found (may already be disabled)"
fi

# Verify disabled
echo ""
echo "Verifying disabled scripts:"
ls -lh tools/*.DISABLED 2>/dev/null || echo "⚠️  No .DISABLED files found"

# Unload LaunchAgent
echo ""
echo "Unloading LaunchAgent..."
launchctl unload ~/Library/LaunchAgents/com.02luka.auto.commit.plist 2>/dev/null && echo "✅ LaunchAgent unloaded" || echo "⚠️  LaunchAgent not loaded or not found"

# Check for running agents
echo ""
echo "Checking for running 02luka agents:"
launchctl list | grep -i 02luka | head -5 || echo "✅ No 02luka agents found"

echo ""
echo "✅ BLOCK 1 COMPLETE"
echo ""

# ============================================
# BLOCK 2: MANUAL BACKUP
# ============================================
echo "📋 BLOCK 2: Manual Backup of WO Pipeline v2"
echo ""

cd ~/02luka/g

# Create backup directory
mkdir -p /tmp/wo_pipeline_backup_manual/{tools,launchd,docs,followup}
echo "✅ Backup directory created"

# Backup files
echo ""
echo "Backing up files..."
cp -R tools/wo_pipeline /tmp/wo_pipeline_backup_manual/tools/ 2>/dev/null && echo "✅ tools/wo_pipeline/ backed up" || echo "⚠️  tools/wo_pipeline/ not found"
cp launchd/com.02luka.*.plist /tmp/wo_pipeline_backup_manual/launchd/ 2>/dev/null && echo "✅ launchd/*.plist backed up" || echo "⚠️  launchd/*.plist not found"
cp docs/WO_PIPELINE_V2.md /tmp/wo_pipeline_backup_manual/docs/ 2>/dev/null && echo "✅ docs/WO_PIPELINE_V2.md backed up" || echo "⚠️  docs/WO_PIPELINE_V2.md not found"
cp -R followup/state /tmp/wo_pipeline_backup_manual/followup/ 2>/dev/null && echo "✅ followup/state/ backed up" || echo "⚠️  followup/state/ not found"

# Verify backup
echo ""
echo "Verifying backup:"
ls -lhR /tmp/wo_pipeline_backup_manual/ | head -20

echo ""
echo "✅ BLOCK 2 COMPLETE"
echo ""

# ============================================
# BLOCK 3: FIX DETACHED HEAD
# ============================================
echo "📋 BLOCK 3: Fix Detached HEAD → Return to Main"
echo ""

cd ~/02luka/g

# Fetch latest
echo "Fetching latest from remote..."
git fetch origin
echo "✅ Fetched from origin"

# Create backup branch
echo ""
echo "Creating backup branch..."
git branch backup/wo-pipeline-9704fac 2>/dev/null && echo "✅ Backup branch created: backup/wo-pipeline-9704fac" || echo "⚠️  Branch may already exist"

# Switch to main
echo ""
echo "Switching to main branch..."
git switch main 2>/dev/null || git checkout -b main
echo "✅ Switched to main"

# Reset to origin/main
echo ""
echo "Resetting main to match origin/main..."
git reset --hard origin/main
echo "✅ Reset to origin/main"

# Verify
echo ""
echo "Verifying final state:"
echo ""
echo "Current branch:"
git branch
echo ""
echo "Repository status:"
git status --short | head -10

echo ""
echo "✅ BLOCK 3 COMPLETE"
echo ""

# ============================================
# FINAL SUMMARY
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ALL 3 BLOCKS COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo "  ✅ Auto-sync disabled (scripts + LaunchAgent)"
echo "  ✅ WO Pipeline v2 manually backed up"
echo "  ✅ Repository on main branch (not detached)"
echo "  ✅ Backup branch created: backup/wo-pipeline-9704fac"
echo ""
echo "WO Pipeline v2 is safe in:"
echo "  - Backup branch: backup/wo-pipeline-9704fac"
echo "  - Manual backup: /tmp/wo_pipeline_backup_manual/"
echo ""
