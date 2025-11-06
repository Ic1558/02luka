# PR Management Script - Quick Start Guide

## TL;DR

```bash
# 1. Preview (safe, no changes)
DRY_RUN=1 ./scripts/manage_prs.sh

# 2. Real run with logging
./scripts/manage_prs.sh | tee g/reports/ci/manage_prs_$(date +%Y%m%d_%H%M%S).log

# 3. Verify
for n in 182 181 114 113; do gh pr view $n --json state -q .state; done
```

---

## Pre-flight Checklist (30 seconds)

```bash
# Verify prerequisites
gh --version          # Should show 2.x+
gh auth status        # Must be authenticated
git status            # Should be on correct branch

# Set repo context (optional)
gh repo set-default Ic1558/02luka

# Fetch latest
git fetch --all --prune
git switch claude/manage-pull-requests-011CUrNc6nZs9hUSWTghraih
git pull
```

---

## Common Workflows

### First-Time Run (Safest)

```bash
# 1. Preview operations
DRY_RUN=1 bash scripts/manage_prs.sh

# 2. If output looks good, run for real
mkdir -p g/reports/ci
ts=$(date +%Y%m%d_%H%M%S)
bash scripts/manage_prs.sh | tee g/reports/ci/manage_prs_$ts.log

# 3. Commit the log
git add g/reports/ci/manage_prs_$ts.log
git commit -m "ci: PR batch run $ts"
git push
```

### Quick Run (After Testing)

```bash
bash scripts/manage_prs.sh | tee g/reports/ci/manage_prs_$(date +%Y%m%d_%H%M%S).log
```

### Fast Run (Skip Validation)

```bash
SKIP_SANITY=1 bash scripts/manage_prs.sh
```

---

## Troubleshooting

### "gh: command not found"
```bash
# macOS
brew install gh

# Linux
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

### "Resource not accessible by integration"
```bash
# Re-authenticate with full scopes
gh auth refresh -h github.com -s repo,workflow
```

### "could not apply <sha>" (rebase conflict on #169)
```bash
# Abort the rebase, fix manually
git rebase --abort
gh pr checkout 169
git fetch origin main
git rebase origin/main
# Resolve conflicts, then:
git rebase --continue
git push --force-with-lease
```

### Rate Limit Hit
```bash
# Use slower retries
RETRY_DELAY=10 bash scripts/manage_prs.sh

# Or check your rate limit
gh api rate_limit
```

---

## What Gets Modified

| Phase | Action | PRs | Destructive? |
|-------|--------|-----|--------------|
| 1 | Merge + delete branch | 182,181,114,113 | ✅ Yes |
| 2 | Re-run checks | 123-129 | ❌ No |
| 3 | Rebase + force-push | 169 | ⚠️ Rewrites history |
| 4 | Watch checks | 164 | ❌ No (read-only) |

**Always run DRY_RUN=1 first if unsure.**

---

## Automation Options

### Cron (Linux/macOS)

Add to crontab:
```bash
# Every 6 hours at :15
15 */6 * * * cd ~/02luka && bash scripts/manage_prs.sh >> g/reports/ci/manage_prs_cron.log 2>&1
```

### LaunchAgent (macOS)

See `g/reports/ci/meta_pr_body.md` for full plist example.

### GitHub Actions

```yaml
name: PR Management
on:
  schedule:
    - cron: '15 */6 * * *'  # Every 6 hours
  workflow_dispatch:        # Manual trigger

jobs:
  manage-prs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash scripts/manage_prs.sh
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## Verification Commands

After running the script:

```bash
# Check merged PRs
for n in 182 181 114 113; do
  echo -n "PR #$n: "
  gh pr view $n --json state -q .state
done

# Check re-run PRs (first and last)
gh pr checks 123
gh pr checks 129

# Check rebased PR
gh pr view 169 --json headRefName,mergeable -q '{branch:.headRefName,mergeable:.mergeable}'

# Check watched PR
gh pr checks 164
```

---

## Environment Variables

| Variable | Default | Example |
|----------|---------|---------|
| `DRY_RUN` | `0` | `DRY_RUN=1` |
| `SKIP_SANITY` | `0` | `SKIP_SANITY=1` |
| `RETRY_DELAY` | `2` | `RETRY_DELAY=5` |
| `GH_TOKEN` | (from gh auth) | `GH_TOKEN=ghp_...` |

---

## Expected Output

### Success Case
```
╔════════════════════════════════════════════════════════════╗
║          PR Management Script                              ║
╚════════════════════════════════════════════════════════════╝

═══ Phase 1: Merging PRs with squash ═══

→ Merging PR #182...
[EXEC] gh pr merge 182 --squash --delete-branch
✓ Merged

...

═══ Sanity Checks ═══

Merged PR states:
  PR #182: ✓ MERGED
  PR #181: ✓ MERGED
  PR #114: ✓ MERGED
  PR #113: ✓ MERGED

✓ All operations completed
Run timestamp: 2025-11-06T12:34:56+00:00
```

### Dry-Run Output
```
⚠ DRY-RUN MODE: No changes will be made

═══ Phase 1: Merging PRs with squash ═══

→ Merging PR #182...
[DRY-RUN] gh pr merge 182 --squash --delete-branch
...
```

---

## Support

**Issues?** Check:
1. `gh auth status` - Must be authenticated
2. `gh repo set-default Ic1558/02luka` - Correct repo
3. `git status` - Clean working directory
4. Script permissions: `chmod +x scripts/manage_prs.sh`

**Questions?** See full documentation in `g/reports/ci/meta_pr_body.md`
