# MLS Git Hooks - Installation & Usage Guide

## Overview

The M LS Trigger Layer v1.0 Git Hooks automatically log git operations to the MLS ledger without any manual intervention.

## Installed Hooks

| Hook | Purpose | MLS Event Type |
|------|---------|----------------|
| `post-commit` | Logs every commit | `improvement` |
| `post-checkout` | Logs branch switches | `improvement` |
| `post-merge` | Logs merge operations | `improvement` |

## Installation

**Status**: ✅ Hooks are pre-installed in `.git/hooks/`

If you need to reinstall:
```bash
cd /Users/icmini/LocalProjects/02luka_local_g
chmod +x .git/hooks/post-commit
chmod +x .git/hooks/post-checkout
chmod +x .git/hooks/post-merge
```

## Verification

Check that hooks are executable:
```bash
ls -la .git/hooks/ | grep -E "post-(commit|checkout|merge)"
```

Expected output:
```
-rwxr-xr-x  1 user  staff  1234 Dec  3 02:44 post-commit
-rwxr-xr-x  1 user  staff  1567 Dec  3 02:44 post-checkout
-rwxr-xr-x  1 user  staff  1392 Dec  3 02:44 post-merge
```

## Usage

**No action required.** Hooks trigger automatically on git operations.

### Testing

**Test post-commit**:
```bash
git add <file>
git commit -m "test: verify MLS logging"
# Check MLS ledger:
tail -1 mls/ledger/$(date +%Y-%m-%d).jsonl | jq .
```

**Test post-checkout**:
```bash
git checkout -b test-branch
# Check MLS ledger for branch switch event
```

**Test post-merge**:
```bash
git merge <branch>
# Check MLS ledger for merge event
```

## Event Schema

### Post-Commit Event
```json
{
  "type": "improvement",
  "title": "Commit: <commit-message>",
  "summary": "Branch: <branch>, Files: <count>, Author: <name>",
  "source": {
    "producer": "git",
    "context": "local",
    "sha": "<commit-hash>"
  },
  "tags": ["git", "commit", "local"],
  "confidence": 0.8
}
```

### Post-Checkout Event
```json
{
  "type": "improvement",
  "title": "Branch switch: <new-branch>",
  "summary": "Switched from <old-branch> to <new-branch>",
  "source": {
    "producer": "git",
    "context": "local",
    "sha": "<new-head>"
  },
  "tags": ["git", "checkout", "branch-switch", "local"],
  "confidence": 0.7
}
```

### Post-Merge Event
```json
{
  "type": "improvement",
  "title": "Merge: <merge-message>",
  "summary": "Branch: <branch>, Files changed: <count>",
  "source": {
    "producer": "git",
    "context": "local",
    "sha": "<merge-sha>"
  },
  "tags": ["git", "merge", "local"],
  "confidence": 0.8
}
```

## Safety Features

### Silent Failure
- Hooks NEVER block git operations
- If MLS logging fails, git proceeds normally
- Errors are logged to `g/logs/mls_git_hook_errors.log`

### Async Logging
- MLS logging happens in background (fire-and-forget)
- Git commands return immediately
- No performance impact

### Error Logging
Check for hook errors:
```bash
cat g/logs/mls_git_hook_errors.log
```

## Troubleshooting

### "Hook didn't trigger"
1. Verify hook is executable: `ls -la .git/hooks/post-commit`
2. Check `tools/mls_add.zsh` exists and is executable
3. Check error log: `cat g/logs/mls_git_hook_errors.log`

### "No MLS event in ledger"
1. Check ledger file exists: `ls mls/ledger/$(date +%Y-%m-%d).jsonl`
2. Wait 1-2 seconds (async logging delay)
3. Check last entry: `tail -1 mls/ledger/$(date +%Y-%m-%d).jsonl | jq .`

### "Permission denied"
```bash
chmod +x .git/hooks/post-commit
chmod +x .git/hooks/post-checkout
chmod +x .git/hooks/post-merge
chmod +x tools/mls_add.zsh
```

## Uninstallation

To disable hooks (not recommended):
```bash
mv .git/hooks/post-commit .git/hooks/post-commit.disabled
mv .git/hooks/post-checkout .git/hooks/post-checkout.disabled
mv .git/hooks/post-merge .git/hooks/post-merge.disabled
```

To re-enable:
```bash
mv .git/hooks/post-commit.disabled .git/hooks/post-commit
mv .git/hooks/post-checkout.disabled .git/hooks/post-checkout
mv .git/hooks/post-merge.disabled .git/hooks/post-merge
```

## Related Documentation

- **Spec**: `g/specs/mls_trigger_layer_v1_SPEC.md`
- **Plan**: `g/reports/feature-dev/mls_trigger_layer_v1_PLAN.md`
- **MLS README**: `mls/README.md`
