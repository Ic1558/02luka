# 🎯 Workspace Split: Team Announcement

**Date:** 2025-12-13  
**Status:** Phase A Complete → Phase B Active  
**Impact:** All team members / CLS agents

---

## 📢 TL;DR

**What Changed:**
- Repository (`~/02luka`) = **Code only** (Git-tracked)
- Workspace (`~/02luka_ws`) = **Runtime data** (NOT in Git)
- Workspace paths in repo are **symlinks** → workspace

**New Rules:**
- ✅ **USE:** `git clean-safe` (safe clean)
- ❌ **NEVER:** `git clean -fd` (will NOT delete workspace data)

**Protection:**
- Pre-commit hook blocks invalid commits
- CI checks workspace guard on PR/Push

---

## 🚫 Prohibited Operations

### ❌ NEVER Do This

```bash
# ❌ This will NOT delete workspace data (protected)
git clean -fd

# ❌ Creating real directories at workspace paths
mkdir g/data  # Wrong! Must be symlink
```

### ✅ Always Do This

```bash
# ✅ Safe clean (use this instead)
git clean-safe -n   # Dry-run first
git clean-safe -f   # Then force

# ✅ Setup workspace (first time or after clone)
zsh tools/bootstrap_workspace.zsh
```

---

## 🛡️ Automatic Protection

**Pre-commit Hook:**
- Automatically runs guard script before commits
- **Blocks commits** if workspace paths are real directories (must be symlinks)

**CI Workflow:**
- Runs workspace guard check on PR/Push
- Fails PR if workspace rules violated

**Result:** You can't accidentally break workspace split rules.

---

## 📚 Quick Reference

**Workspace Paths (must be symlinks):**
- `g/data/` → `~/02luka_ws/g/data/`
- `g/telemetry/` → `~/02luka_ws/g/telemetry/`
- `g/followup/` → `~/02luka_ws/g/followup/`
- `mls/ledger/` → `~/02luka_ws/mls/ledger/`
- `bridge/processed/` → `~/02luka_ws/bridge/processed/`

**Verification:**
```bash
# Check guard
zsh tools/guard_workspace_inside_repo.zsh

# Verify symlinks
readlink g/data
```

---

## 🔧 Setup (New Team Members)

```bash
cd ~/02luka
zsh tools/bootstrap_workspace.zsh
git config --global alias.clean-safe '!zsh ~/02luka/tools/safe_git_clean.zsh'
```

---

## 📖 Full Documentation

- **Quick Reference:** `g/docs/WORKSPACE_SPLIT_README.md`
- **Architecture:** `g/docs/ADR_001_workspace_split.md`
- **Guard Script:** `tools/guard_workspace_inside_repo.zsh`
- **Bootstrap:** `tools/bootstrap_workspace.zsh`

---

## ❓ FAQ

**Q: What if I accidentally run `git clean -fd`?**  
A: Workspace data is safe (in `~/02luka_ws/`, not in repo). But use `git clean-safe` to be safe.

**Q: What if guard script fails?**  
A: Run `zsh tools/bootstrap_workspace.zsh` to fix symlinks.

**Q: Can I still use normal git commands?**  
A: Yes! `git add`, `git commit`, `git push` all work normally. Only `git clean` needs the safe version.

---

**Questions?** See `g/docs/WORKSPACE_SPLIT_README.md` or check guard script output.

---

**Last Updated:** 2025-12-13 (Phase B Active)
