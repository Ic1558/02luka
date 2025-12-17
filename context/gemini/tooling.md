# Tooling Guide (02luka)

**Source of Truth**: `tools/catalog.yaml`  
**Last Synced**: 2025-12-18  
**Version**: v1

---

## Catalog-First Rule

**Always use the catalog as source of truth** for tool/command information.

### Lookup Command
```bash
zsh tools/catalog_lookup.zsh <command>
```

### Run Tool (Single Entry Point)
```bash
zsh tools/run_tool.zsh <tool-id> [args...]
```

**Rule**: Always use `run_tool.zsh` wrapper. Auto-discovery fallback prevents blocking.

## Key Commands

### save-now
**Entry**: `./tools/save.sh`  
**Usage**: 
```bash
cd ~/02luka && AGENT_ID=<agent_name> SAVE_SOURCE=terminal ./tools/save.sh
```

**Important**: Uses `save.sh` as gateway, NOT `session_save.zsh` directly.

### seal-now
**Entry**: `./tools/workflow_dev_review_save.zsh`  
**Description**: Full chain: Review → GitDrop → Save

### code-review
**Entry**: `./tools/code_review_gate.zsh`  
**Usage**: `zsh tools/run_tool.zsh code-review <target> [--quick] [--json]`  
**Gate**: Gate 2.5 (after DRYRUN, before VERIFY)

### feature-dev-validate
**Entry**: `./tools/feature_dev_validate.zsh`  
**Usage**: `zsh tools/run_tool.zsh feature-dev-validate <feature-slug>`  
**Gate**: Gate 4 (Production Readiness - MUST PASS before completion)  
**Quality Gate**: 90% (blocks completion if < 90%)

### gemini-bootstrap
**Entry**: `./tools/gemini_bootstrap.zsh`  
**Usage**: `zsh tools/gemini_bootstrap.zsh <profile> [--print] [--doctor] [--] [gemini args...]`  
**Notes**: Reads profiles from `~/.config/gemini/policies.yaml` and only passes gemini flags that exist in `gemini --help`.

## Tool Execution Pattern

1. **Check catalog**: `zsh tools/catalog_lookup.zsh <command>`
2. **Use wrapper**: `zsh tools/run_tool.zsh <tool-id> [args...]`
3. **Fallback**: Auto-discovery if not in catalog (prevents blocking)

## Environment Variables

Common environment variables used by tools:
- `AGENT_ID` — Agent identifier
- `SAVE_SOURCE` — Source of save operation (e.g., `terminal`)
- `LUKA_SOT` — Single Source of Truth path (`/Users/icmini/02luka`)
- `LUKA_HOME` — Working directory (`/Users/icmini/02luka/g`)

---

**For full catalog, see**: `tools/catalog.yaml`
