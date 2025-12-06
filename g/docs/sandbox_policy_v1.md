# Sandbox Policy v1

**Date:** 2025-12-06  
**Purpose:** Define disallowed command patterns and enforcement rules

---

## Overview

The sandbox checker (`tools/codex_sandbox_check.zsh`) scans the repository for dangerous command patterns defined in `schemas/codex_disallowed_commands.yaml`.

**Goal:** Prevent accidental inclusion of dangerous commands in executable code while allowing educational examples in documentation.

---

## Disallowed Patterns

Patterns are defined in `schemas/codex_disallowed_commands.yaml`:

1. **`rm_rf`** - Recursive delete (`rm -rf`)
2. **`mv_root`** - Moving root-level paths (`mv /`)
3. **`superuser_exec`** - Privilege escalation (`sudo`)
4. **`kill_9`** - Force kill (`kill -9`)
5. **`fork_bomb`** - Bash fork bomb
6. **`chmod_world`** - World-writable permissions (`chmod 777`)
7. **`dd_dev`** - Raw disk copy (`dd if=/dev/...`)
8. **`fs_format`** - Filesystem formatting (`mkfs`)
9. **`shutdown_cmd`** - System shutdown
10. **`reboot_cmd`** - System reboot
11. **`curl_pipe_sh`** - Remote install pipelines (`curl ... | sh`)
12. **`python_os_remove`** - Inline Python os.remove payloads

---

## Rules

### Code (Executable Scripts)

**Strict enforcement:**
- Scripts in `tools/`, `agents/`, `misc/`, `scripts/` must NOT contain disallowed patterns
- If a pattern is needed, it must be:
  - Refactored to a safer alternative
  - Documented with rationale
  - Marked with comment: `# sandbox: <pattern_id> mitigated`

**Examples:**
- ❌ `rm -rf "$DIR"` → ✅ `rm -rf "${SAFE_DIR}"` with validation
- ❌ `curl ... | sh` → ✅ Download to file, then manual execution
- ❌ `sudo command` → ✅ Remove or document requirement separately

### Documentation

**Flexible enforcement:**
- Docs in `g/docs/`, `g/reports/` can contain examples but should avoid triggering regex
- Techniques:
  - Split tokens: `rm -r -f` instead of `rm -rf`
  - Use code fences with language tags
  - Explain concepts without exact command matches

**Examples:**
- ❌ `` `rm -rf /tmp` `` → ✅ `` `rm -r -f /tmp` `` or `` `rm -r` + `-f` ``
- ❌ `` `kill -9 PID` `` → ✅ `` `kill -SIGKILL PID` `` or explain signal numbers

### Test Fixtures

**Special handling:**
- Tests that intentionally include dangerous patterns for validation should:
  - Be in a dedicated test directory
  - Be marked with comments explaining the intent
  - Or be excluded from sandbox scanning

---

## Ignore Rules

The sandbox checker excludes:
- `.github/workflows/*` (for `sudo` pattern - workflows legitimately use sudo)
- `g/reports/**`, `docs/**`, `telemetry/**` (documentation/runtime files)
- `.git/**`, `node_modules/**`, `logs/**` (non-source files)

**Adding new ignore rules:**
- Must have clear rationale
- Document in this file
- Update `tools/codex_sandbox_check.zsh` if needed

---

## Workflow

1. **Local check:**
   ```bash
   zsh tools/codex_sandbox_check.zsh
   ```

2. **CI check:**
   - Runs on every PR via `.github/workflows/codex_sandbox.yml`
   - Must pass before merge

3. **Fixing violations:**
   - See `g/reports/PR_TEMPLATE_sandbox_fix_20251206.md`
   - Follow WO-20251206-SANDBOX-FIX-V1 spec

---

## Exceptions

If a command pattern is legitimately needed:

1. **Document the exception:**
   - Add comment: `# sandbox: <pattern_id> exception - <reason>`
   - Update this policy doc with rationale

2. **Consider alternatives:**
   - Can the same goal be achieved safely?
   - Can it be moved to a separate, well-documented script?

3. **Request review:**
   - Security-sensitive exceptions should be reviewed
   - Update sandbox schema if pattern needs adjustment

---

## Related Files

- Schema: `schemas/codex_disallowed_commands.yaml`
- Checker: `tools/codex_sandbox_check.zsh`
- Workflow: `.github/workflows/codex_sandbox.yml`
- WO Spec: `bridge/inbox/ENTRY/WO-20251206-SANDBOX-FIX-V1.yaml`
- PR Template: `g/reports/PR_TEMPLATE_sandbox_fix_20251206.md`

---

**Last Updated:** 2025-12-06
