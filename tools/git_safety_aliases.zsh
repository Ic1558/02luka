# Safety Aliases for Git Operations
# Add to ~/.zshrc

# Safe git checkout - stash untracked files first
function git-checkout-safe() {
    # Stash ALL files including untracked
    git stash push -u -m "auto-stash before checkout $(date +%Y%m%d_%H%M%S)"
    
    # Now checkout
    git checkout "$@"
    
    echo ""
    echo "💡 Your uncommitted files are stashed."
    echo "   Restore with: git stash pop"
}

# Safe git clean - backup first
function git-clean-safe() {
    BACKUP_DIR="$HOME/02luka/.git/clean-backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup untracked files
    git ls-files --others --exclude-standard | while read file; do
        mkdir -p "$BACKUP_DIR/$(dirname "$file")"
        cp "$file" "$BACKUP_DIR/$file" 2>/dev/null
    done
    
    echo "✅ Backed up to: $BACKUP_DIR"
    
    # Now clean
    git clean "$@"
}

# Replace dangerous commands with safe versions
alias git-checkout='git-checkout-safe'
alias git-clean='git-clean-safe'

# Quick commit alias
alias qc='git add -A && git commit -m "quick save: $(date +%H:%M)"'

# Show uncommitted files
alias git-uncommitted='git status --porcelain'

echo "🛡️  Git safety aliases loaded"
echo "   - git-checkout → auto-stash before checkout"
echo "   - git-clean → auto-backup before clean"
echo "   - qc → quick commit all changes"

# --- Workflow Chain: Review -> Snapshot -> Save ---
function dev_review_save() {
    (
        cd "${LUKA_MEM_REPO_ROOT:-$HOME/02luka}" || return 1
        if [[ -f "./tools/workflow_dev_review_save.zsh" ]]; then
            ./tools/workflow_dev_review_save.zsh
        else
            echo "❌ Workflow script not found in $(pwd)/tools/"
            return 1
        fi
    )
}
alias drs='dev_review_save'

function dev_review_save_status() {
    (
        cd "${LUKA_MEM_REPO_ROOT:-$HOME/02luka}" || return 1
        if [[ -f "./tools/workflow_dev_review_save_status.zsh" ]]; then
            ./tools/workflow_dev_review_save_status.zsh "$@"
        else
            echo "❌ Status script not found in $(pwd)/tools/"
            return 1
        fi
    )
}
alias drs-status='dev_review_save_status'

echo "   - drs → dev review save chain (Review->Snapshot->Save)"
echo "   - drs-status → show recent Review->Snapshot->Save runs"
