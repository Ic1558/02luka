#!/usr/bin/env zsh
# Auto-commit script for 02luka project
# Run every hour via cron or LaunchAgent

cd ~/02luka || exit 1

# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain)

if [[ -n "$UNCOMMITTED" ]]; then
    echo "[$(date)] 💾 Auto-committing uncommitted files..."
    
    # Add all changes
    git add -A
    
    # Create auto-commit with timestamp
    git commit -m "auto-save: $(date '+%Y-%m-%d %H:%M:%S')

Automatically committed by auto_commit.zsh
Prevents data loss from uncommitted files

Files changed:
$(git status --porcelain | head -10)
"
    
    echo "[$(date)] ✅ Auto-commit complete"
    
    # Optional: Auto-push (commented out for safety)
    # git push origin $(git branch --show-current)
else
    echo "[$(date)] ℹ️  No uncommitted changes"
fi
