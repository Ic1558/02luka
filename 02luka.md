# 🎯 02luka Operations Brief
> **Last Updated:** 2025-09-30T22:24:57Z
> **Maintainer:** Luka Automation Stack

This document keeps the lightweight mirror of the broader 02luka system status for work inside `02luka-repo`. It highlights the most recent upgrades and the architecture areas that anyone collaborating through Codex should know about.

## 🧭 Architecture
### Tools
- **Gateway Suite:** MCP Docker (5012), MCP FS (8765), Ollama (11434)
- **Automation Scripts:** `verify_system.sh`, `auto_tunnel.zsh`, discovery helpers under `g/tools/`
- **Prompt Utilities:** `.codex/templates/`, `.claude/commands/` (legacy)

#### Codex Integration Templates
- **Purpose:** Provide a canonical prompt scaffolding so every Codex task starts with the same goals, constraints, and validation hooks.
- **Location:** `.codex/templates/master_prompt.md` (primary), additional templates live alongside it under `.codex/templates/`.
- **Installation:** `g/tools/install_master_prompt.sh` downloads or refreshes the template set, runs integrity checks, and backs up any existing prompts before overwriting.
- **Usage Pattern:** Open the Prompt Library in `luka.html` or copy the template directly—always begin with `GOAL:` describing the mission, then work through context, constraints, and validation steps.

## 🚀 Latest Achievements
1. **Codex Template Ecosystem Online** – Master template published to `.codex/templates/master_prompt.md` with automation script support.
2. **Prompt Library Hooked into Luka UI** – `luka.html` now fetches the master template, enabling quick insertion or clipboard copy.
3. **Mapping & Discovery Updated** – `f/ai_context/mapping.json` versioned to 2.1 with Codex namespace coverage and hidden-tier alignment.

## 🔄 Next Up
- Expand `.codex/templates/` with role-specific prompts (golden prompt, review prompt).
- Tie the installation script into the verification pipeline for automatic compliance checks.

