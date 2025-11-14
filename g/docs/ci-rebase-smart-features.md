## Smart Features for Long-Term Use

This guide explains the intelligent features that make the CI rebase automation smarter and prevent conflicts.

## Overview

The enhanced system adds:
- 🧠 **Pre-flight conflict detection** - Predict conflicts before attempting rebase
- 🔗 **Dependency detection** - Understand PR relationships
- 📊 **Smart ordering** - Process PRs in optimal order
- 🔌 **Hook system** - Extend functionality without modifying core
- 📈 **Metrics tracking** - Learn from patterns over time
- ⚙️ **Configuration-driven** - Customize behavior without code changes

## Configuration System

### Location

`.github/ci-rebase.config.yml`

### Key Benefits

1. **No code changes needed** - Modify behavior via config
2. **Version controlled** - Configuration changes are tracked
3. **Team shared** - Everyone uses same settings
4. **Documented** - Built-in comments explain options

### Quick Customization

```yaml
# Enable smart features
enable_conflict_detection: true
enable_dependency_detection: true
enable_smart_ordering: true

# Customize thresholds
conflict_threshold: 0.7  # 70% confidence to skip
max_prs_per_run: 50      # Process max 50 PRs

# Add skip labels
default_filters:
  skip_labels:
    - do-not-rebase
    - wip
    - hold
```

## Pre-flight Conflict Detection

### How It Works

Before attempting a rebase, the system analyzes:

1. **Merge base distance** - How far behind is the branch?
2. **File overlap** - Do PR and base modify same files?
3. **Test merge** - Can git merge-tree predict conflicts?

Each signal contributes to a confidence score.

### Configuration

```yaml
# Enable detection
enable_conflict_detection: true

# Skip PRs likely to conflict
skip_conflicting_prs: true

# Confidence threshold (0.0-1.0)
# Higher = more conservative
conflict_threshold: 0.7
```

### Usage

Conflict detection runs automatically when enabled. Output:

```
Analyzing PR #123...
  Conflict risk: LOW (confidence: 15%)
  ✅ Safe to rebase

Analyzing PR #456...
  Conflict risk: HIGH (confidence: 85%)
  ⚠️  Skipping - likely to conflict
```

### Benefits

- ❌ **Avoid wasted time** - Skip PRs that will fail
- 📝 **Better planning** - Identify manual work needed
- 🎯 **Higher success rate** - Only attempt safe rebases

## Dependency Detection

### How It Works

Detects relationships between PRs by analyzing:

1. **Base branch** - PRs targeting same base
2. **File overlap** - PRs modifying same files
3. **PR references** - Mentions like "depends on #123"
4. **Labels** - Labels like `depends-on-#123`

### Configuration

```yaml
enable_dependency_detection: true

dependency_methods:
  - base_branch
  - file_overlap
  - commit_references
  - label_based

# Rebase dependencies first
respect_dependencies: true
```

### Example

```
Detected dependencies:
  PR #125 depends on PR #124
  PR #126 depends on PR #124

Rebase order:
  1. PR #124 (no dependencies)
  2. PR #125 (after #124)
  3. PR #126 (after #124)
```

### Benefits

- 🔗 **Respect relationships** - Avoid breaking dependent PRs
- ⚡ **Prevent cascading failures** - Fix issues in order
- 🎯 **Smarter scheduling** - Process prerequisites first

## Smart Ordering

### How It Works

PRs are scored based on multiple factors:

| Factor | Weight | Logic |
|--------|--------|-------|
| Age | -1 per day | Older PRs first |
| Size | -50 (small) to +20 (large) | Smaller PRs first |
| Conflict risk | -100 (low) to +100 (high) | Low-risk first |
| Dependencies | Varies | Dependencies processed first |

Lower score = higher priority.

### Configuration

```yaml
enable_smart_ordering: true

ordering_criteria:
  - dependencies  # Always first
  - age          # Then older
  - conflicts    # Then safer
  - size         # Then smaller
  - ci_status    # Then passing
```

### Example

```
Smart ordering analysis:
  PR #201 score: -180 (old, small, low-risk) → Priority 1
  PR #202 score: -50  (medium, no deps)       → Priority 2
  PR #203 score: +120 (new, large, high-risk) → Priority 3

Processing order: #201 → #202 → #203
```

### Benefits

- ⚡ **Higher success rate** - Easy PRs first build confidence
- 🎯 **Better resource use** - Don't waste time on hard cases
- 📊 **Predictable outcomes** - Consistent ordering logic

## Hook System

### Architecture

```
Main Process
    ├─ pre_discovery hook
    ├─ Discover PRs
    ├─ post_discovery hook
    │
    ├─ For each PR:
    │   ├─ pre_rebase hook
    │   ├─ Perform rebase
    │   ├─ post_rebase hook
    │   ├─ pre_push hook
    │   ├─ Push changes
    │   ├─ post_push hook
    │   └─ on_conflict hook (if conflict)
    │
    └─ on_complete hook
```

### Creating Custom Hooks

1. **Copy example**:
   ```bash
   cd .github/ci-rebase-hooks
   cp post_rebase.sh.example my_hook.sh
   chmod +x my_hook.sh
   ```

2. **Customize**:
   ```bash
   #!/usr/bin/env bash
   PR_NUM="$1"
   STATUS="$3"

   # Your custom logic
   if [[ "$STATUS" == "SUCCESS" ]]; then
     # Notify team
     notify_team "PR #$PR_NUM rebased!"
   fi
   ```

3. **Register**:
   ```yaml
   hooks:
     post_rebase:
       - my_hook.sh
   ```

### Use Cases

| Use Case | Hook | Example |
|----------|------|---------|
| Slack notifications | `post_rebase` | Send message on success/fail |
| Jira updates | `post_rebase` | Update ticket status |
| Detailed logging | `on_conflict` | Generate conflict reports |
| Custom validation | `pre_rebase` | Check branch protection |
| Cleanup | `on_complete` | Archive logs, generate reports |

### Benefits

- 🔌 **Extend without changes** - No core code modification
- 🎨 **Customize to your workflow** - Team-specific logic
- 🔧 **Easy to maintain** - Hooks are isolated
- 📚 **Share knowledge** - Team can contribute hooks

## Metrics and Telemetry

### What's Tracked

```json
{
  "session_id": "uuid",
  "started_at": "2025-01-15T10:00:00Z",
  "prs_processed": 10,
  "prs_succeeded": 8,
  "prs_failed": 1,
  "prs_conflicts": 1,
  "total_duration_sec": 300,
  "operations": [
    {
      "pr": "123",
      "status": "SUCCESS",
      "duration_sec": 25,
      "timestamp": "2025-01-15T10:01:00Z"
    }
  ]
}
```

### Configuration

```yaml
enable_metrics: true
metrics_file: /tmp/ci-rebase-metrics.json
track_success_patterns: true
```

### Using Metrics

```bash
# View success rate
jq '.prs_succeeded / .prs_processed * 100' /tmp/ci-rebase-metrics.json

# Find slow rebases
jq '.operations[] | select(.duration_sec > 60)' /tmp/ci-rebase-metrics.json

# Identify patterns
jq '.operations | group_by(.status) | map({status: .[0].status, count: length})' \
  /tmp/ci-rebase-metrics.json
```

### Benefits

- 📊 **Learn from history** - Understand what works
- 🎯 **Optimize process** - Find bottlenecks
- 📈 **Track improvements** - Measure success over time
- 🔍 **Debug issues** - Detailed operation logs

## State Management and Recovery

### State Persistence

Every operation is saved to state file:

```json
{
  "started": "2025-01-15T10:00:00Z",
  "base": "origin/main",
  "results": {
    "123": {
      "status": "OK",
      "branch": "feature/test",
      "timestamp": "2025-01-15T10:05:00Z"
    },
    "124": {
      "status": "CONFLICT",
      "branch": "feature/complex",
      "timestamp": "2025-01-15T10:10:00Z"
    }
  }
}
```

### State History

```yaml
keep_state_history: true
max_state_history: 10
```

Keeps timestamped snapshots:
```
/tmp/global-ci-rebase-state.json
/tmp/global-ci-rebase-state.json.20250115_100000
/tmp/global-ci-rebase-state.json.20250115_110000
```

### Resume Capability

```yaml
auto_resume: true
```

If a run is interrupted:
1. Detect incomplete state file
2. Resume from last successful operation
3. Skip already-processed PRs

### Benefits

- 💾 **Never lose progress** - Resume after failures
- 🔍 **Audit trail** - Track all operations
- 🛡️ **Safety net** - Recover from interruptions
- 📊 **Historical data** - Analyze trends

## Filtering Enhancements

### Label-based Filtering

```yaml
default_filters:
  skip_labels:
    - do-not-rebase  # Never rebase these
    - wip            # Work in progress
    - hold           # On hold

  require_labels:
    - ready-to-rebase  # Only these (if not empty)
```

### Age-based Filtering

```yaml
default_filters:
  min_age_hours: 1   # Skip very new PRs
  max_age_days: 90   # Skip very old PRs
```

### Draft PR Handling

```yaml
default_filters:
  skip_drafts: true  # Don't rebase draft PRs
```

### Benefits

- 🎯 **Target specific PRs** - Fine-grained control
- 🛡️ **Prevent accidents** - Skip protected PRs
- ⚡ **Faster processing** - Skip irrelevant PRs

## Practical Examples

### Example 1: Team-Specific Setup

```yaml
# .github/ci-rebase.config.yml

# Conservative settings for safety
enable_conflict_detection: true
skip_conflicting_prs: true
conflict_threshold: 0.8  # Very high confidence required

# Team workflow
default_filters:
  skip_labels: [wip, do-not-merge, on-hold]
  skip_drafts: true

# Notifications
hooks:
  post_rebase:
    - slack_notify.sh
  on_conflict:
    - create_jira_ticket.sh
```

### Example 2: Aggressive Automation

```yaml
# For teams wanting maximum automation

# Process everything
enable_conflict_detection: true
skip_conflicting_prs: false  # Try anyway
conflict_threshold: 0.95     # Only skip obvious conflicts

# Smart processing
enable_dependency_detection: true
enable_smart_ordering: true

# Auto-recover
auto_resume: true

# High throughput
max_prs_per_run: 100
parallel_workers: 3  # Experimental
```

### Example 3: Learning Mode

```yaml
# For understanding patterns

# Enable all intelligence
enable_conflict_detection: true
enable_dependency_detection: true
enable_smart_ordering: true

# Collect data
enable_metrics: true
track_success_patterns: true
keep_state_history: true
max_state_history: 50

# Hooks for analysis
hooks:
  post_rebase:
    - log_metrics.sh
  on_complete:
    - generate_analytics.sh
```

## Migration Path

### Phase 1: Enable Configuration (Week 1)

1. Review `.github/ci-rebase.config.yml`
2. Adjust thresholds for your team
3. Add team-specific skip labels
4. Test with `--report` mode

### Phase 2: Add Intelligence (Week 2-3)

1. Enable conflict detection
2. Enable smart ordering
3. Monitor metrics
4. Adjust confidence thresholds

### Phase 3: Extend with Hooks (Week 4+)

1. Create team notifications
2. Add custom validation
3. Integrate with existing tools
4. Share successful hooks with team

### Phase 4: Optimize (Ongoing)

1. Review metrics weekly
2. Adjust ordering criteria
3. Fine-tune filters
4. Add experimental features

## Troubleshooting

### Conflict Detection Too Conservative

```yaml
# Lower threshold
conflict_threshold: 0.5  # 50% instead of 70%
```

### Processing Too Slow

```yaml
# Reduce scope
max_prs_per_run: 25

# Or disable heavy features
enable_dependency_detection: false
```

### Hooks Not Running

1. Check executable: `ls -l .github/ci-rebase-hooks/*.sh`
2. Check config: `yq eval '.hooks' .github/ci-rebase.config.yml`
3. Test manually: `./hooks/your_hook.sh <args>`

### Metrics Not Collecting

```yaml
# Ensure enabled
enable_metrics: true

# Check file permissions
# ls -l /tmp/ci-rebase-metrics.json
```

## Best Practices

### 1. Start Conservative

Begin with safe settings:
- High conflict threshold (0.8+)
- Low max PRs (25-50)
- Skip drafts and labeled PRs

### 2. Monitor and Adjust

Review metrics weekly:
- Success rate
- Common failure patterns
- Average duration

### 3. Document Team Decisions

Add comments to config:
```yaml
# We skip WIP because team adds it manually
skip_labels: [wip]
```

### 4. Test Before Rolling Out

Always test configuration changes:
```bash
# Dry run with new config
./tools/global_ci_branches.zsh --report
```

### 5. Share Hooks

Create team library:
```
.github/ci-rebase-hooks/
  ├── team/
  │   ├── slack_notify.sh
  │   ├── jira_update.sh
  │   └── README.md
  └── examples/
      └── *.sh.example
```

## Future Enhancements

The system is designed to grow:

### Planned Features

- Machine learning conflict prediction
- Parallel rebase processing
- Auto-merge after successful rebase (optional)
- Integration with more external systems

### Extensibility Points

- Custom ordering algorithms (via hooks)
- Plugin system for conflict resolution
- External state storage (database)
- Advanced metrics visualization

## Support and Contribution

### Getting Help

1. Check documentation
2. Review example hooks
3. Check metrics and logs
4. Create issue with details

### Contributing

1. Share successful hooks
2. Suggest config improvements
3. Report patterns you discover
4. Submit enhancements

---

**Remember**: The goal is smarter automation that adapts to your team, not rigid rules. Customize, experiment, and improve over time!
