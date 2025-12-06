# Git Safety System - Implementation Guide

**Problem:** Uncommitted files lost during git operations (checkout, clean, etc.)

**Solution:** 4-layer safety net

---

## Layer 1: Git Pre-Checkout Hook ✅

**File:** `.git/hooks/pre-checkout`

**What it does:**
- Runs BEFORE every `git checkout`
- Auto-backs up untracked files to `.git/auto-backups/`
- Allows checkout to proceed
- You can restore files later

**Status:** ✅ Installed

---

## Layer 2: Hourly Auto-Commit (Optional)

**Files:**
- `tools/auto_commit.zsh`
- `Library/LaunchAgents/com.02luka.auto-commit.plist`

**What it does:**
- Runs every hour
- Auto-commits ALL changes with timestamp
- Creates commits like: `auto-save: 2025-12-06 18:45:00`
- Never lose work again

**Install:**
```bash
cp ~/02luka/Library/LaunchAgents/com.02luka.auto-commit.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.02luka.auto-commit.plist
```

**Status:** ⏳ Created, not loaded (you decide)

---

## Layer 3: Safe Git Aliases ✅

**File:** `tools/git_safety_aliases.zsh`

**Add to ~/.zshrc:**
```bash
source ~/02luka/tools/git_safety_aliases.zsh
```

**New commands:**
- `git-checkout-safe` → Stashes before checkout
- `git-clean-safe` → Backs up before clean
- `qc` → Quick commit (git add -A && commit)

**Status:** ✅ Created, needs sourcing

---

## Layer 4: VSCode Auto-Save

**Add to VSCode settings.json:**
```json
{
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 1000,
  "git.autoStash": true,
  "git.confirmSync": false
}
```

**Status:** Already configured in workspace

---

## Quick Setup (30 seconds)

```bash
# 1. Add safety aliases to ~/.zshrc
echo "\nsource ~/02luka/tools/git_safety_aliases.zsh" >> ~/.zshrc
source ~/.zshrc

# 2. (Optional) Enable hourly auto-commit
cp ~/02luka/Library/LaunchAgents/com.02luka.auto-commit.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.02luka.auto-commit.plist

# 3. Test
git-checkout main  # Should auto-stash first
```

---

## How It Protects You

**Before (DANGEROUS):**
```bash
$ touch important_report.md
$ git checkout main
→ important_report.md DELETED! 💥
```

**After (SAFE):**
```bash
$ touch important_report.md
$ git-checkout main
→ ✅ Stashed uncommitted files
→ ✅ Checkout successful
→ 💡 Restore with: git stash pop
```

---

## Backup Locations

**1. Pre-checkout backups:**
```
.git/auto-backups/YYYYMMDD_HHMMSS/
```

**2. Auto-commits:**
```
Git history: "auto-save: YYYY-MM-DD HH:MM:SS"
```

**3. Git stash:**
```
git stash list
git stash pop
```

---

## Recovery Commands

**Restore from pre-checkout backup:**
```bash
# List backups
ls -la ~/02luka/.git/auto-backups/

# Restore specific backup
cp -r ~/02luka/.git/auto-backups/20251206_184500/* ~/02luka/
```

**Restore from stash:**
```bash
git stash list
git stash pop  # Restore latest
```

**Restore from auto-commit:**
```bash
git log --grep="auto-save"
git checkout <commit-hash> -- <file>
```

---

## Recommendation

**Minimal (Low effort, high safety):**
1. ✅ Keep pre-checkout hook (already installed)
2. ✅ Add safety aliases to ~/.zshrc
3. ✅ Use `qc` for quick commits

**Maximum (Paranoid mode):**
1. All of the above
2. Enable hourly auto-commit
3. Enable auto-push (in auto_commit.zsh)

---

**Status:** Safety system ready to deploy! 🛡️
