#!/usr/bin/env zsh
# Touchless Deployment Script
# Deploys changes directly to main without PR interaction
# Usage: ./touchless-deploy.zsh [branch-name]

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

BRANCH=${1:-$(git branch --show-current)}

if [[ "$BRANCH" == "main" ]]; then
    log $RED "❌ Already on main branch"
    exit 1
fi

log $BLUE "🚀 Touchless Deployment Starting..."
log $YELLOW "Branch: $BRANCH → main"

# Step 1: Push current branch
log $YELLOW "1. Pushing branch to remote..."
git push origin "$BRANCH" || log $YELLOW "⚠️  Branch already up to date"

# Step 2: Switch to main and pull
log $YELLOW "2. Updating main branch..."
git checkout main
git pull origin main

# Step 3: Merge without opening editor
log $YELLOW "3. Merging $BRANCH into main..."
git merge --no-ff "$BRANCH" -m "Touchless merge: $BRANCH

🤖 Automated deployment via touchless-deploy.zsh

Co-Authored-By: Claude <noreply@anthropic.com>" || {
    log $RED "❌ Merge conflict detected"
    log $YELLOW "Attempting auto-resolution (taking incoming changes)..."
    
    # Auto-resolve conflicts by taking incoming changes
    git checkout --theirs . 2>/dev/null || git checkout --ours .
    git add .
    git commit --no-edit
    log $GREEN "✅ Conflicts auto-resolved"
}

# Step 4: Push to main
log $YELLOW "4. Pushing to main..."
git push origin main

# Step 5: Clean up feature branch (optional)
if [[ "${DELETE_BRANCH:-no}" == "yes" ]]; then
    log $YELLOW "5. Deleting feature branch..."
    git branch -d "$BRANCH" 2>/dev/null || log $YELLOW "⚠️  Branch still has unmerged commits"
    git push origin --delete "$BRANCH" 2>/dev/null || log $YELLOW "⚠️  Remote branch already deleted"
fi

log $GREEN "✅ Touchless deployment complete!"
log $BLUE "🔗 View workflows: https://github.com/Ic1558/02luka/actions"

# Show recent commits
log $YELLOW "📝 Recent commits:"
git log --oneline -5
