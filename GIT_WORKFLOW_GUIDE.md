# Git Workflow Guide for 02luka

**Date:** 2025-11-05
**Issue:** Nested Git repositories causing merge conflicts

## Current Situation

### Repository Structure
```
~/02luka/
├── .git/          ← Main repo (github.com:Ic1558/02luka)
└── g/
    └── .git/      ← Nested repo (SAME GitHub URL!)
```

### Problem
- **Unrelated histories**: Local main and GitHub main have different commit histories
- **Nested repos**: `g/` is a separate Git repo inside the main repo
- **Push hangs**: Git can't handle nested repos without proper configuration

## Solutions

### Option 1: Use Separate Working Directories (RECOMMENDED)

**For CLS/Cursor setup work** → Use `~/02luka/` (current location)
**For g/ operational data** → Use `~/02luka/g/` or `~/dev/02luka-repo/`

```bash
# Work on CLS/Cursor/tools → ~/02luka
cd ~/02luka
git status
git add CLS.md .cursor/
git commit -m "feat: CLS updates"

# Work on g/ data → ~/dev/02luka-repo
cd ~/dev/02luka-repo
git status
git add reports/ knowledge/
git commit -m "docs: update reports"
git push origin main
```

### Option 2: Convert g/ to Git Submodule

```bash
cd ~/02luka

# Remove g from Git tracking
git rm --cached -r g

# Add as submodule
git submodule add git@github.com:Ic1558/02luka.git g
git submodule init
git submodule update

# Commit
git add .gitmodules g
git commit -m "chore: convert g to Git submodule"
```

### Option 3: Remove Nested .git (DESTRUCTIVE)

**⚠️ WARNING: This loses g/ Git history!**

```bash
cd ~/02luka
mv g/.git g/.git.backup.$(date +%Y%m%d_%H%M)
git add g/
git commit -m "chore: flatten g directory structure"
```

## Current Recommended Workflow

### For Now: Push CLS Files Only

```bash
cd ~/02luka

# Create feature branch
git checkout -b clc/cursor-cls-integration

# Add only CLS-related files (exclude g/)
git add CLS/ CLS.md .cursor/ .cursorrules AGENTS.md CLAUDE.md .gitignore .vscode/ 02luka.code-workspace

# Commit
git commit -m "feat: Add CLS system orchestrator and Cursor integration"

# Push to new branch (safe, won't affect main)
git push -u origin clc/cursor-cls-integration
```

### For g/ Changes

```bash
cd ~/dev/02luka-repo  # or ~/02luka/g
git status
git add <files>
git commit -m "docs: update"
git push origin main
```

## Unrelated Histories Issue

Local and GitHub main branches don't share history. To fix:

```bash
# If you want to force merge (creates messy history)
git pull --allow-unrelated-histories origin main

# OR: Keep branches separate (cleaner)
git checkout -b local/my-work
git push -u origin local/my-work
# Then merge via GitHub PR
```

## Best Practice Going Forward

1. **~/02luka/** - For system files (CLS, AGENTS.md, tools, scripts)
2. **~/dev/02luka-repo** - For operational data (reports, knowledge, logs)
3. **Use feature branches** - Never push directly to main
4. **Pull before push** - Always `git pull` before `git push`
5. **Check .gitignore** - Ensure logs and temp files are excluded

## Quick Reference

```bash
# Check what will be pushed
git diff origin/main..HEAD --name-status

# Check if histories are related
git merge-base main origin/main

# See all remotes
git remote -v

# See branch tracking
git branch -vv

# Safely push to new branch
git checkout -b feature/my-work
git push -u origin feature/my-work
```

## Questions?

Ask CLC or check:
- `~/02luka/AGENTS.md` - System rules
- `~/02luka/CLS.md` - CLS documentation
- GitHub: https://github.com/Ic1558/02luka
