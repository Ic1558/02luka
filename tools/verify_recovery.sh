#!/bin/bash
# Recovery Verification Script
# Run this to verify all recovery steps completed successfully

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 EMERGENCY RECOVERY VERIFICATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Phase 1: Verify sync stopped
echo "📋 Phase 1: Auto-Sync Stopped"
echo ""

if ls ~/02luka/tools/*.DISABLED 2>/dev/null | grep -q "DISABLED"; then
  echo "✅ Sync scripts disabled:"
  ls ~/02luka/tools/*.DISABLED
else
  echo "⚠️  No .DISABLED files found - scripts may still be active"
fi

if launchctl list | grep -q "02luka.*commit"; then
  echo "⚠️  LaunchAgent still loaded:"
  launchctl list | grep "02luka.*commit"
else
  echo "✅ LaunchAgent unloaded (or not found)"
fi

echo ""

# Phase 2: Verify full backup
echo "📋 Phase 2: Full Repository Backup"
echo ""

if [ -d ~/02luka/g_backup_before_recovery ]; then
  echo "✅ Full backup exists: ~/02luka/g_backup_before_recovery"
  du -sh ~/02luka/g_backup_before_recovery | awk '{print "   Size: " $1}'
else
  echo "❌ Full backup NOT FOUND"
fi

echo ""

# Phase 3: Verify WO Pipeline backup
echo "📋 Phase 3: WO Pipeline v2 Backup"
echo ""

if [ -d /tmp/wo_pipeline_backup ]; then
  echo "✅ WO Pipeline backup exists: /tmp/wo_pipeline_backup"
  echo "   Contents:"
  ls -lhR /tmp/wo_pipeline_backup/ | head -20
else
  echo "❌ WO Pipeline backup NOT FOUND"
fi

echo ""

# Phase 4: Verify repository state
echo "📋 Phase 4: Repository State"
echo ""

cd ~/02luka/g
echo "Current branch:"
git branch | grep "^\*" || echo "⚠️  No branch indicator"

echo ""
echo "Repository status:"
git status --short | head -10 || echo "⚠️  Git status unavailable"

echo ""

# Phase 5: Verify WO Pipeline v2 restored
echo "📋 Phase 5: WO Pipeline v2 Restored"
echo ""

SCRIPT_COUNT=$(ls -1 tools/wo_pipeline/*.zsh 2>/dev/null | wc -l | tr -d ' ')
if [ "$SCRIPT_COUNT" -eq 7 ]; then
  echo "✅ All 7 scripts restored:"
  ls -1 tools/wo_pipeline/*.zsh
else
  echo "⚠️  Found $SCRIPT_COUNT scripts (expected 7)"
fi

echo ""

PLIST_COUNT=$(ls -1 launchd/com.02luka.*.plist 2>/dev/null | wc -l | tr -d ' ')
if [ "$PLIST_COUNT" -eq 5 ]; then
  echo "✅ All 5 LaunchAgents restored:"
  ls -1 launchd/com.02luka.*.plist
else
  echo "⚠️  Found $PLIST_COUNT LaunchAgents (expected 5)"
fi

echo ""

if [ -f docs/WO_PIPELINE_V2.md ]; then
  echo "✅ Documentation restored: docs/WO_PIPELINE_V2.md"
else
  echo "❌ Documentation NOT FOUND"
fi

if [ -d followup/state ]; then
  echo "✅ State directory restored: followup/state/"
else
  echo "❌ State directory NOT FOUND"
fi

echo ""

# Final summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 VERIFICATION SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ALL_OK=true

[ -d ~/02luka/g_backup_before_recovery ] || ALL_OK=false
[ -d /tmp/wo_pipeline_backup ] || ALL_OK=false
[ "$SCRIPT_COUNT" -eq 7 ] || ALL_OK=false
[ "$PLIST_COUNT" -eq 5 ] || ALL_OK=false
[ -f docs/WO_PIPELINE_V2.md ] || ALL_OK=false
[ -d followup/state ] || ALL_OK=false

if [ "$ALL_OK" = true ]; then
  echo "✅ ALL CHECKS PASSED - Recovery appears complete"
else
  echo "⚠️  SOME CHECKS FAILED - Review output above"
fi

echo ""
