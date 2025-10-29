# 🧠 Context Engineering Guide
> **Scope:** 02luka-repo local workspace
> **Updated:** 2025-09-30T22:24:57Z

## System Architecture
```
┌───────────────────────────────┐
│          Context Layer         │
│  - prompts/                   │
│  - .claude/commands/ (legacy)  │
│  - f/ai_context/*.json         │
└───────────────┬───────────────┘
                │
        ┌───────▼────────┐
        │ Luka Frontend  │
        │ (luka.html UI) │
        └───────┬────────┘
                │
        ┌───────▼────────┐
        │ boss-api       │
        │ /api/chat      │
        └───────┬────────┘
                │
┌───────────────▼──────────────┐
│ Local Gateways & Integrations│
│ - MCP Docker (5012)          │
│ - MCP FS (8765)              │
│ - Ollama (11434)             │
└──────────────────────────────┘
```

## Codex Template Usage Pattern
- **Always start from** `prompts/master_prompt.md` when drafting a task for Codex.
- Populate the `GOAL:` line with the mission statement, then fill sections for context, constraints, resources, validation, and follow-up.
- Store any project-specific variations inside `prompts/` to keep them discoverable through the mapping namespace `codex:*`.

## Installation & Maintenance
- Use `g/tools/install_master_prompt.sh` to install or refresh the templates. The script validates content hashes, creates backups, and prints usage reminders.
- `f/ai_context/mapping.json` (v2.1) now exposes the `codex` namespace so tooling can resolve paths like `codex:templates`.
- Update the mapping whenever new template families are added so downstream bots inherit the structure.

## Integration Checklist
- [x] Luka UI prompt library reads from `prompts/master_prompt.md`.
- [x] Backend orchestration forwards prompt metadata through `/api/chat`.
- [ ] Automate template freshness checks inside `verify_system.sh` (planned).

## LaunchAgent Health
- **Health Ratio:** 100% (all LaunchAgents validated after cleanup).
- **Notes:** MCP stack reporting healthy, zero configuration errors remaining.

## Runtime Path Rules

### 🚫 Avoid CloudStorage Paths at Runtime
- **Never rely on** `GoogleDrive-ittipong.c@gmail.com/My Drive/...` paths for runtime operations
- **CloudStorage paths** are placeholders and may not be accessible in devcontainer environments
- **Use symlinked paths** instead: `~/dev/02luka-repo` for consistent access

### ✅ Preferred Path Patterns
- **Development Root**: `/workspaces/02luka-repo` (canonical, devcontainer) or `~/dev/02luka-repo` (optional symlink, host)
- **Memory Files**: `.codex/hybrid_memory_system.md` (local to repo)
- **Reports**: `g/reports/` (versioned under git)
- **Logs**: `/tmp/` or `g/reports/` (avoid CloudStorage for runtime logs)

### 🔧 Path Resolution Strategy
1. **Use canonical workspace**: `/workspaces/02luka-repo` (devcontainer) - primary
2. **Optional symlink**: `~/dev/02luka-repo` (host) - for legacy compatibility
3. **Dynamic resolution**: Use `scripts/repo_root_resolver.sh` in all scripts
4. **Never assume CloudStorage**: Always use resolved paths for runtime
5. **Memory Bridge**: Uses repo-relative paths for portability

