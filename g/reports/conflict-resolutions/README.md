# Conflict Resolution Scripts

This directory contains automated scripts to resolve merge conflicts for all conflicting PRs.

## Quick Start

### For PR Maintainers

1. **Identify your PR** in the table below
2. **Run the appropriate script** for your PR
3. **Review and test** the changes
4. **Push** to your branch

## PR Resolution Guide

| PR # | Title | Script | Complexity |
|------|-------|--------|------------|
| #184 | FAISS/HNSW Vector Index | ✅ No conflicts - ready to merge | None |
| #208 | Phase 19.1 GC hardening | `fix-common-pattern.sh` | Low |
| #207 | Phase 19 CI hygiene | `fix-common-pattern.sh` | Low |
| #206 | Phase 18 Ops Sandbox | `fix-common-pattern.sh` | Low |
| #204 | Phase 16 bus | `fix-common-pattern.sh` | Low |
| #205 | Phase 17 observer | `fix-pr205-phase17-observer.sh` | Medium |
| #212 | Fix shell loop errors | `fix-pr212-shell-loops.sh` | Low |
| #217 | OCR validation hardening | `fix-pr217-ocr-validation.sh` | Low |
| #197 | Phase 15 Router Core | Manual - see notes below | High |
| #201 | CI reliability pack | Manual - see notes below | High |

## Usage Examples

### PR #208 (Common Pattern)
```bash
cd /path/to/02luka
./g/reports/conflict-resolutions/fix-common-pattern.sh claude/phase-19.1-gc-hardening
```

### PR #205 (Phase 17 Observer)
```bash
cd /path/to/02luka
./g/reports/conflict-resolutions/fix-pr205-phase17-observer.sh
```

### PR #212 (Shell Loops)
```bash
cd /path/to/02luka
./g/reports/conflict-resolutions/fix-pr212-shell-loops.sh
```

### PR #217 (OCR Validation)
```bash
cd /path/to/02luka
./g/reports/conflict-resolutions/fix-pr217-ocr-validation.sh
```

## Resolution Details

### Low Complexity (Automated)

These PRs have straightforward conflicts that can be resolved automatically:

**PRs #208, #207, #206, #204:**
- Conflict: pages.yml (heredoc vs printf)
- Conflict: .gitignore (verbose vs clean)
- Resolution: Accept origin/main's cleaner implementations
- Script: `fix-common-pattern.sh`

**PR #212:**
- Conflict: smoke.sh (pipe vs process substitution)
- Resolution: Accept origin/main's process substitution
- Script: `fix-pr212-shell-loops.sh`

**PR #217:**
- Conflict: smoke.sh (different feature sets)
- Resolution: Keep HEAD's enhanced auto-fix version
- Script: `fix-pr217-ocr-validation.sh`

### Medium Complexity

**PR #205:**
- Conflicts: pages.yml + .gitignore + smoke.sh
- Resolution: Hybrid approach for smoke.sh
- Combines process substitution (origin/main) + auto-fix (HEAD)
- Script: `fix-pr205-phase17-observer.sh`

### High Complexity (Manual Review Required)

**PR #197: Phase 15 Router Core**
- Conflict: .github/workflows/ci.yml
- Issue: New `router-selftest` job needs integration
- Action: Manually add job and update ci-summary dependencies

**PR #201: CI reliability pack**
- Conflicts: .github/workflows/ci.yml (multiple regions)
- Conflicts: CI_RELIABILITY_PACK.md (both added)
- Issue: Major structural changes across 6 regions
- Action: Manual merge with careful review of each section

## Testing After Resolution

After running any resolution script, always:

```bash
# 1. Review the changes
git show

# 2. Run smoke tests
./scripts/smoke.sh

# 3. Verify CI workflow syntax (if applicable)
yamllint .github/workflows/*.yml

# 4. Push to origin
git push -u origin <your-branch>
```

## Manual Resolution Notes

### PR #197 - Router Self-Test Integration

1. Check out the branch:
```bash
git checkout claude/phase15-router-core-akr-011CUrtXLeMoxBZqCMowpFz8
git merge origin/main --no-edit
```

2. Edit `.github/workflows/ci.yml`:
   - Keep existing RAG job from origin/main
   - Add router-selftest job from HEAD
   - Update ci-summary dependencies to include both

3. Commit and push

### PR #201 - CI Reliability Pack

This PR requires careful manual review of 6 conflict regions in ci.yml:

1. **Line 2:** Fix `true:` → `on:` (bug in HEAD)
2. **Lines 53-73:** Merge ops-gate job definition with enhanced logging
3. **Lines 86-94:** Use origin/main's fork protection
4. **Lines 119-142:** Preserve both job definitions
5. **Lines 148-158:** Use origin/main's strategy
6. **Lines 187-258:** Use origin/main's comprehensive ci-summary

For CI_RELIABILITY_PACK.md:
- Accept origin/main's comprehensive version (244 lines)

## Conflict Root Causes

Understanding why these conflicts occurred:

1. **PR #209** (pages heredoc fix) merged to main
   - Changed heredocs to printf in pages.yml
   - Affects PRs #208, #207, #206, #205, #204

2. **PR #210** (.gitignore cleanup) merged to main
   - Simplified .gitignore organization
   - Affects PRs #208, #207, #206, #205, #204

3. **PR #211** (shell loop fixes) merged to main
   - Fixed pipe-based loops with process substitution
   - Affects PRs #212, #217, #205

## Prevention Tips

To avoid conflicts in future PRs:

1. **Rebase regularly** against main
2. **Use draft PRs** for work-in-progress
3. **Coordinate changes** to shared files (CI workflows, .gitignore)
4. **Keep PRs small** and focused
5. **Merge quickly** after approval

## Getting Help

If you encounter issues with any resolution script:

1. Check the main resolution report: `/home/user/02luka/CONFLICT_RESOLUTIONS.md`
2. Review the conflict analysis in the script comments
3. Ask for help in the PR discussion

## Script Maintenance

All scripts in this directory:
- Use `set -eo pipefail` for safety
- Provide detailed output
- Check for remaining conflicts
- Include helpful next steps

To make scripts executable:
```bash
chmod +x g/reports/conflict-resolutions/*.sh
```

---

**Generated:** 2025-11-07
**Session:** claude/resolve-conflicting-prs-011CUu7xxmicXCMGtnjyUFkZ
