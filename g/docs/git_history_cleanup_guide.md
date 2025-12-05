# Git History Secret Cleanup Guide

**Last Updated**: 2025-12-06  
**Status**: Active

---

## Overview

This guide explains how to remove exposed secrets (Telegram bot tokens, API keys) from git history after they've been accidentally committed.

**⚠️ WARNING**: Rewriting git history is a destructive operation that:
- Changes all commit hashes
- Requires force push
- Requires all collaborators to re-clone
- Cannot be undone easily

---

## Prerequisites

### 1. Install Cleanup Tool (Recommended)

**Option A: git-filter-repo** (Recommended - Fastest)
```bash
brew install git-filter-repo
```

**Option B: BFG Repo-Cleaner** (Alternative)
```bash
brew install bfg
```

**Option C: Built-in git filter-branch** (Slower, but no install needed)
- Already available in git

### 2. Backup Repository

**Create backup branch:**
```bash
cd ~/02luka
git branch backup-before-secret-cleanup-$(date +%Y%m%d_%H%M%S)
```

**Or clone to backup location:**
```bash
cd ~
git clone ~/02luka ~/02luka-backup-$(date +%Y%m%d)
```

---

## Method 1: Using git-filter-repo (Recommended)

### Step 1: Dry Run (Check What Will Change)

```bash
cd ~/02luka
./tools/git_history_secret_cleanup.sh --dry-run --backup
```

### Step 2: Perform Cleanup

```bash
./tools/git_history_secret_cleanup.sh --backup
```

**Manual method:**
```bash
# Create replacements file
cat > /tmp/replacements.txt << EOF
7683891739:AAFnHw3zkXBZecmzIty4iYTv8e_QxZYgAmk==>[REDACTED - See .env.local]
7966074921:AAHpvlTMnTBuRNahSD7-23H9JFL_5Ay6r3s==>[REDACTED - See .env.local]
7563701343:AAHhpC8SW2ByepPTC10iaDrueYECFj7uReg==>[REDACTED - See .env.local]
8412723056:AAHWPvOauQ4QHoz3v0mUM1ZCI2hWJc4uGcU==>[REDACTED - See .env.local]
7907375805:AAHRJqOYGuZUueBUdGpSklgOztao0LObPjY==>[REDACTED - See .env.local]
EOF

# Run filter-repo
git filter-repo --replace-text /tmp/replacements.txt --force
```

---

## Method 2: Using BFG Repo-Cleaner

```bash
# Create replacements file
cat > /tmp/replacements.txt << EOF
7683891739:AAFnHw3zkXBZecmzIty4iYTv8e_QxZYgAmk==>[REDACTED - See .env.local]
7966074921:AAHpvlTMnTBuRNahSD7-23H9JFL_5Ay6r3s==>[REDACTED - See .env.local]
7563701343:AAHhpC8SW2ByepPTC10iaDrueYECFj7uReg==>[REDACTED - See .env.local]
8412723056:AAHWPvOauQ4QHoz3v0mUM1ZCI2hWJc4uGcU==>[REDACTED - See .env.local]
7907375805:AAHRJqOYGuZUueBUdGpSklgOztao0LObPjY==>[REDACTED - See .env.local]
EOF

# Run BFG
bfg --replace-text /tmp/replacements.txt

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

---

## Method 3: Using git filter-branch (Built-in)

```bash
# Replace secret in all commits
git filter-branch --force --tree-filter \
  "find . -type f -exec sed -i '' 's|7683891739:AAFnHw3zkXBZecmzIty4iYTv8e_QxZYgAmk|[REDACTED - See .env.local]|g' {} +" \
  --prune-empty --tag-name-filter cat -- --all

# Repeat for each secret...
```

**Note**: This is slower but doesn't require additional tools.

---

## Verification

### Check if secrets are removed:

```bash
# Search for secrets in history
git log --all -S "7683891739:AAFnHw3zkXBZecmzIty4iYTv8e_QxZYgAmk"

# Should return no results
```

### Check specific file:

```bash
# View file at specific commit
git show <commit-hash>:g/reports/feature_notification_system_v1_complete_PLAN.md | grep -i "token"
```

---

## After Cleanup

### 1. Force Push to Remote

**⚠️ WARNING**: This overwrites remote history!

```bash
# Push all branches
git push --force --all

# Push all tags
git push --force --tags
```

### 2. Notify Collaborators

All collaborators must:
1. **Re-clone the repository** (cannot just pull)
2. Or reset their local copy:
   ```bash
   git fetch origin
   git reset --hard origin/main
   ```

### 3. Rotate Exposed Secrets

Since secrets were exposed in git history:
1. Generate new Telegram bot tokens
2. Update `.env.local`
3. Revoke old tokens in Telegram BotFather
4. Update any scripts using the tokens

---

## Rollback (If Needed)

If you created a backup branch:

```bash
# Restore from backup
git reset --hard backup-before-secret-cleanup-YYYYMMDD_HHMMSS
```

Or restore from backup clone:

```bash
cd ~/02luka
rm -rf .git
cp -r ~/02luka-backup-YYYYMMDD/.git .
```

---

## Prevention

### 1. Install Pre-commit Hook

```bash
cd ~/02luka
ln -s ../../tools/pre_commit_secret_check.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### 2. Use .gitignore

Ensure `.env.local` and other secret files are in `.gitignore`:

```bash
# .gitignore
.env.local
*.secret
*.key
.env.*.local
```

### 3. Use git-secrets (Optional)

```bash
brew install git-secrets
git secrets --install
git secrets --register-aws  # For AWS keys
# Add custom patterns for Telegram tokens
```

---

## Troubleshooting

### Issue: "fatal: cannot read commit object"

**Solution**: Repository may have corruption. Try:
```bash
git fsck --full
git gc --prune=now
```

### Issue: Cleanup too slow

**Solution**: Use `git-filter-repo` instead of `git filter-branch` (10-50x faster)

### Issue: Collaborators can't pull after force push

**Solution**: They must re-clone or reset:
```bash
git fetch origin
git reset --hard origin/main
```

---

## Related Files

- `tools/pre_commit_secret_check.sh` - Pre-commit hook to prevent secrets
- `tools/git_history_secret_cleanup.sh` - Automated cleanup script
- `.gitignore` - Ensure secrets are ignored

---

**Last Updated**: 2025-12-06  
**Status**: Active



