# File Structure Migration Guide

**Date:** 2025-11-12  
**Status:** Ready for Execution

---

## Quick Start

### Step 1: Dry-Run (Safe Preview)

```bash
~/02luka/tools/fsorg_migrate.zsh
```

This shows what files will be moved **without actually moving them**.

### Step 2: Review Output

Check the `[dry-run]` commands to verify:
- Files are going to correct locations
- No unexpected files are being moved
- Directory structure looks correct

### Step 3: Apply Migration

```bash
~/02luka/tools/fsorg_migrate.zsh --apply
```

This actually moves files using `git mv` (preserves git history).

### Step 4: Commit Changes

```bash
git status                    # Review changes
git commit -m "chore(fsorg): migrate reports into function-first structure"
git push origin main
```

---

## What Gets Moved

### Phase 5 Reports → `g/reports/phase5_governance/`
- Feature specs and plans
- Deployment certificates
- Code reviews
- Governance audits
- Production readiness reports

### Phase 6 Paula Reports → `g/reports/phase6_paula/`
- Feature specs and plans
- Deployment certificates
- Code reviews
- Deployment summaries

### System Reports → `g/reports/system/`
- System status reports
- Undeployed scans
- Weekly governance reports
- System-wide code reviews

---

## Post-Migration Checklist

### ✅ Verify Structure

```bash
# Check directories created
ls -d g/reports/{phase5_governance,phase6_paula,system}

# Check files moved
ls g/reports/phase5_governance/*.md | head -5
ls g/reports/phase6_paula/*.md | head -5
ls g/reports/system/*.md | head -5
```

### ✅ Verify LaunchAgents

```bash
# LaunchAgents should still work (tools/ unchanged)
launchctl list | grep -E "(paula|governance|metrics)"
```

### ✅ Update CI/Workflows (if needed)

If CI workflows reference old report paths, update to:
- `g/reports/phase5_governance/*.md`
- `g/reports/phase6_paula/*.md`
- `g/reports/system/*.md`

### ✅ Verify Scripts

```bash
# Test key scripts still work
tools/phase4_acceptance.zsh
tools/memory_hub_health.zsh
```

---

## Weekly Recap Setup

### Install LaunchAgent

```bash
# Copy plist to LaunchAgents
cp ~/02luka/LaunchAgents/com.02luka.governance.weekly.plist \
   ~/Library/LaunchAgents/

# Load LaunchAgent
launchctl load ~/Library/LaunchAgents/com.02luka.governance.weekly.plist

# Verify loaded
launchctl list | grep governance.weekly
```

### Manual Test

```bash
# Test weekly recap generator
~/02luka/tools/weekly_recap_generator.zsh

# Review output
cat g/reports/system/system_governance_WEEKLY_*.md
```

### Schedule

- **Runs:** Every Sunday at 08:00
- **Output:** `g/reports/system/system_governance_WEEKLY_YYYYMMDD.md`
- **Process:** Aggregates daily digests from past week

---

## Troubleshooting

### Issue: Files already in target directory

**Solution:** Script skips files already in correct location.

### Issue: Git mv fails

**Solution:** 
1. Check if files are staged: `git status`
2. Unstage if needed: `git reset HEAD <file>`
3. Retry migration

### Issue: LaunchAgent not finding tools

**Solution:** 
- Tools are in `tools/` (unchanged)
- Only reports moved
- LaunchAgents should still work

### Issue: CI/Workflow breaks

**Solution:**
1. Find old paths in workflows
2. Update to new paths:
   - `g/reports/phase5_governance/*.md`
   - `g/reports/phase6_paula/*.md`
   - `g/reports/system/*.md`

---

## Rollback

If migration causes issues:

```bash
# Rollback git changes
git reset --hard HEAD~1

# Or restore specific files
git checkout HEAD -- g/reports/phase5_governance/
```

---

## Next Steps

1. **Run migration** (dry-run first)
2. **Verify structure** (check directories)
3. **Test automation** (LaunchAgents, scripts)
4. **Update CI** (if needed)
5. **Commit and push**

---

**Guide Created:** 2025-11-12T15:35:00Z  
**Author:** CLS (Cognitive Local System Orchestrator)
