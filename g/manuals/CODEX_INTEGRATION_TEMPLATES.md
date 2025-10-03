# CODEX Integration Templates Manual
> **Document Owner:** Context Engineering Guild
> **Last Updated:** 2025-09-30T22:24:57Z

## 1. Purpose
The Codex Integration Template system standardises how automation agents compose requests inside 02luka. Every task begins with a structured mission brief (`master_prompt.md`) that encodes goals, constraints, resources, validation, and follow-up expectations.

## 2. Components
- `.codex/templates/master_prompt.md` — daily driver template for all Codex missions.
- `.codex/templates/` — directory reserved for additional prompt archetypes (e.g., `golden_prompt.md`, review prompts).
- `g/tools/install_master_prompt.sh` — installer/refresh utility with integrity checks and backup safeguards.
- `luka.html` Prompt Library — front-end tool that fetches the master template and injects it into the composer.

## 3. Installation Workflow
1. Run `bash g/tools/install_master_prompt.sh`.
2. Script actions:
   - Creates `.codex/templates/` if missing.
   - Backs up existing templates (suffix `.bak-<timestamp>`).
   - Installs or refreshes `master_prompt.md` and companion files.
   - Prints usage reminders (`Use .codex/templates/master_prompt.md with GOAL: <งานที่ต้องการ>`).
3. Verify installation via `ls .codex/templates/` or by opening the Prompt Library inside `luka.html`.

## 4. Daily Usage
- Start every Codex ask by copying the master template.
- Replace `<งานที่ต้องการ>` with the specific mission inside the `GOAL:` line.
- Fill each section (Context, Constraints, Resources, Workflow Strategy, Validation, Output Format, Follow-Up) before executing commands.
- Keep working notes beneath the sections; do not delete headers so automated checkers can parse them.

## 5. Customisation Guidelines
- Add new templates to `.codex/templates/` with descriptive names (`golden_prompt.md`, `review_prompt.md`).
- Document each addition inside this manual and reference it from `f/ai_context/mapping.json` if it needs a logical key.
- Avoid editing `master_prompt.md` directly; instead update the installer script so changes propagate uniformly.

## 6. Integration Points
- **Mapping:** `f/ai_context/mapping.json` exposes `codex:templates` and `codex:prompts` for path resolution.
- **Discovery:** Add new templates to `run/system_discovery_*.json` workflows so automated docs include them (pending automation hook).
- **Verification:** Extend `verify_system.sh` to check template hashes (todo) ensuring no drift between commits and local installs.

## 7. Troubleshooting
| Symptom | Likely Cause | Resolution |
|---------|--------------|------------|
| Prompt Library shows "Unable to load master prompt" | HTTP server not serving repo root | Run `python3 -m http.server` from repo root, then reload. |
| Installer warns about missing `.codex` | Directory deleted or moved | Recreate with `mkdir -p .codex/templates` before rerunning installer. |
| Template edits do not persist | Direct editing of generated file | Update source in installer or commit new template file under version control. |

## 8. Change Log
- **2025-09-30:** Initial manual published; mapping namespace updated to include `codex:*`; Luka Prompt Library connected to backend prompt loader.

## 9. Context Engine v6
- `g/tools/context_engine.sh` exposes the v6 header (`SCRIPT_NAME=context_engine`, `VERSION=6.0`) and honours env flags `AUTO_PRUNE=1` and `ADVANCED_FEATURES=1`. Safe mode performs a straight pass-through.
- Use `g/tools/context_engine.sh --version` to confirm rollout, or pipe payloads via `--input/--output` for explicit files.
- `g/tools/model_router.sh <TASK_TYPE> [HINTS]` returns routing JSON (model, reason, confidence) with safe fallbacks if the preferred Ollama model is missing.
- Example: `TASK_TYPE=review HINTS="diff cleanup" bash g/tools/model_router.sh` → prioritises `deepseek-coder` or falls back to the next available model.
