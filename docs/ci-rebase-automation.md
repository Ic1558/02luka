# CI Rebase Automation

Automated tool for discovering and rebasing pull requests that modify CI workflows.

## Overview

The CI Rebase Automation system provides a safe, automated way to rebase multiple PRs that touch CI workflows (`.github/workflows/ci.yml` and `_reusable/*.yml`). This is particularly useful when:

- A major CI workflow change is merged (e.g., PR #201)
- Multiple CI-related PRs need to be synchronized
- You want to ensure all CI PRs are up-to-date with the latest main branch

## Components

### 1. Global CI Branches Script (`tools/global_ci_branches.zsh`)

Core CLI tool that discovers and rebases CI-related PRs.

**Features:**
- ✅ Safe by default (dry-run mode)
- ✅ Fork detection and protection
- ✅ Branch ownership validation
- ✅ Rate limit awareness
- ✅ Conflict handling with automatic backups
- ✅ Resume-ability via state file
- ✅ Required checks filtering

**Usage:**

```bash
# List all PRs that modify CI workflows
./tools/global_ci_branches.zsh

# Rebase all CI PRs (with confirmation)
./tools/global_ci_branches.zsh --rebase

# Rebase only PRs with failing checks
./tools/global_ci_branches.zsh --rebase --only-failing

# Auto-approve (no confirmation)
./tools/global_ci_branches.zsh --rebase --force

# Rebase onto a different base branch
./tools/global_ci_branches.zsh --rebase --base origin/develop
```

**Full Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `--report` | List candidate PRs (read-only) | ✓ |
| `--rebase` | Perform rebase operations | |
| `--force` | Skip confirmation prompt | |
| `--base BRANCH` | Rebase onto BRANCH | `origin/main` |
| `--limit N` | Limit PR discovery | `100` |
| `--only-failing` | Only rebase PRs with failing checks | |
| `--allow-forks` | Include PRs from forks | |
| `--include PATTERN` | Include PRs matching PATTERN | |
| `--exclude PATTERN` | Exclude PRs matching PATTERN | |
| `--state-file PATH` | Path to state file | `/tmp/global-ci-rebase.json` |
| `--repo OWNER/NAME` | Target repository | auto-detect |

### 2. GitHub Actions Workflow (`.github/workflows/ci-rebase-automation.yml`)

Automated workflow that can be triggered in multiple ways:

#### A. Manual Trigger (Workflow Dispatch)

Navigate to Actions → CI Rebase Automation → Run workflow

**Inputs:**
- **Mode**: `report` or `rebase`
- **Only Failing**: Only process PRs with failing checks
- **Force**: Skip confirmation
- **Base Branch**: Branch to rebase onto

#### B. Bot Commands (PR Comments)

Post a comment on any PR:

```
/rebase-ci
```

**Options:**
```
/rebase-ci --only-failing
```

**Check status only:**
```
/check-ci-rebases
```

#### C. Scheduled (Automatic)

Runs daily at 2 AM UTC to check for CI PR conflicts. If found, creates an issue labeled `ci-rebase-needed`.

### 3. Bot Command Handler (`tools/ci_bot_commands.zsh`)

CLI wrapper for triggering bot commands and workflow dispatches.

**Usage:**

```bash
# Trigger rebase via bot comment on current PR
./tools/ci_bot_commands.zsh trigger-rebase

# Trigger on specific PR
./tools/ci_bot_commands.zsh trigger-rebase --pr 123

# Check current status
./tools/ci_bot_commands.zsh check-status

# Dispatch workflow manually
./tools/ci_bot_commands.zsh dispatch --mode rebase --force

# List recent workflow runs
./tools/ci_bot_commands.zsh list
```

## Safety Features

### 1. Fork Protection

By default, the tool **will not** rebase branches from forks to prevent:
- Pushing to repositories you don't own
- Permission errors
- Security issues

To explicitly allow forks (unsafe):
```bash
./tools/global_ci_branches.zsh --rebase --allow-forks
```

### 2. Protected Branch Guard

These branches are **never** rebased:
- `main`
- `master`
- `develop`
- `production`

### 3. Backup References

Before rebasing, the tool creates backup refs:
```
backup/pre-rebase-<branch>-<timestamp>
```

If a rebase fails, you can restore with:
```bash
git checkout -B <branch> backup/pre-rebase-<branch>-<timestamp>
```

### 4. Conflict Handling

When conflicts occur:
1. Rebase is automatically aborted
2. Branch is restored to original state
3. Backup reference is preserved
4. Manual resolution instructions are provided

### 5. Rate Limit Awareness

The tool checks GitHub API rate limits before starting:
- Warns if remaining calls < 50
- Errors if remaining calls < 10

## Workflow Integration

### Typical CI Update Workflow

When a major CI change is merged (e.g., PR #201):

1. **Check impacted PRs:**
   ```bash
   ./tools/global_ci_branches.zsh
   ```

2. **Review the list** and decide which PRs to update

3. **Rebase selected PRs:**
   ```bash
   # All CI PRs
   ./tools/global_ci_branches.zsh --rebase

   # Or only failing ones
   ./tools/global_ci_branches.zsh --rebase --only-failing
   ```

4. **Monitor results:**
   - ✅ OK: PR rebased and pushed successfully
   - ⚠️  CONFLICT: Manual resolution required
   - ❌ FAIL: Permission or technical error

5. **Handle conflicts manually:**
   ```bash
   git checkout <branch>
   git rebase origin/main
   # Resolve conflicts
   git rebase --continue
   git push --force-with-lease origin <branch>
   ```

### Bot-Triggered Workflow

For automated CI maintenance:

1. **Post bot command** on any PR:
   ```
   /rebase-ci
   ```

2. **Workflow automatically:**
   - Discovers all CI-related PRs
   - Rebases them onto main
   - Posts results as PR comment

3. **Review the comment** for:
   - Success count
   - Conflict count
   - Failed rebases

### Scheduled Monitoring

The system automatically:
- Runs daily at 2 AM UTC
- Checks for CI PRs needing rebases
- Creates an issue if action is needed
- Includes link to manual trigger

## State File

The tool maintains a state file at `/tmp/global-ci-rebase.json`:

```json
{
  "started": "2025-01-15T10:30:00Z",
  "base": "origin/main",
  "results": {
    "123": {
      "status": "OK",
      "branch": "feature/ci-improvements",
      "timestamp": "2025-01-15T10:32:15Z"
    }
  }
}
```

Use this for:
- Resuming interrupted operations
- Audit trail
- Debugging

## Troubleshooting

### "Failed to fetch branch"

**Cause:** Branch doesn't exist on remote or network issue

**Solution:**
```bash
git fetch origin
git branch -r | grep <branch-name>
```

### "Protected branch" error on push

**Cause:** Branch has protection rules

**Solution:**
1. Check branch protection settings
2. Ensure you have required permissions
3. May need admin override

### "Rate limit exceeded"

**Cause:** Too many API calls

**Solution:**
```bash
# Check rate limit status
gh api rate_limit

# Wait for reset or use --limit to reduce calls
./tools/global_ci_branches.zsh --rebase --limit 20
```

### Rebase conflicts

**Cause:** Code changes conflict with base branch

**Solution:**
```bash
# Manual resolution
git checkout <branch>
git rebase origin/main

# Follow git's conflict resolution prompts
# Edit files, then:
git add .
git rebase --continue

# Or abort and try different approach:
git rebase --abort
```

## Best Practices

### 1. Always Check First

Run in report mode before rebasing:
```bash
./tools/global_ci_branches.zsh
```

### 2. Start Small

Test with one PR first:
```bash
./tools/global_ci_branches.zsh --rebase --include "specific-branch"
```

### 3. Use `--only-failing`

Focus on PRs that need attention:
```bash
./tools/global_ci_branches.zsh --rebase --only-failing
```

### 4. Monitor Rate Limits

For large repos, use `--limit`:
```bash
./tools/global_ci_branches.zsh --rebase --limit 25
```

### 5. Keep Backups

Backup refs are automatic, but you can also:
```bash
# Manual backup before batch operations
git branch backup-main-$(date +%Y%m%d) main
```

### 6. Communicate

When rebasing many PRs, consider:
- Posting a comment explaining why
- Using bot commands for transparency
- Notifying affected contributors

## Security Considerations

### Permissions Required

The tool requires:
- **Read** access to PRs and repository
- **Write** access to push rebased branches
- **GitHub CLI** authentication

### Fork Safety

**Never** rebase forks unless:
- You own both repositories
- You have explicit write access
- You understand the implications

### Token Scopes

Required GitHub token scopes:
- `repo` (full repository access)
- `workflow` (to trigger actions)

## Examples

### Example 1: Post-Merge CI Sync

After merging a major CI refactor:

```bash
# Check what needs updating
./tools/global_ci_branches.zsh

# Output:
# Found 8 candidate PR(s) for rebase:
# PR #203: feat/add-caching
# PR #205: fix/timeout-issues
# ...

# Rebase them all
./tools/global_ci_branches.zsh --rebase --force

# Output:
# ✅ OK      PR #203 (feat/add-caching)
# ✅ OK      PR #205 (fix/timeout-issues)
# ...
# Results: 8 succeeded, 0 conflicts, 0 failed
```

### Example 2: Fixing Failing CI Checks

Multiple PRs have failing CI after a base branch update:

```bash
# Rebase only failing PRs
./tools/global_ci_branches.zsh --rebase --only-failing

# Or use bot command on a PR:
# Comment: /rebase-ci --only-failing
```

### Example 3: Scheduled Maintenance

Workflow runs automatically and detects issues:

1. Scheduled run finds 3 PRs need rebasing
2. Workflow creates issue: "🔄 CI Rebases Needed"
3. Maintainer reviews issue
4. Triggers manual rebase via Actions UI

### Example 4: Multi-Branch Strategy

Rebase develop-targeting PRs:

```bash
./tools/global_ci_branches.zsh --rebase --base origin/develop
```

## Migration from Old Script

If upgrading from `ci_rebase_after_201.zsh`:

**Old:**
```bash
./tools/ci_rebase_after_201.zsh
```

**New (equivalent):**
```bash
./tools/global_ci_branches.zsh --rebase
```

**Improvements:**
- Fork safety checks
- Rate limit awareness
- Better error handling
- Backup creation
- State tracking
- More filtering options

## Contributing

To enhance this tool:

1. **Test thoroughly** - use `--report` first
2. **Add safety checks** - fail safe, not sorry
3. **Document changes** - update this doc
4. **Consider edge cases** - forks, permissions, conflicts
5. **Maintain backward compatibility** - don't break existing usage

## Support

For issues or questions:

1. Check this documentation
2. Review workflow run logs
3. Check state file: `/tmp/global-ci-rebase.json`
4. Create issue with label `ci-automation`

## References

- Original review: (included in commit message)
- GitHub CLI docs: https://cli.github.com/manual/
- Git rebase guide: https://git-scm.com/docs/git-rebase
- GitHub Actions: https://docs.github.com/actions
