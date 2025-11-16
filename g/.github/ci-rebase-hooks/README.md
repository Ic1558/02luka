# CI Rebase Hooks

This directory contains hook scripts that extend the CI rebase automation system.

## Available Hooks

### Lifecycle Hooks

| Hook | When | Arguments | Use Case |
|------|------|-----------|----------|
| `pre_discovery` | Before PR discovery starts | None | Setup, environment checks |
| `post_discovery` | After PRs discovered | `<pr_count>` | Filter, validation |
| `pre_rebase` | Before each PR rebase | `<pr_num> <branch> <base>` | Custom checks, notifications |
| `post_rebase` | After each PR rebase | `<pr_num> <branch> <status> <duration>` | Logging, notifications |
| `pre_push` | Before pushing rebased branch | `<pr_num> <branch>` | Final validation |
| `post_push` | After push (success or fail) | `<pr_num> <branch> <status>` | Cleanup, notifications |
| `on_conflict` | When conflict detected | `<pr_num> <branch> <base>` | Detailed analysis, alerts |
| `on_complete` | After all operations | `<success> <conflicts> <failures> <duration>` | Summary, reporting |

## Creating Hooks

### 1. Copy Example

```bash
cd .github/ci-rebase-hooks
cp post_rebase.sh.example post_rebase.sh
chmod +x post_rebase.sh
```

### 2. Customize

Edit the hook script to your needs:
```bash
vim post_rebase.sh
```

### 3. Register in Config

Add to `.github/ci-rebase.config.yml`:
```yaml
hooks:
  post_rebase:
    - post_rebase.sh
```

## Hook Examples

### Example: Slack Notification

```bash
#!/usr/bin/env bash
# slack_notify.sh

PR_NUM="$1"
STATUS="$2"

if [[ "$STATUS" == "SUCCESS" ]]; then
  curl -X POST "$SLACK_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -d '{"text":"✅ PR #'$PR_NUM' rebased successfully"}'
fi
```

### Example: GitHub Comment

```bash
#!/usr/bin/env bash
# comment_on_conflict.sh

PR_NUM="$1"

gh pr comment "$PR_NUM" --body "⚠️ Automatic rebase failed. Please rebase manually:
\`\`\`
git checkout $2
git rebase $3
# Resolve conflicts
git push --force-with-lease
\`\`\`"
```

### Example: Update External System

```bash
#!/usr/bin/env bash
# update_jira.sh

PR_NUM="$1"
STATUS="$3"

# Extract JIRA ticket from PR title/description
TICKET=$(gh pr view "$PR_NUM" --json title --jq '.title' | grep -oE '[A-Z]+-[0-9]+')

if [[ -n "$TICKET" && "$STATUS" == "SUCCESS" ]]; then
  # Update JIRA via API
  curl -X POST "https://your-jira.com/rest/api/2/issue/$TICKET/comment" \
    -u "$JIRA_USER:$JIRA_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"body":"PR rebased successfully"}'
fi
```

## Best Practices

### 1. Keep Hooks Fast

Hooks should execute quickly to avoid slowing down the main process:
- Avoid heavy computation
- Use async operations for external calls
- Consider background jobs for slow tasks

### 2. Handle Errors Gracefully

Hooks should not break the main process:
```bash
set -euo pipefail  # Use this
# But also handle errors:
some_command || {
  echo "Warning: command failed" >&2
  # Don't exit - let main process continue
}
```

### 3. Use Environment Variables

Make hooks configurable:
```bash
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
if [[ -n "$SLACK_WEBHOOK" ]]; then
  # Send notification
fi
```

### 4. Log for Debugging

Always log what hooks do:
```bash
LOG="/tmp/hook-${HOOK_NAME}.log"
echo "[$(date)] Processing PR #$PR_NUM" >> "$LOG"
```

### 5. Version Your Hooks

Add version comments and compatibility notes:
```bash
#!/usr/bin/env bash
# Version: 1.0.0
# Compatible with: ci-rebase v1.0+
# Last updated: 2025-01-15
```

## Hook Return Codes

Hooks can return these codes:
- `0`: Success, continue normally
- `1`: Warning (logged but ignored)
- `2+`: Error (logged but ignored)

**Note**: Hooks cannot currently abort the main process. This is by design for safety.

## Testing Hooks

Test hooks independently:

```bash
# Test post_rebase hook
./post_rebase.sh 123 "feature/test" "SUCCESS" 30

# Test on_conflict hook
./on_conflict.sh 123 "feature/test" "origin/main"
```

## Security Considerations

### Sensitive Data

Never commit hooks with secrets:
- Use environment variables
- Use secret management systems
- Document required env vars in comments

### Permissions

Be careful with hook permissions:
- Only make necessary hooks executable
- Review hooks before enabling
- Use `.example` suffix for templates

### External Commands

Validate all external inputs:
```bash
# Good
PR_NUM=$(echo "$1" | grep -E '^[0-9]+$')
[[ -n "$PR_NUM" ]] || exit 1

# Bad
PR_NUM="$1"  # Could be malicious
```

## Troubleshooting

### Hook Not Running

1. Check it's executable: `ls -l *.sh`
2. Check config: `yq eval '.hooks' .github/ci-rebase.config.yml`
3. Check logs: `grep "Running hook" /tmp/ci-rebase-*.log`

### Hook Failing

1. Test independently: `./your_hook.sh <args>`
2. Check exit code: `echo $?`
3. Add debug output: `set -x` at top of script

### Performance Issues

1. Profile hook: `time ./your_hook.sh <args>`
2. Check for blocking operations
3. Consider async execution

## Advanced Patterns

### Conditional Execution

```bash
# Only run for specific branches
if [[ "$BRANCH" =~ ^(main|develop)$ ]]; then
  # Do something
fi
```

### Parallel Hooks

```bash
# Run slow operations in background
long_running_task &
PID=$!

# Do quick work
quick_task

# Wait if needed
wait $PID
```

### Hook Chaining

```bash
# Call another hook
if [[ -x "./other_hook.sh" ]]; then
  ./other_hook.sh "$@"
fi
```

## Contributing

When creating reusable hooks:
1. Add `.example` suffix
2. Document arguments and behavior
3. Include usage examples
4. Test on multiple PRs
5. Submit PR to share with team

## Support

For issues with hooks:
1. Test hook independently
2. Check hook logs
3. Review configuration
4. Create issue with `hooks` label
