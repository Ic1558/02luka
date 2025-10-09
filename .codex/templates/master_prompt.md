# Master Prompt for Codex – 02luka System

You are Codex working in the 02luka monorepo.

Read first:
- .codex/PREPROMPT.md
- .codex/CONTEXT_SEED.md
- .codex/PATH_KEYS.md
- .codex/GUARDRAILS.md
- f/ai_context/mapping.json

## Critical Rules
- Always resolve paths via `g/tools/path_resolver.sh` (no absolute paths).
- Do NOT create symlinks (Google Drive mirror is used).
- Do NOT write to a/, c/, o/, s/ (human-only sandboxes).
- Always run validations before committing.
- Guardrail FAIL = stop immediately, append manifest with fail status.

## System Architecture
- g/: infra tools, validators, helpers
- run/: runtime artifacts, status, reports
- boss/: workspace (dropbox, inbox, sent, deliverables)
- f/ai_context/: resolver mapping & context data
Flow: dropbox → inbox/sent → deliverables

## Namespace Mapping
- human:inbox → boss/inbox/
- human:sent → boss/sent/
- human:deliverables → boss/deliverables/
- infra:clc_gate → g/tools/clc_gate.sh
- codex:prompts → .codex/templates/

## Network Defaults
- boss-api: http://127.0.0.1:4000
- boss-ui (static dev): http://127.0.0.1:5173
- health-proxy: http://127.0.0.1:3002
- mcp-bridge: http://127.0.0.1:3003
- fastvlm (optional): http://127.0.0.1:8765

## Validation Strategy
- Run `.codex/preflight.sh`
- Run `g/tools/mapping_drift_guard.sh --validate`
- Run `g/tools/clc_gate.sh --scope=precommit`
- If touching boss-api/gateway: run `g/tools/clc_gate.sh --scope=security`
- If touching g/tools/run/mapping: run `g/tools/clc_gate.sh --scope=all`

## Commit & PR Policy
- Conventional commit + CHANGE_ID + tags
- Example:
  `feat(api,ui): add endpoint (CHANGE_ID: CU-2025-10-01-boss-ui-api-v1) #boss-api #boss-ui #resolver #preflight`

## Change Tracking
- Append manifest to `run/change_units/CU-YYYY-MM-DD.yml`
- Append bullet to `run/daily_reports/REPORT_YYYY-MM-DD.md`
- Append-only, never overwrite

## Usage (Template)
CONTEXT_ID: CU-YYYY-MM-DD
CHANGE_ID: CU-YYYY-MM-DD-<slug>
TAGS: #boss-api #boss-ui #resolver #preflight
VALIDATION: precommit

GOAL:
- <describe the goal here>
- Codex must follow guardrails and output:
  1. Edited files list + diffs summary
  2. Manifest entry appended
  3. Daily report bullet appended
  4. Commit message (Conventional) with CHANGE_ID + tags
