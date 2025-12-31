# Codex Full System Access (Safe Mode)
**Goal:** Enable Codex to work anywhere in system (like CLC) while staying safe
**Challenge:** Balance flexibility vs safety

---

## Current Limitation

**Current config (`workspace-write`):**
- ✅ Read: ~/02luka only (best practice)
- ✅ Write: ~/02luka only
- ❌ **Cannot work outside ~/02luka**

**Why this is limiting:**
- Cannot analyze system configs (`/etc`, `~/.config`)
- Cannot read other projects outside 02luka
- Cannot help with system-wide tasks

---

## How CLC Works (For Comparison)

**CLC permission model:**
```
1. CLC wants to read /etc/hosts
   → ✅ Reads directly (no sandbox block)

2. CLC wants to write /etc/hosts
   → ⚠️ Prompts: "About to modify system file. Allow? [y/N]"
   → User approves → ✅ Writes

3. CLC wants to run `sudo rm -rf /`
   → ⚠️ Prompts: "DANGEROUS COMMAND. Are you sure? [y/N]"
   → User declines → ❌ Blocked
```

**Key difference:**
- **CLC = Trust + Approval** (can access anywhere, asks permission)
- **Codex = Zones + Approval** (blocked by zones, asks permission)

---

## Solution: 3-Tier Access Strategy

### Tier 1: Safe Workspace (Current) ✅
**For:** 80% of daily work
**Config:**
```toml
[sandbox]
default_mode = "workspace-write"
auto_approve_workspace_writes = true
```

**Access:**
- Read: ~/02luka ✅
- Write: ~/02luka ✅
- Outside: ❌ Blocked

---

### Tier 2: Expanded Read (Recommended Addition)
**For:** Analysis, research, context gathering
**Config:**
```toml
[sandbox]
default_mode = "workspace-write"
auto_approve_reads = true  # ✅ Enable full read access

# Readable directories (anywhere in system)
[permissions]
read_anywhere = true  # ✅ Like CLC
write_restricted = true  # ✅ Still safe
```

**Access:**
- Read: ✅ Anywhere in system (like CLC)
- Write: ~/02luka only ✅
- Outside write: ❌ Blocked (safe)

**Use case:**
```bash
# Can analyze system configs
codex-auto "analyze my zsh config at ~/.zshrc"

# Can read other projects
codex-auto "review ~/other-project/src/main.py"

# Can check system files
codex-auto "check my SSH config at ~/.ssh/config"
```

---

### Tier 3: Full Access (Explicit Approval Required)
**For:** System-wide changes, emergency fixes
**Config:**
```toml
# Add to ~/.codex/config.toml
[projects."/Users/icmini"]
trust_level = "trusted"  # ✅ Already set
write_allowed = true  # ✅ Add this

[projects."/"]
trust_level = "trusted"  # ⚠️ Full system access
write_prompt = true  # ✅ Always prompt before write
```

**Access:**
- Read: ✅ Anywhere
- Write: ✅ Anywhere (but prompts!)
- Safety: ✅ Prompts for non-workspace writes

**Use case:**
```bash
# System-wide task
codex-auto "update my global git config at ~/.gitconfig"
# → ⚠️ Prompts: "Write outside workspace. Allow? [y/N]"
```

---

## Recommended Config: Tier 2 (Expanded Read)

**Best balance of safety + flexibility:**

### Step 1: Update `~/.codex/config.toml`

```toml
model = "gpt-5.2-codex"
model_reasoning_effort = "high"

# Trusted projects
[projects."/Users/icmini"]
trust_level = "trusted"

[projects."/Users/icmini/02luka"]
trust_level = "trusted"

# Sandbox settings (UPDATED)
[sandbox]
default_mode = "workspace-write"
auto_approve_reads = true  # ✅ NEW: Read anywhere
auto_approve_workspace_writes = true

# Approval settings (UPDATED)
[approval]
mode = "on-request"
trust_workspace_commands = true
prompt_for_dangerous = true
prompt_for_outside_writes = true  # ✅ NEW: Prompt for writes outside workspace

# Permissions (NEW SECTION)
[permissions]
read_anywhere = true  # ✅ Can read system files
write_restricted_to = [  # ✅ Can only write here
  "/Users/icmini/02luka",
  "/Users/icmini/.config",  # Allow config updates
  "/Users/icmini/.zshrc",   # Allow shell config
]

# Workspace settings
[workspace]
additional_writable = [
  "/Users/icmini/02luka/tools",
  "/Users/icmini/02luka/g/reports",
  "/Users/icmini/02luka/apps",
  "/Users/icmini/.codex",  # ✅ Allow Codex config updates
]

# Dangerous patterns (always prompt)
[safety]
always_prompt_for = [
  "rm -rf",
  "sudo",
  "git push --force",
  "chmod 777",
  "/etc/**",  # System files
  "/System/**",  # macOS system
]

[notice]
"hide_gpt-5.1-codex-max_migration_prompt" = true

[notice.model_migrations]
"gpt-5.1-codex-max" = "gpt-5.2-codex"
```

---

### Step 2: Create New Aliases

```bash
# Add to ~/.zshrc

# Tier 1: Workspace only (existing)
alias codex-safe='codex -s workspace-write'
alias codex-auto='codex -a on-request -s workspace-write'

# Tier 2: Expanded read (NEW)
alias codex-read='codex -s workspace-write -c "sandbox_permissions=[\"disk-full-read-access\"]"'
alias codex-system='codex -s workspace-write -c "sandbox_permissions=[\"disk-full-read-access\"]"'

# Tier 3: Full access with prompts (DANGEROUS)
alias codex-full='codex -s danger-full-access'

# Recommended: System analysis (read-only, safe)
alias codex-analyze='codex -s workspace-write -c "sandbox_permissions=[\"disk-full-read-access\"]" --read-only'
```

---

## Safety Comparison

| Scenario | CLC Behavior | Codex (Tier 2) | Safe? |
|----------|--------------|----------------|-------|
| **Read ~/.zshrc** | ✅ Reads directly | ✅ Reads directly | ✅ Safe (read-only) |
| **Read /etc/hosts** | ✅ Reads directly | ✅ Reads directly | ✅ Safe (read-only) |
| **Write ~/02luka/tools/x.sh** | ✅ Writes (no prompt) | ✅ Writes (no prompt) | ✅ Safe (trusted workspace) |
| **Write ~/.zshrc** | ⚠️ Prompts first | ⚠️ Prompts first | ✅ Safe (approval required) |
| **Write /etc/hosts** | ⚠️ Prompts + sudo | ❌ Blocked (or prompts in Tier 3) | ✅ Safe (blocked or approved) |
| **Run `rm -rf ~/*`** | ⚠️ Prompts (dangerous) | ⚠️ Prompts (dangerous) | ✅ Safe (approval required) |

**Conclusion:** Tier 2 = Same safety as CLC ✅

---

## Usage Examples

### Example 1: System Analysis (Safe)
```bash
# Read system config for analysis
codex-system "analyze my zsh config and suggest performance improvements"

# ✅ Reads ~/.zshrc
# ✅ Reads ~/.zsh_history
# ✅ Reads related configs
# ❌ Cannot write (read-only mode)
```

### Example 2: Multi-Project Work
```bash
# Work across multiple projects
codex-system "compare 02luka tools with ~/other-project/scripts"

# ✅ Reads ~/02luka/tools/**
# ✅ Reads ~/other-project/scripts/**
# ✅ Can write to ~/02luka only
# ⚠️ Prompts if trying to write ~/other-project
```

### Example 3: Config Updates (Prompted)
```bash
# Update shell config
codex-auto "add alias to ~/.zshrc for quick git status"

# ✅ Reads ~/.zshrc
# ⚠️ Prompts: "Write to ~/.zshrc (outside workspace). Allow? [y/N]"
# User: y
# ✅ Writes to ~/.zshrc
```

### Example 4: Dangerous Operation (Blocked or Prompted)
```bash
# Try to modify system file
codex-auto "update /etc/hosts to block facebook.com"

# ❌ Blocked (Tier 2 config)
# OR
# ⚠️⚠️⚠️ Prompts: "DANGEROUS: Write to /etc/hosts. Requires sudo. Allow? [y/N]"
```

---

## Migration Path

### Current State (Tier 1)
```
Read: ~/02luka only
Write: ~/02luka only
```

### Recommended (Tier 2 - Expanded Read)
```
Read: ✅ Anywhere in system
Write: ~/02luka + ~/.config + ~/.zshrc (with prompts)
```

### Optional (Tier 3 - Full Access)
```
Read: ✅ Anywhere
Write: ✅ Anywhere (with prompts for each write)
```

---

## Implementation

### Option 1: Automatic Update (Recommended)
```bash
# Run updated setup script
zsh ~/02luka/tools/setup_codex_full_access.zsh

# What it does:
# 1. Backup current config
# 2. Add Tier 2 permissions
# 3. Add new aliases
# 4. Test read access
```

### Option 2: Manual Update
```bash
# 1. Backup config
cp ~/.codex/config.toml ~/.codex/config.toml.backup.tier1

# 2. Edit config manually
# Add [permissions] section (see above)

# 3. Add aliases to ~/.zshrc
# (see aliases above)

# 4. Reload
source ~/.zshrc
```

---

## Testing Expanded Access

### Test 1: Read Outside Workspace
```bash
codex-system "read and summarize my ~/.zshrc file"
# Expected: ✅ Reads successfully, provides summary
```

### Test 2: Write Inside Workspace (No Prompt)
```bash
codex-auto "create test file in ~/02luka/tmp/test.txt"
# Expected: ✅ Creates file without prompt
```

### Test 3: Write Outside Workspace (Prompts)
```bash
codex-auto "add comment to ~/.zshrc"
# Expected: ⚠️ Prompts before writing
```

### Test 4: Dangerous Command (Blocked)
```bash
codex-auto "run sudo rm -rf /tmp/test"
# Expected: ⚠️⚠️⚠️ Prompts with warning
```

---

## Security Considerations

### What's Safe (Tier 2)

1. ✅ **Read anywhere = Safe**
   - Reading files cannot break system
   - Good for context, analysis, research

2. ✅ **Write restrictions = Safe**
   - Only ~/02luka writes auto-approved
   - Other writes prompt for approval

3. ✅ **Dangerous commands = Prompted**
   - `rm -rf`, `sudo`, etc. always prompt
   - Even in Tier 3 full-access mode

### What to Watch

1. ⚠️ **Prompt fatigue**
   - Too many prompts = users say "yes" without reading
   - Mitigation: Define good write_restricted_to list

2. ⚠️ **Accidental approvals**
   - User might approve dangerous write by accident
   - Mitigation: Clear warning messages, git safety net

---

## Comparison Table: All Tiers

| Feature | Tier 1 (Current) | Tier 2 (Recommended) | Tier 3 (Full) |
|---------|------------------|---------------------|---------------|
| **Read Access** | ~/02luka only | ✅ Anywhere | ✅ Anywhere |
| **Write Access** | ~/02luka only | ~/02luka + approved dirs | ✅ Anywhere (prompts) |
| **Prompts** | Minimal | Medium (outside writes) | High (all outside writes) |
| **Safety** | ✅ High | ✅ High | ⚠️ Medium (relies on prompts) |
| **Flexibility** | ⚠️ Low | ✅ High | ✅ Very High |
| **Use Case** | 02luka work only | System analysis + 02luka work | Emergency system-wide fixes |

---

## Recommendation

**Use Tier 2 (Expanded Read) as default:**

**Why:**
- ✅ Same read access as CLC (anywhere in system)
- ✅ Safe write restrictions (prompts for outside writes)
- ✅ Flexible (can analyze system configs, other projects)
- ✅ Practical (covers 95% of use cases)

**When to use Tier 3:**
- Emergency system-wide changes only
- Always with explicit `codex-full` command
- Never as default

---

## Next Steps

1. **Review Tier 2 config** (see above)
2. **Decide on write_restricted_to list** (which dirs should allow writes?)
3. **Run setup script** (I'll create this)
4. **Test with non-critical tasks**
5. **Gradually expand trust as confidence builds**

---

**File:** `g/docs/CODEX_FULL_SYSTEM_ACCESS.md`
**Status:** Design complete, ready for Boss approval
