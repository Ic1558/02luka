# Codex Verification Checklist
**Date:** 2025-11-14  
**Purpose:** Comprehensive verification criteria for Codex changes before enabling GitHub sync

---

## Verification Status

- [ ] **Phase 1: SOT Protection** - Not Started
- [ ] **Phase 2: Safety Checks** - Not Started
- [ ] **Phase 3: Conflict Detection** - Not Started
- [ ] **Phase 4: Code Quality** - Not Started

---

## Phase 1: SOT Protection

### Core SOT Files
- [ ] No changes to `core/` directory
- [ ] No changes to `CLC/` directory
- [ ] No changes to `docs/` directory (except approved documentation)
- [ ] No changes to `02luka.md` (master SOT file)

### Governance Files
- [ ] No changes to `.cursorrules`
- [ ] No changes to `memory/cls/ALLOWLIST.paths`
- [ ] No changes to `.claude/context-map.json`

### Critical Configs
- [ ] No changes to LaunchAgent plists in `Library/LaunchAgents/` (except approved)
- [ ] No changes to critical tools in `tools/` (except approved)
- [ ] No changes to workflow files in `.github/workflows/` (except approved fixes)

**Verification Method:**
```bash
# Check for SOT touches in Codex commits
git log --oneline --all --grep="codex\|Codex\|CODEX" --name-only | grep -E "^core/|^CLC/|^docs/|^02luka\.md$|^\.cursorrules$|^memory/cls/ALLOWLIST\.paths$|^\.claude/context-map\.json$"
```

**Result:** [To be filled by automated analysis]

---

## Phase 2: Safety Checks

### Secrets & Credentials
- [ ] No hardcoded secrets/API keys
- [ ] No credentials in code
- [ ] No passwords in configuration files
- [ ] No tokens exposed in logs

**Verification Method:**
```bash
# Scan for common secret patterns
grep -r -i "password\|secret\|key\|token\|api_key" --include="*.zsh" --include="*.sh" --include="*.py" --include="*.js" --include="*.json" | grep -v ".git" | grep -v "node_modules"
```

**Result:** [To be filled by automated analysis]

### Destructive Operations
- [ ] No destructive mass-delete commands without safety checks
- [ ] No `git reset --hard` without backup
- [ ] No destructive file operations
- [ ] No irreversible deletions

**Verification Method:**
```bash
# Use the sandbox checker to surface destructive patterns
tools/codex_sandbox_check.zsh --list-only
```

**Result:** [To be filled by automated analysis]

### LaunchAgents & Services
- [ ] No changes to LaunchAgents without backup
- [ ] No changes to critical services without tests
- [ ] No changes to Redis/other infrastructure without verification

**Verification Method:**
```bash
# Check LaunchAgent changes
git log --all --grep="codex\|Codex\|CODEX" --name-only | grep -E "\.plist$|LaunchAgent"
```

**Result:** [To be filled by automated analysis]

### Critical Tools
- [ ] No changes to critical tools without tests
- [ ] No breaking changes to existing functionality
- [ ] No removal of essential tools

**Verification Method:**
```bash
# Check tools/ directory changes
git log --all --grep="codex\|Codex\|CODEX" --name-only | grep "^tools/"
```

**Result:** [To be filled by automated analysis]

---

## Phase 3: Conflict Detection

### Merge Conflicts
- [ ] No merge conflicts with current main branch
- [ ] No overwriting of recent CLS/CLC work
- [ ] No breaking changes to active workflows

**Verification Method:**
```bash
# Check for conflicts
git merge-tree $(git merge-base origin/main HEAD) origin/main HEAD | grep -A 5 "^+<<<<<<<"
```

**Result:** [To be filled by automated analysis]

### Overwriting Recent Work
- [ ] No files modified by CLS/CLC in last 7 days were changed by Codex
- [ ] No recent recovery work was overwritten
- [ ] No active WO files were modified

**Verification Method:**
```bash
# Check for overlapping changes
git log --since="7 days ago" --name-only --pretty=format: | sort | uniq > /tmp/recent_files.txt
git log --all --grep="codex\|Codex\|CODEX" --name-only --pretty=format: | sort | uniq > /tmp/codex_files.txt
comm -12 /tmp/recent_files.txt /tmp/codex_files.txt
```

**Result:** [To be filled by automated analysis]

### Breaking Changes
- [ ] No breaking changes to active workflows
- [ ] No breaking changes to API endpoints
- [ ] No breaking changes to CLI tools

**Verification Method:**
- Review workflow files for breaking changes
- Review API endpoints for signature changes
- Review CLI tools for parameter changes

**Result:** [To be filled by manual review]

---

## Phase 4: Code Quality

### Coding Standards
- [ ] Follows 02luka coding standards
- [ ] Uses proper error handling
- [ ] Includes appropriate logging
- [ ] Has proper documentation

**Verification Method:**
- Code review of changed files
- Check for error handling patterns
- Check for logging statements
- Check for documentation

**Result:** [To be filled by manual review]

### Error Handling
- [ ] Proper error handling in scripts
- [ ] Error messages are clear and actionable
- [ ] Failures are logged appropriately
- [ ] No silent failures

**Verification Method:**
```bash
# Check for error handling patterns
git log --all --grep="codex\|Codex\|CODEX" -p | grep -E "set -e|trap|error|fail" | head -20
```

**Result:** [To be filled by automated analysis]

### Logging
- [ ] Appropriate logging statements
- [ ] Log levels are appropriate
- [ ] Sensitive information not logged
- [ ] Logs are useful for debugging

**Verification Method:**
- Review logging statements in changed files
- Check for sensitive information in logs

**Result:** [To be filled by manual review]

---

## Summary

### Overall Status
- **SOT Protection:** [ ] Pass [ ] Fail [ ] Needs Review
- **Safety Checks:** [ ] Pass [ ] Fail [ ] Needs Review
- **Conflict Detection:** [ ] Pass [ ] Fail [ ] Needs Review
- **Code Quality:** [ ] Pass [ ] Fail [ ] Needs Review

### Critical Issues Found
[List any critical issues that block sync]

### Warnings
[List any warnings that need attention]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## Next Steps

1. Run automated analysis script (`tools/codex_verification_analyzer.zsh`)
2. Fill in verification results
3. Manual review of flagged items
4. Make decision: Approve all / Approve partial / Reject all

---

**Checklist Created:** 2025-11-14  
**Status:** Ready for automated analysis

<!-- Sanitized for Codex Sandbox Mode (2025-11) -->
