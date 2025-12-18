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

### gemini (Full Feature Mode - Human/Full)
**Entry**: `/opt/homebrew/bin/gemini`  
**Helper**: `tools/gemini_full_feature.zsh`

**Usage (Full Feature with OAuth)**:
```bash
cd ~/02luka && env -u GEMINI_API_KEY /opt/homebrew/bin/gemini --sandbox --approval-mode=default
```

**Or use helper**:
```bash
zsh tools/gemini_full_feature.zsh
```

### gmx (System/Plain Mode)
**Entry**: `/opt/homebrew/bin/gemini`  
**Helper**: `tools/gmx_system.zsh`

**Usage (System/Plain with OAuth)**:
```bash
cd ~/02luka && env -u GEMINI_API_KEY /opt/homebrew/bin/gemini --sandbox=false --approval-mode=default
```

**Or use helper**:
```bash
zsh tools/gmx_system.zsh
```

**Important Notes**:
- **OAuth vs API Key**: If `GEMINI_API_KEY` is exported in env, CLI may route through API key instead of OAuth
- **Solution**: Use `env -u GEMINI_API_KEY` to unset it before running (forces OAuth flow)
- **Model Flag**: **Don't use `--model auto`** (not a valid model name in v0.21.1). **Best default: don't send `--model` at all** unless intentionally pinning a model.
- **Approval Mode**: Use `--approval-mode=default` (not `auto_edit`) for proper approval flow
- **Full Feature**: Comes from `--sandbox` + `--approval-mode` + tool permissions, not just extensions
- **Extensions**: Many tools are built-in; empty extension list doesn't mean no web/tools
- **API Key Route**: If you intentionally want API key (may be billable), create separate alias like `gmx-api` to avoid accidental usage

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
