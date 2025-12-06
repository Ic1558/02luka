# /review

**Goal:** Run Local Agent Review on staged/unstaged changes and display alerts in Cursor's Problems panel.

## Usage

- Provide: mode (`staged`, `unstaged`, `last-commit`, `branch`) or leave empty for `staged` (default)
- Optional: `--offline` flag to run without API call (free, no issues detected)
- Output: VS Code diagnostics format for Problems panel integration

## Steps (tool-facing)

1) Determine mode: Use provided mode or default to `staged`

2) Run Local Agent Review:
   ```bash
   python3 tools/local_agent_review.py ${MODE:-staged} \
     --format vscode-diagnostics \
     --output .vscode/local_agent_review_diagnostics.json
   ```

3) If `--offline` flag provided, add `--offline` flag to skip API call

4) Display summary and remind user to check Problems panel (`Cmd+Shift+M`)

5) If issues found, show exit code and alert count

## Example

```
/review staged
/review unstaged
/review last-commit
/review staged --offline
```

This will:
- Run Local Agent Review on specified git changes
- Generate VS Code diagnostics for Problems panel
- Save report to `g/reports/reviews/`
- Display alerts in Cursor's Problems panel (`Cmd+Shift+M`)

## Integration with /commit

Local Agent Review is automatically run in `pre_commit.zsh` hook when using `/commit` if `LOCAL_REVIEW_ENABLED=1` is set.
