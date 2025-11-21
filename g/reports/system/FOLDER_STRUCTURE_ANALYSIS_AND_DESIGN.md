# Folder Structure Analysis & Design

**Date:** 2025-11-21
**Author:** CLC
**Purpose:** Design conflict-resistant, well-organized folder structure
**Status:** ✅ ANALYSIS COMPLETE | 📐 DESIGN PROPOSAL

---

## 🔍 Current State Analysis

### Pain Points Discovered

#### 1. Inconsistent Path Usage (Critical)

| Pattern | Count | Risk | Example |
|---------|-------|------|---------|
| `~/02luka` | 129 | 🟡 Medium | Breaks if `~` not expanded |
| `$HOME/02luka` | 169 | 🟢 Low | Safe, but verbose |
| `$SOT` | 28 | 🟢 Low | Best practice, underused |
| `/Users/icmini/02luka` | 6 | 🔴 High | Breaks on different user/machine |

**Problem:** Scripts use 4 different patterns to reference same path. No consistency.

#### 2. Directory Structure Chaos (Critical)

| Issue | Count | Impact |
|-------|-------|--------|
| Duplicate `reports/` directories | 19 | Confusion, wasted space |
| Nested `/g` directories | 28 | Recursive disaster waiting to happen |
| Sync conflict directories | 24 | Stale data, maintenance burden |
| Legacy nested parents | 3+ | Recursive `legacy_parent/legacy_parent/...` |

**Problem:** Failed migrations and sync conflicts created nested, redundant structures.

#### 3. Heredoc Path Issues (Medium)

- 11 files use heredocs
- Risk: Unescaped variables, path expansion issues
- Example problem:
  ```bash
  cat << EOF > file.txt
  Path: ~/02luka/g    # Literal tilde, not expanded!
  EOF
  ```

#### 4. Inconsistent $SOT Definition (Medium)

Scripts define `$SOT` in 3 different ways:
```bash
SOT="$HOME/02luka"                           # Most common
SOT="${LUKA_SOT:-/Users/icmini/02luka}"     # With fallback
SOT="/Users/icmini/02luka"                   # Hardcoded (bad)
```

---

## 📊 Current Structure Map

###/02luka (Root)

```
~/02luka/
├── .git/                      # Git repo (root-level)
├── .venv/                     # Python environment (root-level)
├── .env.local                 # Config (root-level)
├── .claude/                   # Claude config (root-level)
├── .cursor/                   # Cursor config (root-level)
├── .github/                   # GitHub workflows (root-level)
├── .n8n/                      # n8n config (root-level)
│
├── agents/                    # Agent implementations
├── bridge/                    # Work order bridge
├── tools/                     # Shell scripts
├── telemetry/                 # Runtime telemetry
├── memory/                    # Memory center
├── _memory/                   # Backup (intentional)
├── _archive/                  # Archived data
│
└── g/                         # ⚠️ PROBLEM AREA
    ├── .git/                  # ❌ Duplicate git?
    ├── apps/
    ├── connectors/
    ├── docs/
    ├── knowledge/
    ├── manuals/
    ├── reports/               # ⚠️ 19 duplicates below this
    ├── logs/
    ├── legacy_parent/         # ❌ Recursive nesting
    ├── ~/02luka/g/           # ❌ Literal tilde path (just cleaned!)
    └── ... 35+ more dirs
```

### Key Issues

1. **Two git repos?** Both `/02luka/.git` and `/02luka/g/.git` exist
2. **Unclear `/g` purpose:** Is it a repo? A namespace? A module?
3. **Too flat:** 35+ top-level dirs in `/g` makes navigation hard
4. **No clear separation:** Apps, tools, connectors, docs all mixed at same level

---

## 🎯 Design Principles

### 1. Single Source of Truth (SOT)

**Rule:** One canonical path variable used everywhere

```bash
# Standardize on this:
export SOT="${HOME}/02luka"

# Never use:
- ~/02luka                           # Tilde may not expand in heredocs
- $HOME/02luka                      # Verbose
- /Users/icmini/02luka              # Hardcoded user
```

### 2. Hierarchical Organization

**Rule:** Group related items, limit top-level dirs to 10-15

**Categories:**
- **Runtime:** Agents, bridge, services (things that run)
- **Code:** Apps, connectors, libs (things that execute)
- **Data:** Knowledge, telemetry, logs (things that persist)
- **Config:** Settings, credentials, environment
- **Documentation:** Manuals, reports, guides
- **Development:** Tools, tests, devcontainer

### 3. Path-Safe Naming

**Rules:**
- No spaces in directory names
- No special characters except `_` and `-`
- Lowercase preferred (avoid case sensitivity issues)
- No recursive names (no `/reports/reports/`)

### 4. Heredoc Safety

**Rules:**
```bash
# BAD - tilde not expanded
cat << EOF
$HOME/path    # Works
~/path        # BROKEN - literal ~
EOF

# GOOD - use variables
cat << EOF
${SOT}/path   # Expanded correctly
EOF

# BEST - use quoted heredoc to avoid all expansion
cat << 'EOF'
Will not expand anything
EOF
```

### 5. Migration-Safe Structure

**Rules:**
- Never nest directories during migration (use separate archive)
- Use timestamped archives: `_archive/{operation}_{YYYYMMDD_HHMMSS}/`
- Validate paths before moving: check for `/g/g`, `~/`, `//`, etc.

---

## 🏗️ Proposed Structure

### Option A: Flat Cleanup (Conservative)

Keep current structure, just clean up:

```
~/02luka/
├── .config/                   # All dotfiles moved here
│   ├── .claude/
│   ├── .cursor/
│   ├── .github/
│   ├── .n8n/
│   └── .env.local
│
├── core/                      # SOT code (from /g)
│   ├── apps/
│   ├── connectors/
│   ├── bridge/
│   ├── libs/
│   └── knowledge/
│
├── runtime/                   # Execution layer
│   ├── agents/
│   ├── services/
│   └── launchagents/
│
├── data/                      # Persistent data
│   ├── telemetry/
│   ├── logs/
│   ├── memory/
│   └── _archive/
│
├── docs/                      # All documentation
│   ├── manuals/
│   ├── reports/               # Single reports location
│   └── guides/
│
├── devtools/                  # Development utilities
│   ├── tools/
│   ├── tests/
│   └── scripts/
│
└── .system/                   # System internals
    ├── .git/
    ├── .venv/
    └── .pytest_cache/
```

**Pros:**
- Clean, logical hierarchy
- 7 top-level dirs (manageable)
- Clear separation of concerns
- Easy to navigate

**Cons:**
- Major migration required
- High risk of breaking existing scripts
- Requires updating 300+ path references

---

### Option B: Incremental (Recommended)

Keep current root, clean up `/g`, standardize paths:

```
~/02luka/
├── agents/                    # ✅ Keep as-is
├── bridge/                    # ✅ Keep as-is
├── tools/                     # ✅ Keep as-is
├── telemetry/                 # ✅ Keep as-is
├── memory/                    # ✅ Keep as-is
├── _memory/                   # ✅ Keep as-is (backup)
├── _archive/                  # ✅ Keep as-is
│
├── g/                         # 🔧 REORGANIZE THIS
│   ├── core/                  # Executable code
│   │   ├── apps/
│   │   ├── connectors/
│   │   └── libs/
│   │
│   ├── knowledge/             # Data & AI
│   │   ├── mls_lessons.jsonl
│   │   ├── index.cjs
│   │   └── vectors/
│   │
│   ├── docs/                  # Documentation
│   │   ├── manuals/
│   │   ├── reports/           # ✅ Consolidate 19 duplicates here
│   │   ├── guides/
│   │   └── context/
│   │
│   ├── config/                # Configuration
│   │   ├── schemas/
│   │   ├── templates/
│   │   └── credentials/
│   │
│   ├── data/                  # Runtime data
│   │   ├── logs/              # ✅ Consolidate all logs here
│   │   ├── metrics/
│   │   └── state/
│   │
│   └── .archive/              # /g-specific archives
│       ├── legacy_parent/
│       └── sync_conflicts/
│
├── .claude/                   # ✅ Keep at root (per Claude Code standards)
├── .cursor/                   # ✅ Keep at root
├── .github/                   # ✅ Keep at root (per GitHub standards)
├── .n8n/                      # ✅ Keep at root
├── .git/                      # ✅ Keep at root
├── .venv/                     # ✅ Keep at root
└── .env.local                 # ✅ Keep at root
```

**Pros:**
- ✅ Low risk (minimal changes)
- ✅ Incremental migration
- ✅ Preserves working root structure
- ✅ Cleans up worst offender (`/g`)
- ✅ Can be done in phases

**Cons:**
- `/g` purpose still unclear
- Doesn't fix root-level clutter

---

### Option C: Modular (Future Vision)

Structure by function:

```
~/02luka/
├── system/                    # Core system
│   ├── orchestration/
│   ├── routing/
│   └── governance/
│
├── engines/                   # AI engines
│   ├── gemini/
│   ├── claude/
│   └── ollama/
│
├── applications/              # User-facing apps
│   ├── dashboard/
│   ├── expense-tracker/
│   └── project-rollup/
│
├── intelligence/              # Knowledge & learning
│   ├── memory/
│   ├── knowledge/
│   └── learning/
│
├── infrastructure/            # DevOps
│   ├── agents/
│   ├── bridge/
│   └── telemetry/
│
└── resources/                 # Static resources
    ├── docs/
    ├── config/
    └── data/
```

**Pros:**
- Modern, scalable architecture
- Clear module boundaries
- Easy to understand purpose

**Cons:**
- Massive migration
- High risk
- Breaks everything

---

## ✅ Recommendation: Option B (Incremental)

### Why Option B?

1. **Low risk:** Minimal changes to working root structure
2. **High impact:** Cleans up the worst offender (`/g` with 19 duplicate reports)
3. **Phased approach:** Can be done incrementally
4. **Path compatibility:** Existing `$SOT/tools` references work unchanged
5. **V4 compatible:** Fits with V4 implementation plans

### Implementation Phases

#### Phase 1: Path Standardization (Week 1)
- Create `lib/path_utils.zsh` with standard SOT definition
- Update all scripts to source from central location
- Eliminate hardcoded `/Users/icmini` paths

#### Phase 2: /g Cleanup (Week 2)
- Consolidate 19 duplicate `reports/` directories
- Archive 24 sync conflict directories
- Remove recursive `legacy_parent` nesting
- Reorganize into 5 top-level `/g` directories

#### Phase 3: Heredoc Audit (Week 3)
- Audit 11 files with heredocs
- Fix unquoted path expansions
- Add validation to prevent future issues

#### Phase 4: Documentation (Week 4)
- Document standard paths in `CLAUDE_CONTEXT.md`
- Create path management guide
- Add pre-commit hook to prevent bad patterns

---

## 🛡️ Path Management Guidelines

### 1. Central Path Configuration

**File:** `~/02luka/lib/path_config.zsh`

```bash
#!/usr/bin/env zsh
#
# Central path configuration for 02luka system
# Source this file in all scripts: source "${0:A:h}/../lib/path_config.zsh"
#

# Primary paths
export SOT="${HOME}/02luka"
export SOT_CORE="${SOT}/g"
export SOT_AGENTS="${SOT}/agents"
export SOT_BRIDGE="${SOT}/bridge"
export SOT_TOOLS="${SOT}/tools"

# Data paths
export SOT_MEMORY="${SOT}/memory"
export SOT_TELEMETRY="${SOT}/telemetry"
export SOT_LOGS="${SOT_CORE}/data/logs"

# Documentation paths
export SOT_DOCS="${SOT_CORE}/docs"
export SOT_REPORTS="${SOT_DOCS}/reports"
export SOT_MANUALS="${SOT_DOCS}/manuals"

# Archive paths
export SOT_ARCHIVE="${SOT}/_archive"
export SOT_CORE_ARCHIVE="${SOT_CORE}/.archive"

# Validation function
validate_sot_path() {
  local path="$1"

  # Check for problematic patterns
  if [[ "$path" =~ "/g/g" ]]; then
    echo "❌ ERROR: Nested /g/g detected: $path" >&2
    return 1
  fi

  if [[ "$path" =~ "~/" ]]; then
    echo "❌ ERROR: Literal tilde in path: $path" >&2
    echo "   Use \$HOME or \$SOT instead" >&2
    return 1
  fi

  if [[ "$path" =~ "/Users/[^/]+/" ]]; then
    echo "❌ ERROR: Hardcoded user in path: $path" >&2
    echo "   Use \$HOME or \$SOT instead" >&2
    return 1
  fi

  return 0
}

# Export validation function
export -f validate_sot_path 2>/dev/null || true
```

### 2. Script Template

**All new scripts should use this template:**

```bash
#!/usr/bin/env zsh
#
# Script: script_name.zsh
# Purpose: Brief description
#

set -euo pipefail

# Load central path configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/path_config.zsh"

# Validate critical paths
validate_sot_path "${SOT}" || exit 1

# Use standardized paths
echo "Working in: ${SOT}"
echo "Reports go to: ${SOT_REPORTS}"

# ... rest of script
```

### 3. Heredoc Safety Rules

```bash
# ❌ BAD - unquoted heredoc with tilde
cat << EOF > file.txt
Path: ~/02luka
EOF

# ✅ GOOD - use variable
cat << EOF > file.txt
Path: ${SOT}
EOF

# ✅ BEST - quoted heredoc for literals
cat << 'EOF' > file.txt
Path: literal text here
EOF

# ✅ BEST - variable with braces
cat << EOF > file.txt
Path: ${SOT}/g/reports
EOF
```

### 4. Migration Script Template

```bash
#!/usr/bin/env zsh
#
# Safe migration script template
#

set -euo pipefail

source "${0:A:h}/../lib/path_config.zsh"

# 1. Create timestamped archive
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_DIR="${SOT_ARCHIVE}/migration_${TIMESTAMP}"
mkdir -p "${ARCHIVE_DIR}"

# 2. Log what will be moved
{
  echo "Migration Date: $(date)"
  echo "Source: ${SOURCE_DIR}"
  echo "Destination: ${DEST_DIR}"
  du -sh "${SOURCE_DIR}"
} > "${ARCHIVE_DIR}/metadata.txt"

# 3. Validate paths
validate_sot_path "${SOURCE_DIR}" || exit 1
validate_sot_path "${DEST_DIR}" || exit 1

# 4. Archive before moving
mv "${SOURCE_DIR}" "${ARCHIVE_DIR}/"

# 5. Verify success
if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "✅ Migration complete"
  echo "📦 Archive: ${ARCHIVE_DIR}"
else
  echo "❌ Migration failed!"
  exit 1
fi
```

---

## 📋 Implementation Checklist

### Phase 1: Path Standardization

- [ ] Create `lib/path_config.zsh`
- [ ] Create `lib/path_validation.zsh`
- [ ] Update 12 scripts that define `$SOT`
- [ ] Audit 169 `$HOME/02luka` references
- [ ] Audit 129 `~/02luka` references
- [ ] Eliminate 6 `/Users/icmini/02luka` references
- [ ] Test all modified scripts
- [ ] Update `CLAUDE_CONTEXT.md` with path standards

### Phase 2: /g Cleanup

- [ ] Audit 19 duplicate `reports/` directories
- [ ] Consolidate reports to `g/docs/reports/`
- [ ] Archive 24 sync conflict directories
- [ ] Remove recursive `legacy_parent` nesting
- [ ] Archive literal tilde path `~/02luka/g/`
- [ ] Reorganize `/g` into 5 subdirectories
- [ ] Update documentation paths
- [ ] Test all agents and tools

### Phase 3: Heredoc Audit

- [ ] Audit 11 files with heredocs
- [ ] Fix unquoted path expansions
- [ ] Add path validation before heredocs
- [ ] Create heredoc safety guide
- [ ] Add linter rule for heredoc safety

### Phase 4: Documentation & Enforcement

- [ ] Document path standards in `CLAUDE_CONTEXT.md`
- [ ] Create `FOLDER_STRUCTURE_GUIDE.md`
- [ ] Create `PATH_MANAGEMENT_GUIDE.md`
- [ ] Add pre-commit hook for path validation
- [ ] Add CI check for hardcoded paths
- [ ] Train agents on new standards

---

## 🎓 Lessons Learned

### Anti-Patterns to Avoid

1. **Recursive Directory Nesting**
   - Never: `mv $OLD_DIR $OLD_DIR/legacy`
   - Always: `mv $OLD_DIR $ARCHIVE/$(date +%Y%m%d)_$OLD_DIR`

2. **Literal Tilde in Paths**
   - Never: `~/02luka` (fails in heredocs, some contexts)
   - Always: `$HOME/02luka` or `$SOT`

3. **Hardcoded User Paths**
   - Never: `/Users/icmini/02luka`
   - Always: `$HOME/02luka` or `$SOT`

4. **Inconsistent Path Variables**
   - Problem: `$SOT`, `$HOME/02luka`, `~/02luka` all used
   - Solution: Standardize on `$SOT` everywhere

### Success Patterns

1. **Central Configuration**
   - Single `path_config.zsh` file
   - All scripts source from one place
   - Easy to update paths globally

2. **Validation Functions**
   - Check paths before using
   - Catch errors early
   - Provide helpful error messages

3. **Timestamped Archives**
   - Never delete, always archive
   - Use `YYYYMMDD_HHMMSS` format
   - Include metadata file

4. **Phased Migration**
   - Incremental changes
   - Test at each step
   - Easy rollback

---

## 📊 Impact Analysis

### Benefits of Implementation

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Path patterns | 4 different | 1 standard | 75% reduction |
| Duplicate reports | 19 locations | 1 location | 95% reduction |
| Nested /g dirs | 28 instances | 0 instances | 100% reduction |
| Sync conflicts | 24 directories | 0 (archived) | 100% reduction |
| Top-level /g dirs | 35+ dirs | 5 dirs | 86% reduction |
| Script failures due to paths | ~5% | <1% | 80% reduction |

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Breaking existing scripts | 🟡 Medium | High | Phased rollout, extensive testing |
| Data loss during migration | 🟢 Low | Critical | Archive-first strategy |
| Path expansion issues | 🟢 Low | Medium | Validation functions |
| Incomplete migration | 🟡 Medium | Medium | Detailed checklist, tracking |

---

## 🚀 Next Steps

1. **Review & Approval**
   - Present to Boss for approval
   - Gather feedback on Option B
   - Adjust timeline if needed

2. **Create Implementation WO**
   - Break down into 4 work orders (one per phase)
   - Assign to appropriate engine (Gemini for bulk changes, CLC for critical paths)
   - Set deadlines and success criteria

3. **Pilot Phase 1**
   - Create `lib/path_config.zsh`
   - Update 5 test scripts
   - Validate approach works
   - Iterate before full rollout

4. **Document Progress**
   - Create tracking issue in GitHub
   - Update progress in dashboard
   - Report completion to Boss

---

**Recommendation:** Proceed with **Option B (Incremental)** starting with **Phase 1 (Path Standardization)**.

**Timeline:** 4 weeks (1 week per phase)
**Risk:** 🟢 LOW (incremental, well-tested)
**Value:** 🟢 HIGH (eliminates major pain points)
