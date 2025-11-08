# Validation Hooks

Extensible hooks for the global validation system.

## Available Hooks

| Hook | When | Arguments | Use Case |
|------|------|-----------|----------|
| `pre_validate` | Before validation starts | None | Setup, environment prep |
| `post_validate` | After all validation | `<total> <passed> <failed>` | Summary, cleanup |
| `on_validator_start` | Before each validator | `<validator_name>` | Per-validator setup |
| `on_validator_complete` | After each validator | `<name> <status> <duration>` | Logging, metrics |
| `on_failure` | When any validator fails | `<failed_count>` | Alerts, reporting |
| `on_success` | When all pass | `<passed_count>` | Success notifications |

## Usage

### 1. Copy Example

```bash
cd .github/validation-hooks
cp on_failure.sh.example on_failure.sh
chmod +x on_failure.sh
```

### 2. Customize

Edit the hook for your needs:
```bash
vim on_failure.sh
```

### 3. Register

Add to `.github/validation.config.yml`:
```yaml
hooks:
  enabled: true
  on_failure:
    - on_failure.sh
```

## Examples

### Example: Slack Notification on Failure

```bash
#!/usr/bin/env bash
FAILED="$1"

curl -X POST "$SLACK_WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d '{"text":"❌ Validation failed: '$FAILED' validators failed"}'
```

### Example: Track Slow Validators

```bash
#!/usr/bin/env bash
VALIDATOR="$1"
DURATION="$3"

if (( DURATION > 3000 )); then
  echo "⚠️  $VALIDATOR is slow: ${DURATION}ms" | \
    tee -a /tmp/slow-validators.log
fi
```

### Example: Auto-Create GitHub Issue

```bash
#!/usr/bin/env bash
FAILED="$1"

if (( FAILED > 0 )); then
  gh issue create \
    --title "🚨 Validation Failures Detected" \
    --body "Automated validation detected $FAILED failing validators." \
    --label "validation,automated"
fi
```

## Best Practices

1. **Keep hooks fast** - Don't slow down validation
2. **Handle errors** - Use `|| true` for non-critical operations
3. **Log actions** - Always log what hooks do
4. **Use environment variables** - Make hooks configurable
5. **Test independently** - Run hooks standalone before integrating

## Testing

```bash
# Test on_failure hook
./on_failure.sh 3

# Test on_validator_complete hook
./on_validator_complete.sh "git_repository" "FAIL" 150

# Test post_validate hook
./post_validate.sh 10 8 2
```

## Integration with CI

Hooks work seamlessly in CI environments:

```yaml
# .github/workflows/ci.yml
- name: Run validation
  run: ./tools/global_validate.sh --ci
  # Hooks run automatically
```

## Security

- Never commit hooks with secrets
- Use environment variables for sensitive data
- Review hooks before making executable
- Use `.example` suffix for templates

## Contributing

Share useful hooks with the team:
1. Create hook in `.example` form
2. Document purpose and usage
3. Add to this README
4. Submit PR

## Support

For hook issues:
1. Test hook independently
2. Check hook logs
3. Verify configuration
4. Create issue with `hooks` label
