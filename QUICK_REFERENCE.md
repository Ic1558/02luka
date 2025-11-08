# PR Conflict Resolution - Quick Reference Card

## 🎯 One-Liners

```bash
# Check for conflicts
./check_pr_conflicts.sh

# Resolve all conflicts (automatic)
./resolve_pr_conflicts.sh

# Interactive menu
./resolve_all_conflicts.sh

# Generate patches
./create_resolution_patches.sh
```

---

## 📦 Files

| File | Purpose |
|------|---------|
| `resolve_all_conflicts.sh` | 🎮 Interactive menu - **START HERE** |
| `resolve_pr_conflicts.sh` | 🤖 Automatic resolution |
| `check_pr_conflicts.sh` | 🔍 Detect conflicts |
| `create_resolution_patches.sh` | 📦 Generate patches |
| `CONFLICT_RESOLUTION_README.md` | 📖 Complete documentation |
| `CONFLICT_RESOLUTION_GUIDE.md` | 📚 Detailed guide |
| `PR_CONFLICTS_SUMMARY.md` | 📊 Executive summary |

---

## 🚀 Quick Start

### First Time? Use Interactive Menu

```bash
./resolve_all_conflicts.sh
```

### Know What You're Doing? Go Automatic

```bash
./resolve_pr_conflicts.sh
```

### Need Manual Control? Follow Guide

```bash
less CONFLICT_RESOLUTION_GUIDE.md
```

---

## 🎯 Conflicting Branches

1. `codex/add-user-authentication-feature`
2. `codex/add-user-authentication-feature-hhs830`
3. `codex/add-user-authentication-feature-not1zo`
4. `codex/add-user-authentication-feature-yiytty`

**Reason:** Architecture changed (boss-api removed)

---

## ⚡ Resolution Strategy

For each branch:

```bash
git checkout <branch>
git merge origin/main
git rm boss-api/server.cjs          # Accept deletion
git checkout --theirs scripts/smoke.sh  # Accept main's version
git add scripts/smoke.sh
git commit -m "Resolve merge conflicts with main"
git push origin <branch>
```

---

## ✅ Verification

```bash
# Before
./check_pr_conflicts.sh
# Output: Branches with conflicts: 4

# Run resolution
./resolve_pr_conflicts.sh

# After
./check_pr_conflicts.sh
# Output: Branches with conflicts: 0 ✓
```

---

## 🚨 Troubleshooting

| Problem | Solution |
|---------|----------|
| Permission denied (403) | Use patch method or manual push |
| Branch not found | Run `git fetch origin` |
| Merge in progress | Run `git merge --abort` |
| Script not executable | Run `chmod +x *.sh` |

---

## 📞 Help

1. **Interactive menu:** `./resolve_all_conflicts.sh` → Option 3 (View Guide)
2. **Full documentation:** `CONFLICT_RESOLUTION_README.md`
3. **Detailed guide:** `CONFLICT_RESOLUTION_GUIDE.md`
4. **Manual steps:** See guide section "Step-by-Step Manual Resolution"

---

**Status:** ✅ Ready to resolve
**Time to resolve:** ~5 minutes (automatic) or ~20 minutes (manual)
