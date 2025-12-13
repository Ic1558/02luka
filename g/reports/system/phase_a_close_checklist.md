# Phase A Close: Checklist
**Date:** 2025-12-13  
**Status:** Ready for Execution

---

## ✅ Phase A Complete Confirmation

**Verified:**
- ✅ Pre-commit hook: Blocking mode (`exec zsh tools/guard_workspace_inside_repo.zsh`)
- ✅ Bootstrap script: Migrated all paths to symlinks
- ✅ Guard script: Passes all checks
- ✅ All workspace paths: Symlinks pointing to `~/02luka_ws/`
- ✅ Git tracking: Workspace paths not tracked

---

## 📋 Phase A Close Tasks

### 1. Commit Phase A Changes

**Files to commit:**
```bash
git add .gitignore
git add .cursorrules
git add .git/hooks/pre-commit
git add tools/bootstrap_workspace.zsh
git add tools/guard_workspace_inside_repo.zsh
git add tools/safe_git_clean.zsh
git add g/docs/ADR_001_workspace_split.md
git add g/docs/WORKSPACE_SPLIT_README.md
git add .github/workflows/workspace_guard.yml
```

**Commit message:**
```
feat: Phase A - Workspace split hardening complete

- Fix guard script bug (replace file command)
- Restore pre-commit hook to blocking mode
- Complete workspace migration (all paths → symlinks)
- Add ADR-001: Workspace split architecture
- Add workspace split README
- Add CI workflow for workspace guard

Phase A Status:
✅ Guard script: Working
✅ Pre-commit: Blocking mode
✅ All paths: Symlinks
✅ System: Production-safe

Tag: ws-split-phase-a-ok
```

### 2. Create Tag

```bash
git tag -a ws-split-phase-a-ok -m "Phase A: Workspace split hardening complete

- Guard script working
- Pre-commit enforcing
- All paths migrated to symlinks
- System production-safe"
```

### 3. Push (if ready)

```bash
git push origin main
git push origin ws-split-phase-a-ok
```

---

## 📝 Documentation Created

- ✅ `g/docs/ADR_001_workspace_split.md` - Architecture decision record
- ✅ `g/docs/WORKSPACE_SPLIT_README.md` - Quick reference guide
- ✅ `.github/workflows/workspace_guard.yml` - CI check

---

## 🎯 Next Steps (Phase B & C)

**Phase B - Hardening:**
- CI check (workflow created, ready to enable)
- Documentation (ADR + README created)
- Alias for safe clean (optional)

**Phase C - Ops Confidence:**
- Dry-run safe clean
- Simulate failure test

---

**Status:** Ready for commit and tag
