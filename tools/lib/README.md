# CI Rebase Library

Shared libraries for the CI rebase automation system.

## Files

### `ci_rebase_smart.sh`

Smart features library providing intelligence for long-term CI rebase automation.

**Purpose**: Make rebase automation smarter and prevent conflicts without modifying core logic.

**Features**:
- Configuration loading from YAML
- Pre-flight conflict prediction
- PR dependency detection
- Smart ordering algorithms
- Hook execution system
- Metrics collection and tracking
- Enhanced state management
- Advanced filtering

**Usage**:

```bash
# Source the library
source tools/lib/ci_rebase_smart.sh

# Load configuration
load_config ".github/ci-rebase.config.yml"

# Predict conflicts
if predict_conflict "feature-branch" "origin/main"; then
  echo "Low conflict risk"
else
  echo "High conflict risk - skip"
fi

# Run hooks
run_hook "post_rebase" "$PR_NUM" "$BRANCH" "SUCCESS" "$DURATION"

# Track metrics
init_metrics
record_metric "$PR_NUM" "SUCCESS" "$DURATION"
finalize_metrics
```

**Functions**:

| Function | Purpose | Returns |
|----------|---------|---------|
| `load_config` | Load YAML config | 0=success, 1=not found |
| `get_config` | Get config value | Value or default |
| `predict_conflict` | Analyze conflict risk | 0=low, 1=high, 2=unknown |
| `analyze_conflict_risk` | Get risk level | LOW/HIGH/UNKNOWN |
| `detect_dependencies` | Find PR dependencies | JSON array |
| `order_by_dependencies` | Sort by deps | PR numbers |
| `score_pr` | Calculate priority | Numeric score |
| `smart_order_prs` | Order intelligently | JSON array |
| `run_hook` | Execute hook | 0=success |
| `init_metrics` | Start tracking | void |
| `record_metric` | Log operation | void |
| `finalize_metrics` | Complete session | void |
| `save_state_snapshot` | Backup state | void |
| `can_resume` | Check resumability | 0=yes, 1=no |
| `should_skip_pr` | Filter PR | 0=skip, 1=process |

**Dependencies**:
- `jq` - JSON processing
- `yq` - YAML processing (optional, falls back to defaults)
- `gh` - GitHub CLI
- `git` - Version control

**Configuration**:

Controlled by `.github/ci-rebase.config.yml`. See [Smart Features Guide](../../docs/ci-rebase-smart-features.md) for details.

**Extending**:

The library is designed to be extended:

```bash
# Add custom conflict detection
my_predict_conflict() {
  local branch="$1"
  local base="$2"

  # Your custom logic
  # ...

  return 0  # or 1
}

# Override default
predict_conflict() {
  my_predict_conflict "$@"
}
```

**Testing**:

```bash
# Test configuration loading
source tools/lib/ci_rebase_smart.sh
load_config ".github/ci-rebase.config.yml"
echo "Threshold: $(get_config 'conflict_threshold' '0.7')"

# Test conflict detection
predict_conflict "my-branch" "origin/main"
echo "Result: $?"

# Test metrics
init_metrics
record_metric "123" "SUCCESS" "30"
finalize_metrics
cat /tmp/ci-rebase-metrics.json
```

**Performance**:

- Configuration caching: Minimal overhead
- Conflict detection: 2-5 seconds per PR
- Dependency detection: O(n²) for n PRs
- Hook execution: Depends on hooks
- Metrics: Negligible overhead

**Error Handling**:

All functions handle errors gracefully:
- Missing config: Uses defaults
- Failed API calls: Returns error code
- Invalid input: Returns error code
- Hook failures: Logged but don't abort

**Future Enhancements**:

- Machine learning conflict prediction
- Caching of conflict analysis
- Parallel processing support
- External state storage
- More ordering algorithms

## Development

### Adding New Features

1. Create function in library
2. Export function at bottom
3. Document in this README
4. Add tests
5. Update examples

### Code Style

- Use bash best practices
- Add error handling
- Document parameters
- Export for use in main script

### Testing

```bash
# Run library tests
bash tests/lib/ci_rebase_smart_test.sh

# Integration test
./tools/global_ci_branches.zsh --report
```

## Support

For issues:
1. Check function documentation
2. Review configuration
3. Test independently
4. Create issue with `lib` label
