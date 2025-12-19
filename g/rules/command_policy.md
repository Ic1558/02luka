# ATG Command Policy (Hard Canonical)

**Status**: ACTIVE (HARD ENFORCEMENT)
**Purpose**: Eliminate "Accept" button friction perfectly.

## The Rule: Hard Canonical Syntax
Antigravity UI allows **ONLY** commands matching these exact patterns.
Any deviation (extra tokens, chaining) triggers the UI permission prompt.

### ✅ Allowed Patterns (Exact Match)
Command must match one of these prefixes exactly:

1. `zsh "$HOME/02luka/tools/`
2. `AGENT_ID=liam zsh "$HOME/02luka/tools/`

**Example:**
```zsh
AGENT_ID=liam zsh "$HOME/02luka/tools/save.sh"
zsh "$HOME/02luka/tools/guard_runtime.zsh" --cmd "ls"
```

### ⛔ Forbidden Tokens
Use of these tokens anywhere in the command string triggers a prompt:
- `cd` (Change directory)
- `&&` or `;` (Chaining)
- `exec`
- `|` (Pipes)
- `>` or `>>` (Redirection)
- `2>&1` (stderr redirection)
- `sudo`

### 📝 Logging & Output
- **Do not use redirection** in the terminal command (e.g., `> log.txt` or `2>&1`).
- Scripts must handle their own logging internally.
- `tools/save.sh` handles its own output.

## Implementation Guide for Agents
- Always use the full absolute path variable: `$HOME/02luka`.
- Never `cd` before running.
- Pass arguments cleanly without shell metacharacters if possible.

**Canonical Save Command:**
```zsh
AGENT_ID=liam zsh "$HOME/02luka/tools/save.sh"
```
