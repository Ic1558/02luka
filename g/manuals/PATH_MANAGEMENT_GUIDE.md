# Path Management Guide

**Version:** 1.0.0
**Last Updated:** 2025-11-21
**Status:** 📐 DESIGN PHASE

---

## 🎯 Purpose

This guide establishes standards for path management across the 02luka system to prevent:
- Hardcoded user paths (`/Users/icmini/...`)
- Literal tilde expansions (`~/...` in wrong contexts)
- Recursive directory nesting (`/g/g/g/...`)
- Path expansion failures in heredocs

---

## 📚 Quick Reference

### Standard Path Variable

**Always use:** `$SOT`

```bash
# ✅ CORRECT
source "${SOT}/lib/path_config.zsh"
report_file="${SOT_REPORTS}/my_report.md"

# ❌ WRONG
source "~/02luka/lib/path_config.zsh"           # Tilde fails in some contexts
report_file="/Users/icmini/02luka/g/reports/"  # Hardcoded user
```

### Loading Path Configuration

**Every script must:**

```bash
#!/usr/bin/env zsh
set -euo pipefail

# Load central path config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/path_config.zsh"

# Validate paths
validate_sot_path "${SOT}" || exit 1
```

---

## 🔧 Path Variables Reference

### Primary Paths

| Variable | Path | Purpose |
|----------|------|---------|
| `$SOT` | `~/02luka` | Source of Truth (root) |
| `$SOT_CORE` | `~/02luka/g` | Core codebase |

### Runtime Paths

| Variable | Path | Purpose |
|----------|------|---------|
| `$SOT_AGENTS` | `~/02luka/agents` | Agent implementations |
| `$SOT_BRIDGE` | `~/02luka/bridge` | Work order bridge |
| `$SOT_TOOLS` | `~/02luka/tools` | Shell utilities |

### Data Paths

| Variable | Path | Purpose |
|----------|------|---------|
| `$SOT_MEMORY` | `~/02luka/memory` | Memory center |
| `$SOT_TELEMETRY` | `~/02luka/telemetry` | Runtime telemetry |
| `$SOT_LOGS` | `~/02luka/g/data/logs` | System logs |
| `$SOT_KNOWLEDGE` | `~/02luka/g/knowledge` | Knowledge base |
| `$SOT_MLS` | `~/02luka/g/knowledge/mls_lessons.jsonl` | MLS database |

### Documentation Paths

| Variable | Path | Purpose |
|----------|------|---------|
| `$SOT_DOCS` | `~/02luka/g/docs` | Documentation root |
| `$SOT_REPORTS` | `~/02luka/g/docs/reports` | System reports |
| `$SOT_MANUALS` | `~/02luka/g/docs/manuals` | User manuals |
| `$SOT_GUIDES` | `~/02luka/g/docs/guides` | Developer guides |

### Configuration Paths

| Variable | Path | Purpose |
|----------|------|---------|
| `$SOT_CONFIG` | `~/02luka/g/config` | Configuration files |
| `$SOT_SCHEMAS` | `~/02luka/g/config/schemas` | YAML/JSON schemas |
| `$SOT_TEMPLATES` | `~/02luka/g/config/templates` | File templates |

### Archive Paths

| Variable | Path | Purpose |
|----------|------|---------|
| `$SOT_ARCHIVE` | `~/02luka/_archive` | System archives |
| `$SOT_CORE_ARCHIVE` | `~/02luka/g/.archive` | Core archives |

### Work Order Paths

| Variable | Path | Purpose |
|----------|------|---------|
| `$SOT_BRIDGE_INBOX` | `~/02luka/bridge/inbox` | WO inbox |
| `$SOT_BRIDGE_OUTBOX` | `~/02luka/bridge/outbox` | WO outbox |
| `$SOT_BRIDGE_GEMINI_INBOX` | `~/02luka/bridge/inbox/GEMINI` | Gemini inbox |
| `$SOT_BRIDGE_GEMINI_OUTBOX` | `~/02luka/bridge/outbox/GEMINI` | Gemini outbox |

---

## ⚠️ Common Mistakes

### 1. Literal Tilde in Heredocs

**Problem:**
```bash
# ❌ WRONG - tilde not expanded in heredoc
cat << EOF > file.md
Path: ~/02luka/g
EOF
# Result: Literal "~/02luka/g" in file
```

**Solution:**
```bash
# ✅ CORRECT - use variable
cat << EOF > file.md
Path: ${SOT}/g
EOF
# Result: "/Users/icmini/02luka/g" in file
```

### 2. Hardcoded User Paths

**Problem:**
```bash
# ❌ WRONG - breaks on different user/machine
cp file.txt /Users/icmini/02luka/g/docs/
```

**Solution:**
```bash
# ✅ CORRECT - works for any user
cp file.txt "${SOT_DOCS}/"
```

### 3. Inconsistent Path Usage

**Problem:**
```bash
# ❌ WRONG - 3 different ways to reference same path
source ~/02luka/lib/path_config.zsh
cd $HOME/02luka/g
log_file="/Users/icmini/02luka/g/logs/app.log"
```

**Solution:**
```bash
# ✅ CORRECT - consistent use of variables
source "${SOT}/lib/path_config.zsh"
cd "${SOT_CORE}"
log_file="${SOT_LOGS}/app.log"
```

### 4. Recursive Nesting

**Problem:**
```bash
# ❌ WRONG - creates /g/g/g/...
while [[ -d "$old_dir" ]]; do
  mv "$old_dir" "$old_dir/legacy"
done
```

**Solution:**
```bash
# ✅ CORRECT - use separate archive
archive_dir=$(create_archive "migration")
mv "$old_dir" "${archive_dir}/"
```

---

## 🛠️ Helper Functions

### validate_sot_path()

Check path for anti-patterns:

```bash
validate_sot_path "/Users/icmini/02luka/g"
# Output: ❌ ERROR: Hardcoded user path detected

validate_sot_path "${SOT}/g"
# Output: (none - path is valid)
```

**Checks for:**
- Nested `/g/g` patterns
- Literal tildes `~/`
- Hardcoded user paths `/Users/username/`
- Double slashes `//`
- Multiple `/g/` occurrences

### create_archive()

Create timestamped archive directory:

```bash
archive_dir=$(create_archive "cleanup")
# Returns: /Users/icmini/02luka/_archive/cleanup_20251121_050000

mv "${old_data}" "${archive_dir}/"
```

### log_migration()

Log migration metadata:

```bash
archive_dir=$(create_archive "migration")
log_migration "${archive_dir}" "${source}" "${destination}"
# Creates: ${archive_dir}/metadata/migration_log.txt
```

---

## 📝 Script Template

Use this template for all new scripts:

```bash
#!/usr/bin/env zsh
#
# Script: my_script.zsh
# Purpose: Brief description
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════
# Load Central Configuration
# ═══════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/path_config.zsh"

# Validate SOT path
validate_sot_path "${SOT}" || exit 1

# ═══════════════════════════════════════════════════════════
# Main Logic
# ═══════════════════════════════════════════════════════════

main() {
  echo "Working in: ${SOT}"

  # Use standardized paths
  local report_file="${SOT_REPORTS}/my_report_$(date +%Y%m%d).md"

  # Safe heredoc usage
  cat << 'EOF' > "${report_file}"
# My Report

**Date:** $(date)
**Path:** ${SOT}
EOF
}

main "$@"
```

**Copy from:** `~/02luka/lib/script_template.zsh`

---

## 🔐 Heredoc Safety Rules

### Rule 1: Quote Heredoc Delimiter for Literals

```bash
# ❌ WRONG - expands variables
cat << EOF
$HOME will expand
EOF

# ✅ CORRECT - no expansion
cat << 'EOF'
$HOME will NOT expand
EOF
```

### Rule 2: Use Variables for Dynamic Content

```bash
# ❌ WRONG - tilde won't expand
cat << EOF
Path: ~/02luka
EOF

# ✅ CORRECT - variable expands
cat << EOF
Path: ${SOT}
EOF
```

### Rule 3: Escape Special Characters

```bash
# For code that includes special chars
cat << 'EOF' > script.sh
#!/bin/bash
echo "Special chars: $, \`, \\ all work"
EOF
```

---

## 🔄 Migration Best Practices

### Always Use Archive-First Strategy

```bash
#!/usr/bin/env zsh
set -euo pipefail

source "${0:A:h}/../lib/path_config.zsh"

# 1. Create timestamped archive
archive_dir=$(create_archive "cleanup")

# 2. Log metadata
log_migration "${archive_dir}" "${source}" "${dest}"

# 3. Validate paths
validate_sot_path "${source}" || exit 1
validate_sot_path "${dest}" || exit 1

# 4. Archive (never delete!)
mv "${source}" "${archive_dir}/"

# 5. Verify
if [[ ! -d "${source}" ]]; then
  echo "✅ Migration complete"
  echo "📦 Archive: ${archive_dir}"
else
  echo "❌ Migration failed"
  exit 1
fi
```

---

## ✅ Validation Checklist

Before committing scripts, verify:

- [ ] Script sources `path_config.zsh`
- [ ] Uses `$SOT` variables (not `~/02luka`)
- [ ] No hardcoded `/Users/username/` paths
- [ ] Heredocs use quotes when needed
- [ ] Calls `validate_sot_path()` for critical paths
- [ ] Migration scripts use `create_archive()`
- [ ] No recursive directory operations

---

## 🎓 Examples

### Example 1: Creating a Report

```bash
#!/usr/bin/env zsh
set -euo pipefail

source "${0:A:h}/../lib/path_config.zsh"
validate_sot_path "${SOT}" || exit 1

report_file="${SOT_REPORTS}/system/health_check_$(date +%Y%m%d).md"

cat << EOF > "${report_file}"
# System Health Check

**Date:** $(date)
**SOT:** ${SOT}

## Status

All systems operational.
EOF

echo "✅ Report created: ${report_file}"
```

### Example 2: Safe Migration

```bash
#!/usr/bin/env zsh
set -euo pipefail

source "${0:A:h}/../lib/path_config.zsh"

old_dir="${SOT_CORE}/old_reports"
new_dir="${SOT_REPORTS}/archived"

# Create archive
archive_dir=$(create_archive "report_migration")
log_migration "${archive_dir}" "${old_dir}" "${new_dir}"

# Validate
validate_sot_path "${old_dir}" || exit 1
validate_sot_path "${new_dir}" || exit 1

# Migrate
mkdir -p "${new_dir}"
mv "${old_dir}"/* "${new_dir}/"
rmdir "${old_dir}"

echo "✅ Migration complete"
```

### Example 3: Heredoc with Variables

```bash
#!/usr/bin/env zsh
set -euo pipefail

source "${0:A:h}/../lib/path_config.zsh"

config_file="${SOT_CONFIG}/app.conf"

cat << EOF > "${config_file}"
# Application Configuration
# Generated: $(date)

[paths]
sot = ${SOT}
reports = ${SOT_REPORTS}
logs = ${SOT_LOGS}

[runtime]
memory = ${SOT_MEMORY}
telemetry = ${SOT_TELEMETRY}
EOF

echo "✅ Config created: ${config_file}"
```

---

## 🚨 Pre-Commit Validation

Add this to `.git/hooks/pre-commit`:

```bash
#!/bin/bash

echo "Validating paths in staged files..."

# Check for hardcoded user paths
if git diff --cached --name-only | xargs grep -l "/Users/icmini" 2>/dev/null; then
  echo "❌ ERROR: Hardcoded user path detected"
  echo "   Use \$SOT or \$HOME instead"
  exit 1
fi

# Check for literal tildes in scripts
if git diff --cached --name-only | grep '\.zsh$\|\.sh$' | xargs grep -l "~/02luka" 2>/dev/null; then
  echo "⚠️  WARNING: Literal tilde (~) found in script"
  echo "   Consider using \$SOT instead"
fi

echo "✅ Path validation passed"
```

---

## 📚 Related Documentation

- **Full Analysis:** `g/reports/system/FOLDER_STRUCTURE_ANALYSIS_AND_DESIGN.md`
- **Script Template:** `lib/script_template.zsh`
- **Path Config:** `lib/path_config.zsh`
- **CLAUDE_CONTEXT:** `g/CLAUDE_CONTEXT.md`

---

## 🔄 Version History

- **v1.0.0 (2025-11-21):** Initial release with comprehensive path standards

---

**Questions?** Reference the full analysis document or ask CLC for clarification.
