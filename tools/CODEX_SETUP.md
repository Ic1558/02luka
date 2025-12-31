# Codex Tier 2 Setup (02luka)

## Prerequisites
- Codex CLI 0.77.0+
- git and python3 in PATH
- Repo at `~/02luka`

## Tier 2 Config (copy-paste)
Edit `~/.codex/config.toml` and merge this block with your existing config:

```toml
model = "gpt-5.2-codex"
model_reasoning_effort = "high"

[projects."/Users/icmini"]
trust_level = "trusted"

[projects."/Users/icmini/02luka"]
trust_level = "trusted"

[sandbox]
default_mode = "workspace-write"
auto_approve_reads = true
auto_approve_workspace_writes = true

[approval]
mode = "on-request"
trust_workspace_commands = true
prompt_for_dangerous = true

[workspace]
additional_writable = [
  "/Users/icmini/02luka/tools",
  "/Users/icmini/02luka/g/reports",
  "/Users/icmini/02luka/apps"
]
```

## Permissions and Safety
- Reads: allowed everywhere (for context)
- Writes: only inside the trusted workspace
- Dangerous commands (rm, sudo) still prompt

## Aliases (optional)
Run:
```bash
zsh ~/02luka/tools/setup_codex_workspace.zsh aliases
```

Creates:
- `codex-safe` -> `codex -s workspace-write`
- `codex-auto` -> `codex -a on-request -s workspace-write`
- `codex-danger` -> full bypass (emergency only)
- `codex-task` -> git safety net wrapper

## Testing
```bash
codex-safe "create a file at ~/02luka/tmp/sandbox_test.txt with content 'Hello'"
codex-safe "add a comment to tools/session_save.zsh"
```

Expected:
- Writes inside `~/02luka` succeed
- Writes outside workspace are blocked or prompt
