---
description: Run Local Agent Review on staged/unstaged changes
---

# /02luka/review — Local Agent Review

Run Local Agent Review to analyze code changes and display alerts in Cursor's Problems panel.

## Steps (tool-facing)

1. **Determine mode**: Use `staged` (default), `unstaged`, `last-commit`, or `branch`
2. **Run review script**: Execute `tools/local_agent_review.py` with appropriate mode
3. **Output format**: Use `--format vscode-diagnostics` for Problems panel integration
4. **Display results**: Show summary and remind user to check Problems panel (`Cmd+Shift+M`)

## Command Execution

```bash
# Default: Review staged changes
python3 tools/local_agent_review.py staged \
  --format vscode-diagnostics \
  --output .vscode/local_agent_review_diagnostics.json

# With mode specified
python3 tools/local_agent_review.py ${MODE:-staged} \
  --format vscode-diagnostics \
  --output .vscode/local_agent_review_diagnostics.json
```

## Usage

```
/02luka/review [staged|unstaged|last-commit|branch] [--offline]
```

**Default:** `staged` (reviews staged git changes)

## Options

- `staged` - Review staged changes (default)
- `unstaged` - Review all unstaged changes
- `last-commit` - Review last commit
- `branch` - Review changes against main branch
- `--offline` - Run without API call (free, no issues detected)

## Output

- **Problems Panel**: Alerts appear in Cursor's Problems panel (`Cmd+Shift+M`)
- **Report File**: Markdown report saved to `g/reports/reviews/`
- **Diagnostics**: VS Code diagnostics format in `.vscode/local_agent_review_diagnostics.json`

## Examples

```bash
# Review staged changes
/02luka/review staged

# Review unstaged changes
/02luka/review unstaged

# Review last commit
/02luka/review last-commit

# Offline mode (no API call)
/02luka/review staged --offline
```

## Integration with /02luka/commit

Local Agent Review is automatically run in `pre_commit.zsh` hook when using `/02luka/commit`.

**To enable auto-review in commit hook:**
```bash
export LOCAL_REVIEW_ENABLED=1
```

**To disable auto-review in commit hook:**
```bash
export LOCAL_REVIEW_SKIP=1
```

## See Also

- [Local Agent Review Integration Guide](../../g/docs/local_agent_review_cursor_integration.md)
- [Local Agent Review Usage](../../g/reports/feature-dev/local_agent_review/251206_local_agent_review_USAGE.md)
