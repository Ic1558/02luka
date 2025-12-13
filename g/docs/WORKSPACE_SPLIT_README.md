# Workspace Split: Quick Reference

**TL;DR:** Repository code is separate from runtime data. Workspace paths are symlinks.

---

## 🎯 What is This?

**Repository (`~/02luka`):** Source code, scripts, docs (Git-tracked)  
**Workspace (`~/02luka_ws`):** Runtime data, logs, telemetry (NOT in Git)

**Connection:** Workspace paths in repo are **symlinks** pointing to workspace.

---

## ✅ Safe Operations

```bash
# Normal git operations (safe)
git add .
git commit -m "message"
git push

# Safe clean (use this instead of git clean -fd)
zsh tools/safe_git_clean.zsh -n   # Dry-run first
zsh tools/safe_git_clean.zsh -f   # Then force
```

---

## 🚫 Never Do This

```bash
# ❌ NEVER: This will delete workspace data
git clean -fd

# ❌ NEVER: Create real directories at workspace paths
mkdir g/data  # Wrong! Must be symlink

# ✅ CORRECT: Use bootstrap script
zsh tools/bootstrap_workspace.zsh
```

---

## 🔧 Setup (First Time)

```bash
cd ~/02luka
zsh tools/bootstrap_workspace.zsh
```

This will:
1. Create `~/02luka_ws/` directory
2. Migrate existing data to workspace
3. Create symlinks in repository

---

## ✅ Verification

```bash
# Check guard script
zsh tools/guard_workspace_inside_repo.zsh

# Verify symlinks
readlink g/data
readlink g/telemetry
readlink mls/ledger
```

**Expected:** All paths should point to `~/02luka_ws/...`

---

## 🛡️ Protection

**Pre-commit Hook:** Automatically runs guard script before commits  
**Guard Script:** Fails if workspace paths are real directories (must be symlinks)

**Result:** Commits are blocked if workspace rules are violated.

---

## 📚 More Info

- **ADR:** `g/docs/ADR_001_workspace_split.md`
- **Guard Script:** `tools/guard_workspace_inside_repo.zsh`
- **Bootstrap:** `tools/bootstrap_workspace.zsh`
- **Safe Clean:** `tools/safe_git_clean.zsh`

---

**Last Updated:** 2025-12-13 (Phase A Complete)
