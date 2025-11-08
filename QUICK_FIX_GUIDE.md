# Quick Fix Guide: PR Conflicts & CI/CD Issues

## 🚨 CRITICAL: pages.yml YAML Syntax Error (5 minutes)

**Location**: `.github/workflows/pages.yml` lines 45 and 52

### Fix:
```diff
- cat > dist/manifest.json << JSON
+ cat > dist/manifest.json << 'JSON'
```

### Verify:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pages.yml'))"
echo $?  # Should return 0
```

---

## 🔴 HIGH PRIORITY: Close Obsolete Branches (4 minutes)

### Branch 1: chore/auto-update-branch
- 222 commits behind main
- Based on deleted boss-api architecture
- **Action**: Close PR with message:
  ```
  Closing due to:
  - 222 commits behind main
  - Based on deprecated boss-api/boss-ui architecture
  - File changes cannot be salvaged (targets deleted components)
  - Recommend: Create new PR based on current architecture
  ```

### Branch 2: chore/ci-docs-links
- 222 commits behind main
- Same architectural obsolescence
- **Action**: Close PR with similar message

**Command to close (via GitHub API)**:
```bash
gh pr close <PR_NUMBER> -c "Closing: architecture deprecated, branch unmergeable"
```

---

## 🟡 MEDIUM PRIORITY: Rebase Recent Branches (2-3 hours)

### Batch Rebase Script:
```bash
#!/bin/bash
branches=(
  "claude/ci-optin-smoke-011C"
  "claude/ci-reliability-pack-011C"
  "claude/phase-16-bus"
  "claude/phase-17-ci-observer"
  "claude/phase-18-ops-sandbox-runner"
  "claude/phase-19-ci-hygiene-health"
  "claude/phase-19.1-gc-hardening"
  "claude/phase15-rag-faiss-prod-011CUrwXGH2CAhL3tptUTayj"
  "claude/phase15-router-core-akr-011CUrtXLeMoxBZqCMowpFz8"
  "claude/fix-ci-node-lockfile-check-011CUrjUCx7jV39sFNDLkRMo"
  "claude/fix-dangling-symlink-chmod-011CUrnthGyres339RYKRCTj"
  "claude/exploration-and-research-011CUrRfU1hPvBmZXZqjgN9M"
)

for branch in "${branches[@]}"; do
  echo "Rebasing: $branch"
  git checkout "remotes/origin/$branch" || git fetch origin "$branch"
  git rebase origin/main
  if [ $? -eq 0 ]; then
    echo "✅ $branch rebased successfully"
    # Force push (use with caution!)
    # git push origin "$branch" -f
  else
    echo "❌ $branch had conflicts, manual intervention needed"
    git rebase --abort
  fi
done
```

### Manual Rebase (for one branch):
```bash
git fetch origin
git checkout <branch-name>
git rebase origin/main

# If conflicts occur:
git status  # See conflicts
# Edit files to resolve
git add .
git rebase --continue

# Force push to update PR
git push origin <branch-name> -f
```

---

## 🟢 OPTIONAL: Add YAML Linting (15 minutes)

### Add to `.github/workflows/ci.yml`:
```yaml
  lint-workflows:
    name: Lint Workflows
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint workflows
        run: |
          sudo apt-get install -y yamllint
          yamllint .github/workflows/
```

### Make Required:
- Go to GitHub repo settings
- Branch protection rules → Add rule for main
- Add "lint-workflows" as required check

---

## 📊 Conflict Status Summary

```
BEFORE: 14 conflicting branches
  ├─ 2 unmergeable (222 commits behind) ← CLOSE
  ├─ 5 with only .gitignore conflict ← EASY REBASE
  ├─ 7 with ci.yml conflict ← MEDIUM REBASE
  └─ 0 beyond recovery

AFTER: 0 conflicting branches
  ├─ 2 closed
  └─ 12 merged
```

---

## ✅ Verification Checklist

- [ ] pages.yml YAML syntax fixed and verified
- [ ] pages.yml workflow runs successfully
- [ ] 2 obsolete branches closed
- [ ] All 12 remaining branches rebased
- [ ] All branches mergeable (no conflicts)
- [ ] YAML linting added to CI
- [ ] All tests pass after merge

---

## 📈 Prevention Measures (Optional but Recommended)

### 1. Branch Lifecycle Automation
```yaml
# Add to .github/workflows/branch-cleanup.yml
name: Cleanup Stale Branches
on:
  schedule:
    - cron: '0 0 * * *'
jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Close stale branches
        run: |
          # Close branches >30 days old
          # Notify branches >20 days old
```

### 2. Architecture Deprecation Notice
Create `docs/DEPRECATION.md`:
```markdown
# Deprecated Components

## boss-api/boss-ui (Deprecated: Nov 7, 2025)
- **Status**: Removed from main branch
- **Reason**: Superseded by native agent-based architecture
- **Migration**: See [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)
- **Affected Branches**: Notify owners immediately
```

### 3. Refactor Communication Template
When making major changes:
1. Create issue: "Architecture Change: [Component]"
2. Post announcement in team channel
3. Set 7-day notice period before merge
4. Notify active branch owners
5. Document in DEPRECATION.md
6. Provide migration guide

---

## 🆘 Troubleshooting

### "Conflict during rebase"
```bash
git status  # See conflicts
# Edit conflicting files
git add .
git rebase --continue
```

### "Force push rejected"
```bash
# Check branch protection rules
# May need admin approval
# Or temporarily disable for this branch
```

### "Can't close old PR"
```bash
# Use GitHub web UI instead:
# 1. Go to PR page
# 2. Scroll down, click "Close pull request"
# 3. Add comment explaining closure
```

### "YAML lint fails on workflow changes"
```bash
# Test locally first:
yamllint .github/workflows/ci.yml

# Common issues:
# - Unquoted multi-line strings
# - Missing colons
# - Invalid indentation
```

---

## 📞 Questions?

- **pages.yml error**: See ROOT_CAUSE_ANALYSIS.md line 500+
- **Branch deletion**: See EXECUTIVE_SUMMARY.md "Decision Matrix"
- **Rebase help**: See ROOT_CAUSE_ANALYSIS.md "Recommendations"
- **Timeline**: See CONFLICT_VISUALIZATION.txt "Timeline section"

---

**Last updated**: November 7, 2025
**Estimated time to complete**: 3-4 hours
**Risk level**: Low (no data loss, clear solution path)
