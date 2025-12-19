# ATG Command Policy

**Status**: ACTIVE
**Purpose**: Eliminate "Accept" button friction by aligning Agent behavior with Antigravity UI Allow List.

## The Rule: Canonical Syntax
Antigravity UI uses a simple prefix matcher. It does not parse shell logic.
Therefore, "Safe" logic inside a script != "Safe" to UI if the command string looks complex.

### ✅ Allowed (Canonical)
Direct execution of tools using absolute or repo-relative paths.

```zsh
zsh tools/save.sh
zsh tools/guard_runtime.zsh --cmd "ls -la"
python3 tools/script.py
```

### ❌ Forbidden (Triggers Accept)
Compound commands, chaining, or complex inline logic.

```zsh
cd ~/02luka && zsh tools/save.sh   # ⛔ Compound (&&)
ls -la; echo "done"                # ⛔ Chained (;)
for f in *; do echo $f; done       # ⛔ Inline Loop
```

## Implementation Guide

### 1. How to handle CWD?
**Do not use `cd` in the command string.**
- **Agent**: Use the `Cwd` parameter in `run_command` tool.
- **Scripts**: Handle directory logic inside the `.zsh` script itself (e.g., `REPO_ROOT="${0:A:h}/.."`).

### 2. How to run multiple steps?
**Do not chain with `&&`.**
- **Option A**: Use multiple `run_command` calls (Agent).
- **Option B**: Create a batch script (`batch_xxx.zsh`) and run that single file.

## Why?
- **Security**: Complex compound commands hide malicious logic from simple regex scanners.
- **UX**: Simple commands match the Allow List -> Zero Friction.
