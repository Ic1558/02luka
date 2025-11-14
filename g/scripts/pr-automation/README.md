# PR Automation System

Comprehensive automation tools for managing Pull Requests and GitHub workflows.

## Quick Start

```bash
# Navigate to scripts directory
cd scripts/pr-automation

# Make main helper available
chmod +x pr-helper.zsh

# Run commands
./pr-helper.zsh create              # Create PR from current branch
./pr-helper.zsh status 123          # Check PR #123 status
./pr-helper.zsh fix                 # Retry failed workflows
./pr-helper.zsh health              # Check repo health
```

## Features

### 1. **Create PR** (`create-pr.zsh`)
- Auto-generates PR title from branch name
- Creates PR body from commits
- Auto-adds labels based on branch prefix
- Pushes branch if not on remote

```bash
./pr-helper.zsh create
./pr-helper.zsh create feat/my-feature "My awesome feature"
```

### 2. **Check PR Status** (`check-pr-status.zsh`)
- Shows PR details
- Lists workflow runs
- Checks merge readiness
- Shows CI/CD status

```bash
./pr-helper.zsh status 123
./pr-helper.zsh list              # List all open PRs
```

### 3. **Fix Failed Workflows** (`fix-failed-workflows.zsh`)
- Detects recent failed workflows
- Auto-retry with confirmation
- Batch retry support

```bash
./pr-helper.zsh fix
AUTO_RETRY=yes ./pr-helper.zsh fix  # No confirmation
```

### 4. **Merge & Close** 
- Safe merge with checks
- Auto-delete branch after merge
- Squash commits

```bash
./pr-helper.zsh merge 123
./pr-helper.zsh close 123
```

### 5. **Repository Health**
- Overview of open issues
- Open PRs
- Recent failed workflows
- Notifications summary

```bash
./pr-helper.zsh health
./pr-helper.zsh notifications
./pr-helper.zsh workflows
```

## Environment Variables

- `AUTO_RETRY=yes` - Auto-retry failed workflows without prompting
- `OPEN_BROWSER=no` - Don't open PR in browser after creation
- `GH_TOKEN` - GitHub personal access token (if not using gh auth)

## Branch Naming Conventions

Auto-labeling based on branch prefix:

- `feat/` or `feature/` → `enhancement` label
- `fix/` or `bugfix/` or `hotfix/` → `bug` label  
- `docs/` or `doc/` → `documentation` label

Example: `feat/add-authentication` → Title: "Feat: Add Authentication" + enhancement label

## Workflow Improvements

### GitHub Pages Fix
The workflow has been updated to:
- Build a clean `dist/` directory
- Exclude dynamic files (`.pid`, logs, metrics)
- Prevent "File removed before we read it" errors

File: `.github/workflows/pages-fixed.yml`

### Auto-Tag Phase
Works correctly - only runs when PR title contains "Phase X.Y"
Not a failure, just conditional execution.

## Troubleshooting

### SSH Authentication Issues
```bash
# Check SSH key
ssh -T git@github.com

# Verify gh CLI
gh auth status
```

### Permission Errors
```bash
# Re-authenticate gh CLI
gh auth login

# Refresh GitHub token
gh auth refresh -h github.com -s repo,workflow
```

### Workflow Not Retriggering
```bash
# Manual rerun
gh run rerun [run-id]

# Or use the fix command
./pr-helper.zsh fix
```

## Integration with Other Tools

### CLS Bridge Integration
```bash
# Create PR and log to CLS
./pr-helper.zsh create && ~/tools/bridge_cls_clc.zsh \
  --title "PR Created" --priority P3 --tags "pr,automation"
```

### Daily Workflow
```bash
# Morning check
./pr-helper.zsh health
./pr-helper.zsh fix              # Fix any failures
./pr-helper.zsh notifications   # Check what needs attention
```

## Files

- `pr-helper.zsh` - Main command interface
- `create-pr.zsh` - PR creation automation
- `check-pr-status.zsh` - Status checking
- `fix-failed-workflows.zsh` - Workflow retry automation
- `README.md` - This file

## Requirements

- zsh shell
- gh CLI (authenticated)
- Git
- jq (for JSON parsing)

## Support

For issues or improvements, check:
- GitHub notifications: https://github.com/notifications
- Repository workflows: https://github.com/Ic1558/02luka/actions
- PR automation guide: This file

---

✅ System Status: Operational
🔑 SSH: Configured (ed25519)
🤖 Automation: Active
