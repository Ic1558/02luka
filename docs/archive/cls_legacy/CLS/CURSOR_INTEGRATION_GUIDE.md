# CLS Integration Guide for Cursor IDE

## 🚀 Quick Start (5 seconds)

**In any Cursor terminal:**
```bash
# 1. Reload your shell to activate CLS hooks
exec zsh

# 2. Enable CLS learning
cls-on

# 3. Run commands normally - they'll be logged automatically!
git status
npm test
echo "Hello, CLS!"

# 4. View what was learned
cls-stats
```

---

## 🎯 What Just Happened?

CLS (Command Learning System) is now **automatically capturing** every command you run in Cursor's terminal, including:
- The command itself
- Exit code (success/failure)
- Working directory
- Timestamp
- Session ID

This data is used to:
- Detect error patterns
- Learn your workflow habits
- Provide context for AI assistance
- Build a knowledge base of your commands

---

## 📋 Available Commands

### Toggle Learning
```bash
cls-on          # ✅ Enable automatic command capture
cls-off         # ❌ Disable automatic command capture
cls-status      # 📊 Show current status
```

### Helper Commands
```bash
cls stats       # Show database statistics
cls analyze     # Run pattern detection
cls learn-last  # Manually log last command from history
cls learn-clip  # Log command from clipboard
```

### Quick Aliases
```bash
cls-analyze     # Quick pattern analysis
cls-stats       # Quick statistics view
```

---

## 🎛️ Configuration

### Environment Variables
```bash
export CLS_ENABLED=1                # 0=disabled, 1=enabled
export CLS_MIN_CMD_LENGTH=3         # Ignore short commands
export SESSION_ID="my-session-123"  # Custom session identifier
```

### Exclude Commands
The hooks automatically skip:
- Commands shorter than 3 characters (configurable)
- CLS commands themselves (`cls-*`, `cls_*.zsh`)
- Shell built-ins without side effects

---

## 📂 Where Data is Stored

```
~/02luka/memory/cls/
├── learning_db.jsonl       # All captured commands & interactions
├── session_context.json    # Session metadata (append-only)
├── patterns.jsonl          # Detected patterns (error rates, etc.)
└── policies.json           # Learning policies (optional)

~/02luka/g/logs/
└── cls_phase3.log         # CLS system logs
```

---

## 🔍 Example Workflow in Cursor

### 1. Start a Coding Session
```bash
# Open Cursor terminal
cls-on
export SESSION_ID="feature-auth-$(date +%Y%m%d)"
```

### 2. Work Normally
```bash
git checkout -b feature/auth
npm install jsonwebtoken
npm test
# ... all commands are automatically logged ...
```

### 3. Check Your Progress
```bash
cls-stats
# Output:
# 📈 CLS Database Statistics:
#   Learning DB: 47 entries
#   Session Context: 5 sessions
#   Patterns: 12 patterns
```

### 4. Analyze Patterns
```bash
cls-analyze
# Output:
# 🔍 Analyzing command patterns...
# 📊 Latest patterns:
#   • command_usage: 47 cmds, 8% errors
```

### 5. End Session
```bash
cls session-save coding-complete '{"feature":"auth","tests":"passing"}'
cls-off
```

---

## 🎨 Integration with Cursor Features

### 1. Command Palette Integration

**Create `.cursor/commands/cls-analyze.sh`:**
```bash
#!/bin/bash
~/02luka/tools/cls_cursor_helper.zsh analyze
```

Then run from Cursor's command palette: `> CLS: Analyze Patterns`

### 2. Keybinding (Optional)

Add to Cursor's `keybindings.json`:
```json
{
  "key": "ctrl+shift+l",
  "command": "workbench.action.terminal.sendSequence",
  "args": {
    "text": "cls-stats\n"
  }
}
```

### 3. Status Bar (Via Cursor Extension)

You can create a custom extension that:
- Shows CLS status (enabled/disabled) in status bar
- Displays session ID
- Shows command count for current session

---

## 🧪 Testing the Integration

### Test 1: Basic Capture
```bash
cls-on
echo "test command"
cls-stats
# Should show 1+ new entry
```

### Test 2: Error Detection
```bash
cls-on
false  # Intentional failure (exit code 1)
cls-analyze
# Should detect error rate > 0%
```

### Test 3: JSON Safety
```bash
cls-on
echo "a\" b\\ c"
tail -1 ~/02luka/memory/cls/learning_db.jsonl
# Should show properly escaped JSON
```

---

## 🔧 Troubleshooting

### Commands Not Being Logged

**Check 1: Is CLS enabled?**
```bash
cls-status
# Should show: ✅ CLS learning: ENABLED
```

**Check 2: Is the hook file sourced?**
```bash
type _cls_precmd
# Should show: _cls_precmd is a shell function
```

**Check 3: Check the log file**
```bash
tail ~/02luka/g/logs/cls_phase3.log
```

### Performance Issues

If terminal feels slow:
```bash
# Increase minimum command length
export CLS_MIN_CMD_LENGTH=5

# Or disable temporarily
cls-off
```

### Reset CLS Data

```bash
# Backup first
cp ~/02luka/memory/cls/learning_db.jsonl ~/02luka/memory/cls/learning_db.backup.jsonl

# Clear data
> ~/02luka/memory/cls/learning_db.jsonl
> ~/02luka/memory/cls/session_context.json
> ~/02luka/memory/cls/patterns.jsonl
```

---

## 🎓 Advanced Usage

### Custom Session Contexts
```bash
cls-on
export SESSION_ID="debug-$(date +%s)"

# Work...
# When you solve something:
cls session-save bug-fix '{"issue":"PROJ-123","solution":"cache invalidation"}'
```

### Integrate with Git Hooks
```bash
# .git/hooks/post-commit
#!/bin/bash
if [[ "$CLS_ENABLED" == "1" ]]; then
  ~/02luka/tools/cls_save_context.zsh session \
    "$(date +%s)" \
    "git-commit" \
    "{\"hash\":\"$(git rev-parse HEAD)\"}"
fi
```

### Export for Analysis
```bash
# Export to CSV for analysis in Excel/Sheets
jq -r '[.timestamp, .metadata.command, .metadata.exit_code] | @csv' \
  ~/02luka/memory/cls/learning_db.jsonl > commands.csv
```

---

## 📊 Privacy & Data Management

### What Gets Logged
- ✅ Command text
- ✅ Exit codes
- ✅ Working directory paths
- ✅ Timestamps

### What Doesn't Get Logged
- ❌ Command output (too large)
- ❌ Passwords or secrets (if you don't type them as commands)
- ❌ File contents
- ❌ Network traffic

### Best Practices
1. **Don't paste secrets as commands** - CLS will log them
2. **Review learning_db.jsonl periodically** - Delete sensitive entries
3. **Use `.gitignore`** - Exclude `~/02luka/memory/cls/` from git repos
4. **Session IDs** - Use descriptive names without sensitive info

---

## 🎬 Next Steps

1. **Enable CLS in your daily workflow**
   ```bash
   cls-on
   ```

2. **Create a startup script** (optional)
   ```bash
   # Add to ~/.zshrc
   cls-on  # Auto-enable on shell start
   ```

3. **Set up pattern alerts** (future)
   - Get notified when error rate > 20%
   - Alert on repeated failures

4. **Integrate with AI assistants**
   - Feed command history to Claude/GPT
   - Use patterns for context-aware suggestions

---

## 📚 Related Documentation

- **Bug Fix Report**: `~/02luka/CLS/CLS_BUG_FIX_VERIFICATION_*.md`
- **CLS Phase Documentation**: `~/02luka/CLS/*.md`
- **Script Sources**: `~/02luka/tools/cls_*.zsh`

---

## 🤝 Support

**Check Status:**
```bash
cls-status
cls-stats
tail ~/02luka/g/logs/cls_phase3.log
```

**Quick Fix:**
```bash
# Reload shell environment
exec zsh

# Re-enable CLS
cls-on
```

---

**Last Updated:** 2025-10-31
**Version:** 1.0
**Status:** ✅ Production Ready
