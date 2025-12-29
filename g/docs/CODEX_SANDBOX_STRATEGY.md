# Codex Sandbox Strategy for 02luka
**Goal:** Enable Codex to work on real files without sandbox blocking
**Balance:** Safety vs Productivity

---

## Current Status

**Config:** `~/.codex/config.toml`
```toml
model = "gpt-5.2-codex"
model_reasoning_effort = "high"

[projects."/Users/icmini"]
trust_level = "trusted"

[projects."/Users/icmini/02luka"]  ✅ ALREADY TRUSTED
trust_level = "trusted"
```

**Status:** ✅ 02luka is trusted, but sandbox mode not configured

---

## Sandbox Modes Available

| Mode | Read | Write | Risk | Use Case |
|------|------|-------|------|----------|
| `read-only` | ✅ | ❌ | 🟢 Safe | Analysis, review only |
| `workspace-write` | ✅ | ✅ Workspace only | 🟡 Medium | **Recommended for 02luka** |
| `danger-full-access` | ✅ | ✅ Anywhere | 🔴 High | Emergency only |

**Recommendation:** `workspace-write` (write to ~/02luka only)

---

## Strategy: 3-Tier Approach

### Tier 1: Safe Mode (Default - Recommended)

**Usage:**
```bash
# Run Codex with workspace-write (can edit 02luka files)
codex -s workspace-write

# Or set as alias
alias codex-work='codex -s workspace-write'
```

**Config addition:**
```toml
# Add to ~/.codex/config.toml
[sandbox]
default_mode = "workspace-write"
auto_approve_reads = true          # Auto-approve file reads
auto_approve_workspace_writes = true  # Auto-approve writes in trusted workspace
```

**Protection:**
- ✅ Can read/write ~/02luka (trusted workspace)
- ✅ Can read system files (for context)
- ❌ Cannot write outside ~/02luka
- ✅ Still prompts for dangerous commands (rm -rf, etc.)

**Recommended for:** 90% of tasks

---

### Tier 2: Auto Mode (Convenience)

**Usage:**
```bash
# Enable auto-approval for on-request commands
codex -a on-request -s workspace-write

# Or shorter alias
alias codex-auto='codex -a on-request -s workspace-write'
```

**Config addition:**
```toml
[approval]
mode = "on-request"  # Auto-approve when model requests
trust_workspace_commands = true
```

**Protection:**
- ✅ Same as Tier 1
- ✅ Auto-approves commands in workspace
- ⚠️ Less prompts (faster but slightly riskier)

**Recommended for:** Routine refactoring, batch operations

---

### Tier 3: Danger Mode (Emergency Only)

**Usage:**
```bash
# BYPASS EVERYTHING (use with extreme caution!)
codex --dangerously-bypass-approvals-and-sandbox

# Or
alias codex-danger='codex --dangerously-bypass-approvals-and-sandbox'
```

**Protection:**
- ❌ No sandbox
- ❌ No approvals
- 🔴 Can delete/modify anything!

**Recommended for:**
- Emergency fixes only
- When you trust the task 100%
- **NEVER use for exploratory tasks**

---

## Recommended Config for 02luka

**File:** `~/.codex/config.toml`

```toml
model = "gpt-5.2-codex"
model_reasoning_effort = "high"

# Trusted projects
[projects."/Users/icmini"]
trust_level = "trusted"

[projects."/Users/icmini/02luka"]
trust_level = "trusted"

# Sandbox settings (ADD THIS)
[sandbox]
default_mode = "workspace-write"    # Can write to trusted workspace
auto_approve_reads = true           # Don't prompt for file reads
auto_approve_workspace_writes = true  # Don't prompt for workspace writes

# Approval settings (ADD THIS)
[approval]
mode = "on-request"                 # Auto-approve when model needs it
trust_workspace_commands = true     # Trust commands in workspace
prompt_for_dangerous = true         # Still prompt for rm, sudo, etc.

# Additional writable directories (OPTIONAL)
[workspace]
additional_writable = [
  "/Users/icmini/02luka/tools",
  "/Users/icmini/02luka/g/reports",
  "/Users/icmini/02luka/apps"
]

# Notice (keep existing)
[notice]
"hide_gpt-5.1-codex-max_migration_prompt" = true

[notice.model_migrations]
"gpt-5.1-codex-max" = "gpt-5.2-codex"
```

---

## How to Apply

### Option A: Update Config File (Recommended)

```bash
# Backup current config
cp ~/.codex/config.toml ~/.codex/config.toml.backup

# Edit config
# Add sandbox/approval sections from above

# Restart Codex
# (exit current session, start new one)
```

### Option B: Use Flags (No Config Change)

```bash
# Create aliases in ~/.zshrc
echo 'alias codex-safe="codex -s workspace-write"' >> ~/.zshrc
echo 'alias codex-auto="codex -a on-request -s workspace-write"' >> ~/.zshrc
echo 'alias codex-danger="codex --dangerously-bypass-approvals-and-sandbox"' >> ~/.zshrc

source ~/.zshrc
```

**Usage:**
```bash
codex-safe   # Default: workspace-write, prompts for commands
codex-auto   # Auto-approve, workspace-write
codex-danger # Full bypass (emergency only)
```

---

## Testing Sandbox Bypass

**Test 1: Can Codex write to 02luka?**
```bash
codex-safe "create a test file at ~/02luka/tmp/sandbox_test.txt with content 'Hello from Codex'"

# Expected: File created without blocking
# Check: ls ~/02luka/tmp/sandbox_test.txt
```

**Test 2: Can Codex edit existing files?**
```bash
codex-safe "add a comment '# Sandbox test' to ~/02luka/tools/session_save.zsh line 1"

# Expected: File edited, git diff shows change
# Check: git diff ~/02luka/tools/session_save.zsh
```

**Test 3: Does sandbox block writes outside 02luka?**
```bash
codex-safe "create a file at /tmp/outside_workspace.txt"

# Expected (workspace-write): Prompt or block
# Expected (danger mode): Creates file
```

**Test 4: Are dangerous commands still protected?**
```bash
codex-safe "remove all files in ~/02luka/tmp with rm -rf"

# Expected: Prompt asking for confirmation
# Even in workspace-write mode, dangerous commands prompt
```

---

## Comparison: Before vs After

### Before (Current - Blocking)
```bash
$ codex "fix tools/session_save.zsh"

Codex: I need to write to ~/02luka/tools/session_save.zsh
       Allow? [y/N] _  ⏸️ BLOCKED

User: y ✅
Codex: Done
```

**Problems:**
- ⏸️ Multiple prompts per task
- 🐌 Slow (wait for approval each time)
- 😤 Frustrating for batch operations

---

### After (Recommended Config)
```bash
$ codex-auto "fix tools/session_save.zsh"

Codex: Reading ~/02luka/tools/session_save.zsh... ✅ Auto-approved
Codex: Writing fix to session_save.zsh... ✅ Auto-approved
Codex: Done ✅

No prompts! Fast! ⚡
```

**Benefits:**
- ⚡ Zero prompts for routine operations
- 🚀 Fast iteration
- ✅ Still safe (workspace-only, dangerous commands prompt)

---

## Security Considerations

### What's Protected (Even After Bypass)

1. ✅ **Dangerous commands still prompt:**
   - `rm -rf`
   - `sudo`
   - `chmod 777`
   - File deletion in critical dirs

2. ✅ **Writes outside workspace blocked:**
   - Cannot write to `/etc`, `/usr`, `/System`
   - Cannot write to other user directories

3. ✅ **Git safety intact:**
   - Codex cannot run `git push --force` without approval
   - Cannot delete .git directory

### What's NOT Protected

1. ⚠️ **Files in workspace:**
   - Codex can overwrite any file in ~/02luka
   - **Mitigation:** Use git, commit before Codex tasks

2. ⚠️ **Commands in workspace:**
   - Codex can run any "safe" command in ~/02luka
   - **Mitigation:** Review Codex output before accepting

---

## Git-Based Safety Net (Recommended)

**Workflow:**
```bash
# 1. Always commit before Codex task
git add -A
git commit -m "before codex task: refactor session_save"

# 2. Run Codex
codex-auto "refactor tools/session_save.zsh with error handling"

# 3. Review changes
git diff

# 4. If good → keep. If bad → rollback
git reset --hard HEAD  # Rollback to pre-Codex state
```

**Why this works:**
- ✅ Can always undo Codex changes
- ✅ No permanent damage possible
- ✅ Codex can work freely (speed)
- ✅ You review output (safety)

---

## Integration with GG Orchestrator

**Add to routing spec:**

When routing to Codex, GG should:

1. **Pre-flight check:**
   ```bash
   # Ensure workspace is clean
   git status --porcelain
   # If dirty → commit first
   ```

2. **Codex invocation:**
   ```bash
   # Use safe mode by default
   codex-auto "task description"
   ```

3. **Post-task validation:**
   ```bash
   # Review changes
   git diff
   # Run tests
   pytest tests/
   # If pass → commit. If fail → rollback
   ```

---

## Recommended Aliases for 02luka

**Add to ~/.zshrc:**

```bash
# Codex aliases for 02luka workflow
alias codex-safe='codex -s workspace-write'
alias codex-auto='codex -a on-request -s workspace-write'
alias codex-danger='codex --dangerously-bypass-approvals-and-sandbox'

# Codex with git safety net
codex-task() {
  echo "📌 Creating safety checkpoint..."
  git add -A && git commit -m "pre-codex: $1" || echo "⚠️ No changes to commit"

  echo "🤖 Running Codex..."
  codex-auto "$1"

  echo "📊 Review changes:"
  git diff HEAD

  echo ""
  echo "✅ To keep: git add -A && git commit -m 'codex: $1'"
  echo "❌ To undo: git reset --hard HEAD"
}

# Usage: codex-task "refactor session_save.zsh"
```

---

## Next Steps

### Immediate (Do Now)
1. ✅ Update `~/.codex/config.toml` with recommended config
2. ✅ Add aliases to `~/.zshrc`
3. ✅ Test with 3 sandbox tests above

### Week 1 (After Testing)
1. Route 5-10 tasks to Codex with new config
2. Validate no blocking issues
3. Measure speed improvement

### Week 2+ (Production)
1. Update GG Orchestrator to use `codex-auto`
2. Enable full Codex routing for non-locked zones
3. Monitor for any safety issues

---

## Troubleshooting

### Problem: Still getting prompts for workspace writes

**Solution:**
```bash
# Check config
cat ~/.codex/config.toml | grep -A5 sandbox

# If missing, add:
[sandbox]
default_mode = "workspace-write"
auto_approve_workspace_writes = true
```

### Problem: "Permission denied" when writing

**Solution:**
```bash
# Check trust level
cat ~/.codex/config.toml | grep -A2 02luka

# Should see:
# [projects."/Users/icmini/02luka"]
# trust_level = "trusted"

# If missing, add it
```

### Problem: Codex still prompting for "dangerous" commands

**Expected behavior!** Even with bypass, dangerous commands like `rm -rf` should prompt.

**Override (use carefully):**
```bash
# Only if you're 100% sure
codex-danger "task that needs rm -rf"
```

---

## Summary

**Current State:** ✅ 02luka is trusted, sandbox not configured
**Recommended Fix:** Add `[sandbox]` config with `workspace-write` mode
**Expected Result:** Codex works freely in 02luka without blocking
**Safety Net:** Git commits before Codex tasks = easy rollback

**Next Action:** Update config file or use `codex-auto` alias

---

**File:** `g/docs/CODEX_SANDBOX_STRATEGY.md`
**Status:** Ready for implementation
**Risk:** Low (workspace-only, git safety net)
