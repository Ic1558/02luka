#!/bin/bash
# Emergency Recovery - Execute Now
set -e

cd /Users/icmini/02luka

echo "=== PHASE 1: STOPPING AUTO-SYNC ==="
if [ -f tools/ensure_remote_sync.zsh ]; then
  mv tools/ensure_remote_sync.zsh tools/ensure_remote_sync.zsh.DISABLED
  echo "✅ ensure_remote_sync.zsh disabled"
fi

if [ -f tools/auto_commit_work.zsh ]; then
  mv tools/auto_commit_work.zsh tools/auto_commit_work.zsh.DISABLED
  echo "✅ auto_commit_work.zsh disabled"
fi

launchctl unload ~/Library/LaunchAgents/com.02luka.auto.commit.plist 2>/dev/null || true
echo "✅ LaunchAgent unloaded (or not found)"

echo ""
echo "=== PHASE 2: FULL REPO BACKUP ==="
cp -R 02luka/g 02luka/g_backup_before_recovery
echo "✅ Full backup created"

echo ""
echo "=== PHASE 3: WO PIPELINE BACKUP ==="
mkdir -p /tmp/wo_pipeline_backup/{tools,launchd,docs,followup}
cp -R 02luka/g/tools/wo_pipeline /tmp/wo_pipeline_backup/tools/ 2>/dev/null || true
cp 02luka/g/launchd/com.02luka.*.plist /tmp/wo_pipeline_backup/launchd/ 2>/dev/null || true
cp 02luka/g/docs/WO_PIPELINE_V2.md /tmp/wo_pipeline_backup/docs/ 2>/dev/null || true
cp -R 02luka/g/followup/state /tmp/wo_pipeline_backup/followup/ 2>/dev/null || true
echo "✅ WO Pipeline v2 backed up"

echo ""
echo "=== PHASE 4: RESET REPOSITORY ==="
cd 02luka/g
git reset --hard
git fetch origin
git switch main 2>/dev/null || git checkout -b main
git reset --hard origin/main
echo "✅ Repository reset to clean state"

echo ""
echo "=== PHASE 5: RESTORE WO PIPELINE V2 ==="
git switch -c feature/wo-pipeline-v2 2>/dev/null || git checkout feature/wo-pipeline-v2
mkdir -p tools/wo_pipeline launchd docs followup
cp -R /tmp/wo_pipeline_backup/tools/wo_pipeline/* tools/wo_pipeline/ 2>/dev/null || true
cp /tmp/wo_pipeline_backup/launchd/*.plist launchd/ 2>/dev/null || true
cp /tmp/wo_pipeline_backup/docs/WO_PIPELINE_V2.md docs/ 2>/dev/null || true
cp -R /tmp/wo_pipeline_backup/followup/state followup/ 2>/dev/null || true
chmod +x tools/wo_pipeline/*.zsh 2>/dev/null || true

git add tools/wo_pipeline/ launchd/ docs/ followup/state/ 2>/dev/null || true
git commit -m "feat(wo_pipeline): restore WO Pipeline v2 from backup" 2>/dev/null || true
echo "✅ WO Pipeline v2 restored on feature/wo-pipeline-v2"

echo ""
echo "=== RECOVERY COMPLETE ==="
git branch | grep "^\*"
git status --short | head -5
