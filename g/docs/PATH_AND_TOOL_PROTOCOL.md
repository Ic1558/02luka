# Path and Tool Usage Protocol
**Version:** 1.0.0
**Status:** OFFICIAL
**Effective Date:** 2025-11-17
**Maintainer:** Boss (ittipong.c@gmail.com)

---

## 1. Purpose & Scope

**Purpose:** Define mandatory rules for path handling and tool usage in the 02luka system.

**Scope:**
- All agents (GG, GC, CLC, Codex, LPE, Kim)
- All scripts (LaunchAgents, tools, automation)
- All documentation that references file paths
- All code that performs file I/O operations

**Authority:** This protocol is binding for all SOT writes. Violations SHALL trigger pre-commit hook failures.

**Supersedes:**
- Ad-hoc path handling practices
- Hardcoded path references in legacy scripts
- Inconsistent tool selection patterns

---

## 2. Path Usage Rules

### 2.1 SOT Variable Usage

**RULE 2.1.1: SOT Variable Requirement**

All scripts and code **MUST** use the `$SOT` environment variable when referencing the 02luka root directory.

```bash
# ✅ CORRECT
source "$SOT/g/tools/lib/common.zsh"
cat "$SOT/g/knowledge/mls_lessons.jsonl"

# ❌ FORBIDDEN
source ~/02luka/g/tools/lib/common.zsh
cat /Users/icmini/02luka/g/knowledge/mls_lessons.jsonl
```

**Rationale:** Enables relocation, testing, and multi-environment deployments.

**Enforcement:** Git pre-commit hook **MUST** reject commits containing hardcoded paths.

---

**RULE 2.1.2: SOT Variable Definition**

The `$SOT` variable **MUST** be defined in shell initialization files:

```bash
# In ~/.zshrc or ~/.bashrc
export SOT="${HOME}/02luka"

# Verification
if [[ ! -d "$SOT" ]]; then
  echo "ERROR: SOT directory not found: $SOT" >&2
  exit 1
fi
```

**Validation:** LaunchAgent scripts **SHALL** validate `$SOT` existence before execution.

---

### 2.2 Path Structure

**RULE 2.2.1: Standard Directory Hierarchy**

The following directory structure is **MANDATORY**:

```
$SOT/
├── g/                          # Governance & system files (submodule)
│   ├── docs/                   # Documentation (protocols, specs, guides)
│   ├── tools/                  # System tools and utilities
│   ├── run/                    # Runtime executables (Node.js, daemons)
│   ├── reports/                # Generated reports (system, sessions, MLS)
│   ├── knowledge/              # MLS database and indexes
│   └── rag/                    # RAG system (deprecated, see knowledge/)
├── agents/                     # Work order agents
│   ├── json_wo_processor/      # JSON work order processor
│   ├── wo_executor/            # Work order executor
│   └── apply_patch_processor/  # Patch application agent
├── tools/                      # User-facing tools (parent repo)
│   ├── mls_capture.zsh         # MLS capture tool
│   └── session_save.zsh        # Session save tool
├── bridge/                     # Integration bridges
├── mcp/                        # MCP servers
└── LaunchAgents/               # LaunchAgent plist files
    ├── disabled/               # Disabled agents
    └── archived/               # Deprecated agents
```

**RULE 2.2.2: Submodule Path Awareness**

Scripts **MUST** be aware of submodule boundaries:

```bash
# ✅ CORRECT: g/ is a submodule
cd "$SOT/g" && git status              # Works in submodule
cd "$SOT" && git -C g status           # Also correct

# ❌ INCORRECT: Assuming g/ is part of parent repo
cd "$SOT" && git add g/tools/script.zsh  # Will add submodule ref, not file
```

---

### 2.3 Path Validation

**RULE 2.3.1: Pre-Write Validation**

All write operations **SHALL** validate target path existence:

```bash
# ✅ CORRECT
target_dir="$SOT/g/reports/system"
if [[ ! -d "$target_dir" ]]; then
  echo "ERROR: Target directory does not exist: $target_dir" >&2
  exit 1
fi
echo "data" > "$target_dir/report.md"

# ❌ FORBIDDEN: Write without validation
echo "data" > "$SOT/g/reports/system/report.md"  # May fail silently
```

**Exception:** Directory creation is permitted if documented in script header.

---

**RULE 2.3.2: Symlink Prohibition**

Scripts **MUST NOT** create symlinks within SOT directories.

```bash
# ❌ FORBIDDEN
ln -s "$SOT/g/tools/script.zsh" "$SOT/tools/script.zsh"

# ✅ CORRECT: Use wrapper script
cat > "$SOT/tools/script.zsh" <<'EOF'
#!/usr/bin/env zsh
exec "$SOT/g/tools/script.zsh" "$@"
EOF
chmod +x "$SOT/tools/script.zsh"
```

**Rationale:** Symlinks break Google Drive sync and complicate validation.

---

### 2.4 MLS Path Registry

**RULE 2.4.1: MLS Standard Paths**

The following MLS paths are **MANDATORY**:

| Component | Path | Purpose |
|-----------|------|---------|
| MLS Capture Tool | `$SOT/tools/mls_capture.zsh` | Capture lessons to MLS |
| MLS Database | `$SOT/g/knowledge/mls_lessons.jsonl` | JSONL ledger |
| MLS Index | `$SOT/g/knowledge/mls_index.json` | Search index |
| MLS Reports | `$SOT/g/reports/mls/` | Generated MLS reports |
| MLS Sessions | `$SOT/g/reports/mls/sessions/` | Session summaries |

**Enforcement:** Tools **MUST** reference these paths via variables, not literals.

```bash
# ✅ CORRECT
MLS_DB="$SOT/g/knowledge/mls_lessons.jsonl"
cat "$MLS_DB" | jq '.type == "solution"'

# ❌ FORBIDDEN
cat ~/02luka/g/knowledge/mls_lessons.jsonl | jq '...'
```

---

## 3. Tool Registry & Capabilities

### 3.1 Tool Classification

**RULE 3.1.1: Tool Capability Levels**

All tools **SHALL** be classified by capability:

| Level | Capabilities | Examples | Constraints |
|-------|--------------|----------|-------------|
| **System** | Read, Write, Execute, Git commit | CLC, GC, GG, LPE | Token limits, MLS logging required |
| **Runtime** | Read, Write, Execute (no git) | LaunchAgent workers, Node.js daemons | No SOT commits, log to runtime state |
| **Read-Only** | Read, Analyze (no write) | Codex, validators, report generators | Cannot modify SOT |
| **Validator** | Read, Exit with status | Pre-commit hooks, health checks | Must exit 0 (pass) or non-zero (fail) |

---

### 3.2 Core Tool Inventory

**RULE 3.2.1: System Tools (g/tools/)**

| Tool | Path | Purpose | Agent Access | Constraints |
|------|------|---------|--------------|-------------|
| `validate_runtime_state.zsh` | `g/tools/` | Validate LaunchAgent health | CLC, GC, runtime | Read-only, exit status |
| `backup_to_gdrive.zsh` | `g/tools/` | Rsync to Google Drive | runtime | No git commit |
| `mls_cursor_watcher.zsh` | `g/tools/` | Capture Cursor prompts | runtime | Write to MLS DB |
| `check_launchagent_scripts.sh` | `g/tools/` | Pre-commit validator | git hook | Exit 0 or 1 |
| `validate_launchagent_paths.zsh` | `g/tools/` | Enhanced path validator | CLC, runtime | Warnings + errors |
| `fix_launchagent_paths.zsh` | `g/tools/` | Automated path fixer | CLC only | Modifies plist files |
| `session_save.zsh` | `tools/` | Save CLC session to MLS | CLC | Write to MLS, git commit |
| `mls_capture.zsh` | `tools/` | Manual MLS entry capture | CLC, LPE | Append to MLS DB |

**Enforcement:** LaunchAgent plists **MUST** reference these exact paths.

---

**RULE 3.2.2: Runtime Services (g/run/)**

| Service | Path | Purpose | Startup | Constraints |
|---------|------|---------|---------|-------------|
| `health_dashboard.cjs` | `g/run/` | Generate health JSON | LaunchAgent | Read runtime, write JSON |
| `knowledge/index.cjs` | (root) | MLS/RAG hybrid search | CLC, manual | Read-only search |

**Constraint:** Runtime services **MUST NOT** commit to git.

---

**RULE 3.2.3: Work Order Agents (agents/)**

| Agent | Path | Purpose | Trigger | Constraints |
|-------|------|---------|---------|-------------|
| `json_wo_processor.zsh` | `agents/json_wo_processor/` | Process JSON work orders | LaunchAgent | Execute, log to state |
| `wo_executor.zsh` | `agents/wo_executor/` | Execute work orders | LaunchAgent | Execute, log results |
| `apply_patch_processor.zsh` | `agents/apply_patch_processor/` | Apply code patches | LaunchAgent | Modifies code, requires review |

**Safety:** Work order agents **SHALL** log all actions to MLS before execution.

---

### 3.3 Tool Selection Rules

**RULE 3.3.1: Prefer Specialized Tools Over Bash**

When multiple tools can accomplish a task, **PREFER** in this order:

1. **Specialized tool** (e.g., `validate_launchagent_paths.zsh` for path checks)
2. **Standard utility** (e.g., `jq` for JSON, `git` for version control)
3. **Bash built-ins** (e.g., `[[`, `test`, `read`)
4. **Custom script** (last resort, requires justification)

**Example:**

```bash
# ✅ CORRECT: Use specialized tool
bash "$SOT/g/tools/check_launchagent_scripts.sh"

# ❌ DISCOURAGED: Reimplement validation in bash
for plist in ~/Library/LaunchAgents/com.02luka.*.plist; do
  # ... custom validation logic ...
done
```

**Rationale:** Reduces duplication, improves maintainability, enforces standards.

---

**RULE 3.3.2: MLS Tool Usage**

For MLS operations, **MUST** use designated tools:

| Operation | Tool | Command Example |
|-----------|------|-----------------|
| Capture lesson | `mls_capture.zsh` | `bash ~/02luka/tools/mls_capture.zsh --type solution --context "..."` |
| Search MLS | `knowledge/index.cjs` | `node ~/02luka/knowledge/index.cjs --hybrid "query"` |
| View MLS entries | `mls_view.zsh` | `bash ~/02luka/tools/mls_view.zsh --today` |
| Save session | `session_save.zsh` | `bash ~/02luka/tools/session_save.zsh` |

**Constraint:** Direct writes to `mls_lessons.jsonl` **SHOULD** go through `mls_capture.zsh` to ensure proper formatting.

---

## 4. Enforcement Mechanisms

### 4.1 Pre-Commit Validation

**RULE 4.1.1: Hardcoded Path Detection**

Git pre-commit hook **MUST** reject commits with hardcoded paths:

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Check for hardcoded ~/02luka paths
if git diff --cached | grep -E '~/02luka|/Users/[^/]+/02luka'; then
  echo "❌ PROTOCOL VIOLATION: Hardcoded path detected"
  echo "Use \$SOT variable instead of hardcoded paths"
  echo ""
  echo "Replace:"
  echo "  ~/02luka/...        → \$SOT/..."
  echo "  /Users/USER/02luka/ → \$SOT/"
  exit 1
fi

# Check LaunchAgent script references
if git diff --cached --name-only | grep -q '\.plist$'; then
  if ! bash "$SOT/g/tools/check_launchagent_scripts.sh"; then
    echo "❌ LaunchAgent validation failed"
    exit 1
  fi
fi

exit 0
```

**Installation:**
```bash
cp "$SOT/g/tools/pre-commit-hook-template.sh" "$SOT/.git/hooks/pre-commit"
chmod +x "$SOT/.git/hooks/pre-commit"
```

---

**RULE 4.1.2: Symlink Detection**

Pre-commit hook **MUST** detect and reject symlink creation:

```bash
# Check for symlinks in staged files
if git diff --cached --diff-filter=A --name-only | while read file; do
  if [[ -L "$file" ]]; then
    echo "❌ PROTOCOL VIOLATION: Symlink detected: $file"
    echo "Use wrapper scripts instead of symlinks"
    exit 1
  fi
done; then
  exit 1
fi
```

---

### 4.2 Runtime Validation

**RULE 4.2.1: LaunchAgent Path Validation**

LaunchAgent scripts **SHALL** validate paths on startup:

```bash
#!/usr/bin/env zsh
# Template for LaunchAgent scripts

# Validate SOT variable
if [[ -z "$SOT" ]] || [[ ! -d "$SOT" ]]; then
  echo "ERROR: SOT not set or directory missing" >&2
  exit 1
fi

# Validate script dependencies
REQUIRED_PATHS=(
  "$SOT/g/tools/lib/common.zsh"
  "$SOT/g/knowledge/mls_lessons.jsonl"
)

for path in "${REQUIRED_PATHS[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "ERROR: Required path missing: $path" >&2
    exit 1
  fi
done

# Proceed with script logic
# ...
```

**Enforcement:** Runtime state validator **SHALL** report scripts that skip validation.

---

**RULE 4.2.2: Health Dashboard Integration**

The health dashboard **MUST** report path validation failures:

```javascript
// In health_dashboard.cjs
const pathChecks = [
  { path: process.env.SOT + '/g/knowledge/mls_lessons.jsonl', critical: true },
  { path: process.env.SOT + '/g/tools/check_launchagent_scripts.sh', critical: true },
  // ...
];

pathChecks.forEach(check => {
  if (!fs.existsSync(check.path)) {
    healthStatus.errors.push({
      component: 'path_validator',
      severity: check.critical ? 'critical' : 'warning',
      message: `Missing path: ${check.path}`
    });
  }
});
```

---

### 4.3 Periodic Audits

**RULE 4.3.1: Weekly Path Audit**

A weekly audit **SHALL** scan for protocol violations:

```bash
#!/usr/bin/env zsh
# Weekly path audit script

echo "=== Path Protocol Audit $(date) ==="

# Check for hardcoded paths in all scripts
echo "Checking for hardcoded paths..."
grep -r "~/02luka" "$SOT" --include="*.zsh" --include="*.sh" --exclude-dir=".git" > /tmp/hardcoded_paths.txt

if [[ -s /tmp/hardcoded_paths.txt ]]; then
  echo "❌ VIOLATIONS FOUND:"
  cat /tmp/hardcoded_paths.txt
else
  echo "✅ No hardcoded paths found"
fi

# Check for symlinks
echo "Checking for symlinks..."
find "$SOT" -type l ! -path "*/node_modules/*" > /tmp/symlinks.txt

if [[ -s /tmp/symlinks.txt ]]; then
  echo "❌ SYMLINKS FOUND:"
  cat /tmp/symlinks.txt
else
  echo "✅ No symlinks found"
fi

# Check LaunchAgent health
echo "Checking LaunchAgent scripts..."
bash "$SOT/g/tools/check_launchagent_scripts.sh"
```

**Trigger:** LaunchAgent scheduled weekly or manual execution by CLC/GC.

---

## 5. Common Patterns

### 5.1 Reading Configuration Files

**Pattern:** Load configuration from SOT-relative path

```bash
# ✅ CORRECT
CONFIG_FILE="$SOT/g/config/system.yaml"
if [[ -f "$CONFIG_FILE" ]]; then
  # Use yq, jq, or source depending on format
  source "$CONFIG_FILE"
else
  echo "ERROR: Config not found: $CONFIG_FILE" >&2
  exit 1
fi
```

---

### 5.2 Writing Reports

**Pattern:** Write reports to standardized locations

```bash
# ✅ CORRECT
REPORT_DIR="$SOT/g/reports/system"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/audit_$TIMESTAMP.md"

# Validate directory exists
[[ -d "$REPORT_DIR" ]] || mkdir -p "$REPORT_DIR"

# Write report
cat > "$REPORT_FILE" <<EOF
# Audit Report $TIMESTAMP
...
EOF

echo "Report saved: $REPORT_FILE"
```

---

### 5.3 MLS Integration

**Pattern:** Capture lessons via MLS tool

```bash
# ✅ CORRECT
bash "$SOT/tools/mls_capture.zsh" \
  --type solution \
  --context "Fixed path protocol violation in script X" \
  --artifact "$SCRIPT_PATH" \
  --producer "CLC"

# ❌ FORBIDDEN: Direct write to MLS database
echo '{"type":"solution",...}' >> "$SOT/g/knowledge/mls_lessons.jsonl"
```

**Rationale:** Ensures proper JSON formatting, validation, and indexing.

---

### 5.4 Cross-Submodule Operations

**Pattern:** Working across parent and g/ submodule

```bash
# ✅ CORRECT: Commit in submodule
cd "$SOT/g"
git add docs/NEW_PROTOCOL.md
git commit -m "Add new protocol"
git push origin feature/new-protocol

# Then update parent reference
cd "$SOT"
git add g  # Updates submodule reference
git commit -m "Update g/ submodule to include new protocol"

# ❌ INCORRECT: Try to commit submodule file from parent
cd "$SOT"
git add g/docs/NEW_PROTOCOL.md  # This won't work as expected
```

---

## 6. Anti-Patterns (Forbidden Practices)

### 6.1 Hardcoded Paths

```bash
# ❌ FORBIDDEN
source ~/02luka/g/tools/lib/common.zsh
cat /Users/icmini/02luka/g/knowledge/mls_lessons.jsonl

# ✅ CORRECT
source "$SOT/g/tools/lib/common.zsh"
cat "$SOT/g/knowledge/mls_lessons.jsonl"
```

---

### 6.2 Unchecked File Operations

```bash
# ❌ FORBIDDEN: Write without validation
echo "data" > "$SOT/new_dir/file.txt"

# ✅ CORRECT: Validate then write
DIR="$SOT/new_dir"
[[ -d "$DIR" ]] || mkdir -p "$DIR"
echo "data" > "$DIR/file.txt"
```

---

### 6.3 Bypassing Tool Interfaces

```bash
# ❌ FORBIDDEN: Manual MLS write
echo '{"timestamp":"2025-11-17",...}' >> "$SOT/g/knowledge/mls_lessons.jsonl"

# ✅ CORRECT: Use MLS capture tool
bash "$SOT/tools/mls_capture.zsh" --type solution --context "..."
```

---

### 6.4 Symlinks in SOT

```bash
# ❌ FORBIDDEN
ln -s "$SOT/g/tools/script.zsh" "$SOT/tools/script.zsh"

# ✅ CORRECT: Wrapper script
cat > "$SOT/tools/script.zsh" <<'EOF'
#!/usr/bin/env zsh
exec "$SOT/g/tools/script.zsh" "$@"
EOF
chmod +x "$SOT/tools/script.zsh"
```

---

## 7. Validation Gates

### 7.1 Pre-Commit Gates

**GATE 7.1.1: Hardcoded Path Check**

- **Trigger:** Every git commit
- **Check:** Scan diff for `~/02luka` or `/Users/*/02luka`
- **Pass:** No hardcoded paths found
- **Fail:** Reject commit, display correction instructions

---

**GATE 7.1.2: LaunchAgent Script Existence**

- **Trigger:** Commit modifies `*.plist` files
- **Check:** Run `check_launchagent_scripts.sh`
- **Pass:** All referenced scripts exist
- **Fail:** Reject commit, list missing scripts

---

### 7.2 Runtime Gates

**GATE 7.2.1: SOT Variable Presence**

- **Trigger:** LaunchAgent script startup
- **Check:** `[[ -n "$SOT" ]] && [[ -d "$SOT" ]]`
- **Pass:** Continue execution
- **Fail:** Exit 1, log to system logs

---

**GATE 7.2.2: Dependency Path Validation**

- **Trigger:** Script initialization
- **Check:** Validate all required paths exist
- **Pass:** Continue execution
- **Fail:** Exit 1, log missing dependencies

---

### 7.3 Periodic Gates

**GATE 7.3.1: Weekly Audit**

- **Trigger:** Weekly LaunchAgent (every Sunday 02:00)
- **Check:** Scan entire SOT for violations
- **Pass:** Generate clean report
- **Fail:** Alert via health dashboard, log to MLS

---

## 8. Tool Development Guidelines

### 8.1 Creating New Tools

**RULE 8.1.1: Tool Header Template**

All new tools **MUST** include standardized header:

```bash
#!/usr/bin/env zsh
# ======================================================================
# Tool Name: tool_name.zsh
# Purpose: Brief description
# Classification: Critical | Important | Optional
# Agent Access: CLC, GC, runtime, etc.
# Capabilities: Read | Write | Execute | Git Commit
# Dependencies:
#   - $SOT/g/tools/lib/common.zsh
#   - jq (command line JSON processor)
# MLS Integration: Yes | No
# ======================================================================

# Validate SOT
if [[ -z "$SOT" ]] || [[ ! -d "$SOT" ]]; then
  echo "ERROR: SOT not set or directory missing" >&2
  exit 1
fi

# Rest of script...
```

---

**RULE 8.1.2: Tool Registration**

After creating a tool:

1. Add entry to `LAUNCHAGENT_REGISTRY.md` (if LaunchAgent)
2. Add to this protocol's Tool Registry (Section 3.2)
3. Update health dashboard checks if critical
4. Create MLS entry documenting purpose and usage

---

### 8.2 Tool Testing

**RULE 8.2.1: Path Isolation Testing**

Test tools with alternative SOT paths:

```bash
# Test with non-standard SOT location
export SOT="/tmp/test_02luka"
mkdir -p "$SOT/g/knowledge"
bash path/to/tool.zsh

# Verify it used $SOT, not hardcoded paths
```

---

## 9. Migration & Compliance

### 9.1 Legacy Script Migration

**RULE 9.1.1: Incremental Migration**

For existing scripts with hardcoded paths:

1. **Audit:** Run `grep -r "~/02luka" script.zsh`
2. **Replace:** `~/02luka` → `$SOT`
3. **Test:** Execute script with validation enabled
4. **Commit:** Include "PATH PROTOCOL COMPLIANCE" in commit message
5. **MLS:** Log migration to learning database

---

### 9.2 Compliance Tracking

**RULE 9.2.1: Compliance Metrics**

Track compliance in health dashboard:

```json
{
  "path_protocol_compliance": {
    "total_scripts": 156,
    "compliant_scripts": 142,
    "violations": 14,
    "compliance_percentage": 91.0,
    "last_audit": "2025-11-17T02:00:00"
  }
}
```

---

## 10. Glossary

**SOT (Single Source of Truth):**
- Environment variable pointing to 02luka root directory
- Default: `$HOME/02luka`
- Used in all path references

**Hardcoded Path:**
- Literal path string (e.g., `~/02luka/file.txt`)
- Forbidden in all SOT scripts

**Path Validation:**
- Checking file/directory existence before use
- Mandatory for all write operations

**LaunchAgent:**
- macOS background service
- Defined by plist in `~/Library/LaunchAgents/`
- References scripts via absolute paths

**Submodule:**
- Git repository embedded in parent repository
- `g/` is a submodule in 02luka
- Has independent commit history

**MLS (Multi-Loop Learning System):**
- Knowledge capture and retrieval system
- Paths defined in Section 2.4

**Symlink:**
- Filesystem symbolic link
- Prohibited in SOT (breaks Google Drive sync)

---

## 11. Related Protocols

- **Context Engineering Protocol:** `CONTEXT_ENGINEERING_PROTOCOL_v3.md`
- **Multi-Agent PR Contract:** `MULTI_AGENT_PR_CONTRACT.md`
- **LaunchAgent Registry:** `LAUNCHAGENT_REGISTRY.md`
- **Codex Sandbox Mode:** `CODEX_SANDBOX_MODE.md`

---

## 12. Protocol Metadata

**Version History:**
- v1.0.0 (2025-11-17): Initial protocol creation

**Approval Status:** ✅ OFFICIAL

**Enforcement Status:** ✅ ACTIVE (pre-commit hooks enabled)

**Compliance Target:** 100% by 2025-11-24

**Review Cadence:** Quarterly or on major system changes

---

**🎯 Key Takeaway:**

**Use `$SOT`, validate paths, use specialized tools, log to MLS.**

**This protocol ensures portability, prevents breakage, and maintains audit trails.**
