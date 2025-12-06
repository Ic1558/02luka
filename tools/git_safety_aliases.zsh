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
