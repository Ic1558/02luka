# Local Agent Review - Cursor IDE Integration

## Overview

Local Agent Review can now display alerts in Cursor IDE's Problems panel, similar to Cursor's built-in Agent Review.

## How It Works

### 1. VS Code Diagnostics Format

Local Agent Review outputs diagnostics in VS Code format that Cursor's Problems panel can read:

- **Format**: `vscode-diagnostics` (JSON format with file URIs and diagnostic ranges)
- **Output**: `.vscode/local_agent_review_diagnostics.json`
- **Problem Matcher**: Also outputs to stderr in format: `file:line:col: severity: message`

### 2. VS Code Tasks

Two tasks are available in `.vscode/tasks.json`:

- **"Local Agent Review: Staged Changes"** - Reviews staged git changes
- **"Local Agent Review: All Unstaged Changes"** - Reviews all unstaged changes

**Usage:**
1. Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
2. Type "Tasks: Run Task"
3. Select "Local Agent Review: Staged Changes"
4. Check Problems panel (`Cmd+Shift+M`) for alerts

### 3. Git Hook Integration (Optional)

Auto-run review on staged changes before commit:

```bash
# Install git hook
cd /Users/icmini/02luka
ln -s ../../tools/local_agent_review_git_hook.zsh .git/hooks/pre-commit

# Enable (optional)
export LOCAL_REVIEW_ENABLED=1
```

**Note**: Git hook runs in background and doesn't block commits (just warns).

## Displaying Alerts in Cursor

### Method 1: Run Task Manually

1. **Run Task**: `Cmd+Shift+P` → "Tasks: Run Task" → "Local Agent Review: Staged Changes"
2. **View Problems**: `Cmd+Shift+M` (or click Problems icon in Activity Bar)
3. **See Alerts**: Issues appear with severity (Error/Warning/Info/Hint)

### Method 2: Auto-run via Git Hook

1. **Install hook** (see above)
2. **Stage changes**: `git add .`
3. **Commit**: `git commit -m "message"`
4. **Hook runs automatically** → Check Problems panel

### Method 3: Command Line + Problems Panel

```bash
# Run review and output diagnostics
python3 tools/local_agent_review.py staged --format vscode-diagnostics

# Problems panel will show alerts from stderr output
```

## Diagnostics Format

### VS Code Diagnostics JSON

```json
{
  "file:///path/to/file.py": [
    {
      "range": {
        "start": {"line": 10, "character": 0},
        "end": {"line": 10, "character": 1000}
      },
      "severity": 1,
      "source": "Local Agent Review",
      "message": "Potential bug: ...",
      "code": "bug"
    }
  ]
}
```

### Problem Matcher Format (stderr)

```
/path/to/file.py:10:1: error: Potential bug description
/path/to/file.py:25:1: warning: Security issue description
```

## Severity Mapping

| Local Review | VS Code Severity | Problems Panel |
|-------------|------------------|----------------|
| `critical`   | Error (1)        | Red ❌         |
| `warning`    | Warning (2)      | Yellow ⚠️      |
| `suggestion` | Information (3)   | Blue ℹ️        |
| `info`       | Hint (4)          | Light Blue 💡  |

## Troubleshooting

### Alerts Not Showing?

1. **Check Problems Panel**: `Cmd+Shift+M` (Mac) or `Ctrl+Shift+M` (Windows/Linux)
2. **Filter Settings**: Make sure "Errors", "Warnings", "Info" are enabled in Problems panel
3. **Run Task Again**: Tasks may need to be run manually
4. **Check Output**: Review script should output to stderr in Problem Matcher format

### Git Hook Not Running?

1. **Check Hook Exists**: `ls -la .git/hooks/pre-commit`
2. **Check Permissions**: `chmod +x .git/hooks/pre-commit`
3. **Check Environment**: `echo $LOCAL_REVIEW_ENABLED` (should be `1`)
4. **Check API Key**: `echo $ANTHROPIC_API_KEY` (should be set)

### Diagnostics File Not Created?

1. **Check Directory**: `.vscode/` directory must exist
2. **Check Permissions**: Script needs write access
3. **Check Output**: Review must find issues (empty reviews don't create file)

## Comparison with Cursor's Agent Review

| Feature | Cursor Agent Review | Local Agent Review |
|---------|---------------------|-------------------|
| **Alert Display** | ✅ Built-in (Source Control tab) | ✅ Problems panel |
| **Auto-run** | ✅ On commit (if enabled) | ✅ Via git hook (optional) |
| **Cost** | 💰 Usage-based (subscription) | 💰 Pay-per-use (~$0.10/review) |
| **Offline Mode** | ❌ No | ✅ Yes (`--offline`) |
| **Customization** | ❌ Limited | ✅ Full control (config, prompts) |

## Next Steps

1. **Test Integration**: Run task manually and check Problems panel
2. **Install Git Hook**: Enable auto-review on commits
3. **Customize**: Adjust severity mapping or output format in config
4. **Monitor**: Check `.vscode/local_agent_review_diagnostics.json` for diagnostics

---

**See Also:**
- [Local Agent Review Usage Guide](../feature-dev/local_agent_review/251206_local_agent_review_USAGE.md)
- [Local Agent Review Specification](../feature-dev/local_agent_review/251206_local_agent_review_SPEC_v01.md)
