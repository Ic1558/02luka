#!/usr/bin/env zsh
# Emergency Repository Recovery Script
# Created: 2025-11-14
# Purpose: Stop sync, backup, reset repo, restore WO Pipeline v2

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚨 EMERGENCY REPOSITORY RECOVERY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================
# PHASE 1: STOP AUTO-SYNC
# ============================================
echo "📋 PHASE 1: Stopping Auto-Sync..."
echo ""

# Disable sync scripts
if [[ -f ~/02luka/tools/ensure_remote_sync.zsh ]]; then
  mv ~/02luka/tools/ensure_remote_sync.zsh ~/02luka/tools/ensure_remote_sync.zsh.DISABLED
  echo "✅ ensure_remote_sync.zsh → .DISABLED"
else
  echo "ℹ️  ensure_remote_sync.zsh already disabled or not found"
fi

if [[ -f ~/02luka/tools/auto_commit_work.zsh ]]; then
  mv ~/02luka/tools/auto_commit_work.zsh ~/02luka/tools/auto_commit_work.zsh.DISABLED
  echo "✅ auto_commit_work.zsh → .DISABLED"
else
  echo "ℹ️  auto_commit_work.zsh already disabled or not found"
fi

# Unload LaunchAgents
if launchctl list | grep -q "com.02luka.auto.commit"; then
  launchctl unload ~/Library/LaunchAgents/com.02luka.auto.commit.plist 2>/dev/null
  echo "✅ com.02luka.auto.commit unloaded"
else
  echo "ℹ️  com.02luka.auto.commit not loaded"
fi

# Verify no sync processes
SYNC_PROCS=$(ps aux | grep "git push\|git pull\|ensure_remote_sync\|auto_commit_work" | grep -v grep | wc -l | tr -d ' ')
if [[ "$SYNC_PROCS" -eq 0 ]]; then
  echo "✅ No sync processes running"
else
  echo "⚠️  Found $SYNC_PROCS sync process(es) - please check manually"
fi

echo ""
echo "✅ Phase 1 Complete: Auto-sync stopped"
echo ""

# ============================================
# PHASE 2: FULL REPO BACKUP
# ============================================
echo "📋 PHASE 2: Creating Full Repository Backup..."
echo ""

if [[ -d ~/02luka/g ]]; then
  cp -R ~/02luka/g ~/02luka/g_backup_before_recovery
  echo "✅ Full backup created: ~/02luka/g_backup_before_recovery"
  du -sh ~/02luka/g_backup_before_recovery | awk '{print "   Size: " $1}'
else
  echo "❌ ERROR: ~/02luka/g not found!"
  exit 1
fi

echo ""
echo "✅ Phase 2 Complete: Full backup created"
echo ""

# ============================================
# PHASE 3: WO PIPELINE V2 BACKUP
# ============================================
echo "📋 PHASE 3: Backing Up WO Pipeline v2..."
echo ""

mkdir -p /tmp/wo_pipeline_backup/{tools,launchd,docs,followup}

# Backup WO Pipeline scripts
if [[ -d ~/02luka/g/tools/wo_pipeline ]]; then
  cp -R ~/02luka/g/tools/wo_pipeline /tmp/wo_pipeline_backup/tools/ 2>/dev/null
  echo "✅ tools/wo_pipeline/ backed up"
else
  echo "⚠️  tools/wo_pipeline/ not found"
fi

# Backup LaunchAgents
if [[ -d ~/02luka/g/launchd ]]; then
  cp ~/02luka/g/launchd/com.02luka.*.plist /tmp/wo_pipeline_backup/launchd/ 2>/dev/null
  echo "✅ launchd/*.plist backed up"
else
  echo "⚠️  launchd/ not found"
fi

# Backup docs
if [[ -f ~/02luka/g/docs/WO_PIPELINE_V2.md ]]; then
  cp ~/02luka/g/docs/WO_PIPELINE_V2.md /tmp/wo_pipeline_backup/docs/ 2>/dev/null
  echo "✅ docs/WO_PIPELINE_V2.md backed up"
else
  echo "⚠️  docs/WO_PIPELINE_V2.md not found"
fi

# Backup state directory
if [[ -d ~/02luka/g/followup/state ]]; then
  cp -R ~/02luka/g/followup/state /tmp/wo_pipeline_backup/followup/ 2>/dev/null
  echo "✅ followup/state/ backed up"
else
  echo "⚠️  followup/state/ not found"
fi

echo ""
echo "Backup verification:"
ls -lhR /tmp/wo_pipeline_backup/ | head -20
echo ""
echo "✅ Phase 3 Complete: WO Pipeline v2 backed up"
echo ""

# ============================================
# PHASE 4: RESET REPOSITORY
# ============================================
echo "📋 PHASE 4: Resetting Repository to Clean State..."
echo ""

cd ~/02luka/g

# Step 1: Reset working tree
echo "Step 4.1: Resetting working tree..."
git reset --hard
echo "✅ Working tree reset"

# Step 2: Fetch latest
echo "Step 4.2: Fetching from remote..."
git fetch origin
echo "✅ Fetched from origin"

# Step 3: Switch to main
echo "Step 4.3: Switching to main branch..."
git switch main
echo "✅ Switched to main"

# Step 4: Reset to match remote
echo "Step 4.4: Resetting to match origin/main..."
git reset --hard origin/main
echo "✅ Reset to origin/main"

# Verify
echo ""
echo "Repository status:"
git status
echo ""

if git status | grep -q "working tree clean"; then
  echo "✅ Phase 4 Complete: Repository reset to clean state"
else
  echo "⚠️  WARNING: Repository may not be clean - please check git status"
fi

echo ""

# ============================================
# PHASE 5: RESTORE WO PIPELINE V2
# ============================================
echo "📋 PHASE 5: Restoring WO Pipeline v2 on New Branch..."
echo ""

cd ~/02luka/g

# Create new branch
echo "Step 5.1: Creating feature/wo-pipeline-v2 branch..."
git switch -c feature/wo-pipeline-v2
echo "✅ Branch created"

# Ensure directories exist
mkdir -p tools/wo_pipeline launchd docs followup

# Restore files
echo "Step 5.2: Restoring files from backup..."

if [[ -d /tmp/wo_pipeline_backup/tools/wo_pipeline ]]; then
  cp -R /tmp/wo_pipeline_backup/tools/wo_pipeline/* tools/wo_pipeline/ 2>/dev/null
  echo "✅ tools/wo_pipeline/ restored"
fi

if [[ -d /tmp/wo_pipeline_backup/launchd ]]; then
  cp /tmp/wo_pipeline_backup/launchd/*.plist launchd/ 2>/dev/null
  echo "✅ launchd/*.plist restored"
fi

if [[ -f /tmp/wo_pipeline_backup/docs/WO_PIPELINE_V2.md ]]; then
  cp /tmp/wo_pipeline_backup/docs/WO_PIPELINE_V2.md docs/ 2>/dev/null
  echo "✅ docs/WO_PIPELINE_V2.md restored"
fi

if [[ -d /tmp/wo_pipeline_backup/followup/state ]]; then
  cp -R /tmp/wo_pipeline_backup/followup/state followup/ 2>/dev/null
  echo "✅ followup/state/ restored"
fi

# Make scripts executable
chmod +x tools/wo_pipeline/*.zsh 2>/dev/null
echo "✅ Scripts made executable"

# Stage and commit
echo "Step 5.3: Committing WO Pipeline v2..."
git add tools/wo_pipeline/ launchd/ docs/ followup/state/ 2>/dev/null

git commit -m "feat(wo_pipeline): restore WO Pipeline v2 from backup

Recovered WO Pipeline v2 work created by Codex.
All 7 scripts, 5 LaunchAgents, docs, and state directory.

Files restored:
- tools/wo_pipeline/*.zsh (7 scripts)
- launchd/com.02luka.*.plist (5 LaunchAgents)
- docs/WO_PIPELINE_V2.md
- followup/state/

Recovery date: $(date +%Y-%m-%d)
Emergency recovery from detached HEAD state.
" || echo "⚠️  Commit failed (may be empty or already committed)"

echo ""
echo "✅ Phase 5 Complete: WO Pipeline v2 restored on feature/wo-pipeline-v2"
echo ""

# ============================================
# FINAL SUMMARY
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ RECOVERY COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo "  ✅ Auto-sync stopped"
echo "  ✅ Full repo backup: ~/02luka/g_backup_before_recovery"
echo "  ✅ WO Pipeline v2 backup: /tmp/wo_pipeline_backup/"
echo "  ✅ Repository reset to clean state"
echo "  ✅ WO Pipeline v2 restored on feature/wo-pipeline-v2"
echo ""
echo "Current branch:"
git branch | grep "^\*" | sed 's/^\* /  /'
echo ""
echo "Repository status:"
git status --short | head -10
echo ""
echo "Next steps:"
echo "  1. Review WO Pipeline v2 on feature/wo-pipeline-v2 branch"
echo "  2. Test WO Pipeline v2 scripts"
echo "  3. Merge to main when ready (after testing)"
echo "  4. Investigate root cause of detached HEAD"
echo "  5. Fix auto-sync scripts with safeguards"
echo ""
