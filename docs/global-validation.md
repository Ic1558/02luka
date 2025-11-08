# Global Validation System

Smart, extensible validation for the 02LUKA system.

## Overview

The Global Validation System provides intelligent, configuration-driven validation with:

- **Configuration-driven**: Customize behavior without code changes
- **Parallel execution**: Fast validation with concurrent validators
- **Smart caching**: Skip redundant checks
- **Extensible hooks**: Add custom logic without modifying core
- **Comprehensive metrics**: Track performance and success patterns
- **Auto-fix capabilities**: Automatically fix common issues
- **CI-optimized**: Special settings for continuous integration

## Quick Start

### Basic Usage

```bash
# Run all validators
./tools/global_validate.sh

# Run only critical validators
./tools/global_validate.sh --category critical

# Run specific validator
./tools/global_validate.sh --validator git_repository

# CI mode
./tools/global_validate.sh --ci --fail-fast
```

### Integration with Existing Script

Update `tools/ci/validate.sh`:

```bash
#!/usr/bin/env bash
# Use global validation system
exec ./tools/global_validate.sh --ci "$@"
```

## Components

### 1. Main Script (`tools/global_validate.sh`)

The entry point for all validation.

**Features**:
- Category-based execution (critical/important/optional)
- Parallel validation for speed
- Progress reporting
- Result caching
- Hook execution
- Metrics collection

### 2. Smart Library (`tools/lib/validation_smart.sh`)

Reusable validation logic.

**Includes**:
- Built-in validators
- Cache management
- Metrics tracking
- Hook execution
- Configuration loading

### 3. Configuration (`.github/validation.config.yml`)

All behavior controlled via YAML.

**Configures**:
- Which validators run
- Validation rules
- Caching behavior
- Hook registration
- CI overrides
- Performance tuning

### 4. Hook System (`.github/validation-hooks/`)

Extend functionality without code changes.

**Lifecycle**:
```
pre_validate
    ↓
For each validator:
    on_validator_start
    → run validator
    on_validator_complete
    ↓
post_validate
on_success / on_failure
```

## Built-in Validators

### Critical Validators

These always run and failures block:

#### `directory_structure`
Verifies required directories exist.

```yaml
directory_structure:
  required_dirs:
    - path: .github/workflows
      description: "GitHub Actions workflows"
    - path: tools
      description: "Tooling scripts"
```

#### `git_repository`
Validates git repository health.

```yaml
git_repository:
  verify_git_dir: true
  require_remote: true
  remote_name: origin
```

#### `required_files`
Checks for required files with validation.

```yaml
required_files:
  critical:
    - path: .github/workflows/ci.yml
      description: "Main CI workflow"
      pattern: "validate"  # Must contain
      min_size: 100        # Minimum bytes
      validate_json: false
      executable: false
```

### Important Validators

Run by default, failures warn:

#### `workflow_files`
Validates GitHub Actions workflows.

- YAML syntax checking
- Action version validation
- Deprecated action warnings
- Naming conventions

#### `script_permissions`
Ensures scripts are executable.

```yaml
script_permissions:
  executable_patterns:
    - "tools/*.zsh"
    - "tools/**/*.sh"
    - "scripts/*.sh"
  exclude_patterns:
    - "**/*.example"
  auto_fix: false
```

#### `cls_integration`
Verifies CLS integration files.

#### `dependencies`
Checks required system tools.

```yaml
dependencies:
  system_tools:
    required:
      - git
      - jq
      - bash
    recommended:
      - yq
      - gh
      - redis-cli
```

### Optional Validators

Can be enabled/disabled:

#### `performance`
Checks repository health metrics.

- Repository size
- File counts
- Large file detection
- Script complexity

#### `security_scan`
Scans for security issues.

- Secret pattern detection
- Dangerous file permissions
- Sensitive data exposure

## Configuration Guide

### Basic Structure

```yaml
# Core settings
enabled: true
fail_fast: false
timeout: 300
parallel_workers: 4

# Validators to run
validators:
  critical:
    - directory_structure
    - git_repository
  important:
    - workflow_files
    - dependencies
  optional:
    - performance
    - security_scan
```

### Customizing Validators

Each validator has its own configuration:

```yaml
workflow_files:
  validate_yaml: true
  required_action_versions:
    "actions/checkout": "v4"
    "actions/setup-node": "v4"
  deprecated_actions:
    - "actions/checkout@v2"
```

### Caching

Speed up validation with result caching:

```yaml
caching:
  enabled: true
  cache_dir: /tmp/validation-cache
  ttl: 3600  # 1 hour
  cache_validators:
    - dependencies
    - security_scan
```

### Hooks

Register custom hooks:

```yaml
hooks:
  enabled: true
  hooks_dir: .github/validation-hooks
  on_failure:
    - notify_slack.sh
  on_success:
    - cleanup_temp.sh
```

### CI Mode

CI-specific overrides:

```yaml
ci_mode:
  auto_detect: true
  overrides:
    fail_fast: true
    parallel_workers: 2
    timeout: 600
  respect_env_vars:
    SKIP_BOSS_API: skip_server_validators
    CI_QUIET: quiet_mode
```

## Advanced Features

### Parallel Execution

Process validators concurrently:

```yaml
parallel_workers: 4  # Run 4 validators simultaneously
```

### Smart Caching

Cache expensive validator results:

```bash
# First run - checks everything
./tools/global_validate.sh  # 30s

# Second run - uses cache
./tools/global_validate.sh  # 5s (cached results)
```

### Auto-Fix

Automatically fix common issues:

```bash
# Fix script permissions
./tools/global_validate.sh --auto-fix

# With confirmation
./tools/global_validate.sh --auto-fix  # Prompts before fixing
```

```yaml
auto_fix:
  enabled: true
  fixable_issues:
    - script_permissions
    - trailing_whitespace
  require_confirmation: true
```

### Custom Validators

Add your own validators by extending the library:

```bash
# In tools/lib/validation_smart.sh
validate_custom_check() {
  # Your validation logic
  if [[ some_check ]]; then
    validator_result "custom_check" "PASS" "Check passed"
    return 0
  else
    validator_result "custom_check" "FAIL" "Check failed"
    return 1
  fi
}
```

Register in config:

```yaml
validators:
  important:
    - custom_check
```

## Metrics and Reporting

### Metrics Collection

Automatic tracking of:
- Validator duration
- Pass/fail rates
- Cache hit rates
- Performance trends

```yaml
metrics:
  enabled: true
  metrics_file: /tmp/validation-metrics.json
  track:
    - validator_duration
    - pass_fail_rate
    - cache_hit_rate
```

### View Metrics

```bash
# View metrics file
cat /tmp/validation-metrics.json | jq .

# Success rate
jq '.summary.passed / .summary.total * 100' /tmp/validation-metrics.json

# Slow validators
jq '.validators[] | select(.duration_ms > 1000)' /tmp/validation-metrics.json
```

### Report Formats

```bash
# Detailed (default)
./tools/global_validate.sh --report detailed

# Compact
./tools/global_validate.sh --report compact

# JSON (for processing)
./tools/global_validate.sh --report json
```

## Hook System

### Creating Hooks

1. **Copy example**:
   ```bash
   cd .github/validation-hooks
   cp on_failure.sh.example on_failure.sh
   chmod +x on_failure.sh
   ```

2. **Customize**:
   ```bash
   #!/usr/bin/env bash
   FAILED="$1"

   # Your custom logic
   if (( FAILED > 0 )); then
     # Send alert
     notify_team "Validation failed"
   fi
   ```

3. **Register**:
   ```yaml
   hooks:
     on_failure:
       - on_failure.sh
   ```

### Hook Use Cases

| Use Case | Hook | Implementation |
|----------|------|----------------|
| Slack notifications | `on_failure` | Post to webhook |
| Create GitHub issue | `on_failure` | Use `gh issue create` |
| Track slow validators | `on_validator_complete` | Log duration > threshold |
| Cleanup temp files | `post_validate` | Remove temp directories |
| Pre-flight checks | `pre_validate` | Verify environment |

## CI Integration

### GitHub Actions

```yaml
# .github/workflows/ci.yml
- name: Run validation
  run: ./tools/global_validate.sh --ci --fail-fast
```

### Environment Variables

Respect CI environment:

```yaml
ci_mode:
  respect_env_vars:
    CI_QUIET: quiet_mode
    SKIP_BOSS_API: skip_server_validators
```

### Migration from Old Script

**Old** (`tools/ci/validate.sh`):
```bash
#!/usr/bin/env bash
# Old implementation
bash scripts/smoke.sh
```

**New** (`tools/ci/validate.sh`):
```bash
#!/usr/bin/env bash
# Use global validation system
exec ./tools/global_validate.sh --ci "$@"
```

## Troubleshooting

### Validator Failing

1. Run with verbose output:
   ```bash
   ./tools/global_validate.sh --verbose --validator failing_validator
   ```

2. Check configuration:
   ```bash
   yq eval '.validators' .github/validation.config.yml
   ```

3. Test validator independently:
   ```bash
   source tools/lib/validation_smart.sh
   load_validation_config
   validate_failing_validator
   ```

### Slow Validation

1. Check metrics:
   ```bash
   jq '.validators | sort_by(.duration_ms) | reverse' /tmp/validation-metrics.json
   ```

2. Enable caching:
   ```yaml
   caching:
     enabled: true
   ```

3. Reduce parallel workers:
   ```yaml
   parallel_workers: 2  # Lower if CPU-bound
   ```

### Cache Issues

1. Clear cache:
   ```bash
   rm -rf /tmp/validation-cache
   ```

2. Disable caching:
   ```bash
   ./tools/global_validate.sh --no-cache
   ```

3. Adjust TTL:
   ```yaml
   caching:
     ttl: 600  # 10 minutes instead of 1 hour
   ```

## Best Practices

### 1. Start Conservative

Begin with critical validators only:

```yaml
validators:
  critical:
    - directory_structure
    - git_repository
    - required_files
  # Add more gradually
```

### 2. Use Caching Wisely

Cache expensive checks:

```yaml
caching:
  cache_validators:
    - dependencies      # System tools don't change often
    - security_scan     # Slow, can be cached
```

### 3. Monitor Performance

Track slow validators:

```bash
# Weekly review
jq '.validators | group_by(.name) | map({validator: .[0].name, avg_ms: (map(.duration_ms) | add / length)})' \
  /tmp/validation-metrics.json
```

### 4. Customize for Your Team

Add team-specific validators:

```yaml
required_files:
  important:
    - path: TEAM_GUIDELINES.md
      description: "Team guidelines"
```

### 5. Use Hooks for Integration

Integrate with your tools:

```bash
# Jira integration
gh pr view --json title | grep -oE 'PROJ-[0-9]+' | \
  xargs -I {} jira comment {} "Validation passed"
```

## Examples

### Example 1: Fast Local Validation

```bash
# Quick check before commit
./tools/global_validate.sh --category critical --fail-fast
```

### Example 2: Full CI Validation

```bash
# Comprehensive check in CI
./tools/global_validate.sh \
  --ci \
  --fail-fast \
  --report json > validation-results.json
```

### Example 3: Custom Validation Run

```bash
# Only specific validators
./tools/global_validate.sh \
  --validator git_repository \
  --validator dependencies \
  --verbose
```

### Example 4: Auto-Fix Mode

```bash
# Fix common issues automatically
./tools/global_validate.sh \
  --auto-fix \
  --category important
```

## Migration Guide

### Phase 1: Setup (Week 1)

1. Review configuration
2. Test with existing script
3. Enable critical validators only

### Phase 2: Expand (Week 2-3)

1. Add important validators
2. Enable caching
3. Set up hooks

### Phase 3: Optimize (Week 4+)

1. Monitor metrics
2. Tune performance
3. Add custom validators
4. Full CI integration

## Support

For issues:
1. Check configuration
2. Review validator logs
3. Test independently
4. Create issue with `validation` label

## References

- Configuration schema: `.github/validation.config.yml`
- Library docs: `tools/lib/README.md`
- Hook docs: `.github/validation-hooks/README.md`
- CI integration: `.github/workflows/_reusable/validate-core.yml`
