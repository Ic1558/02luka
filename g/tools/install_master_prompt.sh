#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-}"

if [[ -z "$PROJECT_ROOT" ]]; then
  if PROJECT_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null); then
    :
  else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  fi
fi

TEMPLATE_DIR="$PROJECT_ROOT/.codex/templates"
TARGET_FILE="$TEMPLATE_DIR/master_prompt.md"
EXPECTED_SHA="7814b917a2e7154b4f9d717173d9736e34c2fbec5b4389c174533c12080e6e0b"
EXPECTED_CONTENT="$(cat <<'TEMPLATE'
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
- Work from the Stream Mode workspace (`$SOT_PATH=~/dev/02luka-repo`) instead of direct Google Drive paths.
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
TEMPLATE
)"

mkdir -p "$TEMPLATE_DIR"

if [[ -f "$TARGET_FILE" ]]; then
  ACTUAL_SHA=$(shasum -a 256 "$TARGET_FILE" | awk '{print $1}')
  if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_file="${TARGET_FILE}.backup-${timestamp}"
    cp "$TARGET_FILE" "$backup_file"
    echo "Existing template differed. Backed up to $backup_file"
  else
    echo "Master prompt template already installed."
    echo "ใช้เทมเพลตเดิมได้เลย: $TARGET_FILE"
    echo "Use .codex/templates/master_prompt.md with GOAL: <งานที่ต้องการ>"
    exit 0
  fi
else
  echo "Master prompt template missing. Creating new file."
fi

printf '%s' "$EXPECTED_CONTENT" > "$TARGET_FILE"

cat <<'MSG'
✅ Installation complete.

How to use / วิธีใช้งาน:
  1. Open .codex/templates/master_prompt.md
  2. Replace GOAL with the Thai description of the task (งานที่ต้องการ)
  3. Fill each section before running Codex

Quick commands:
  • ใช้เทมเพลต: Use .codex/templates/master_prompt.md with GOAL: <งานที่ต้องการ>
  • ติดตั้งในโปรเจกต์นี้: g/tools/install_master_prompt.sh
  • คัดลอกไปโปรเจกต์อื่น: cp '.codex/templates/master_prompt.md' /path/to/your/project/.codex/
MSG
