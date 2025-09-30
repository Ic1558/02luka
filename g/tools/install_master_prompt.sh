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
EXPECTED_CONTENT="$(cat <<'TEMPLATE'
# Codex Master Prompt Template

Use this template to orchestrate Codex tasks. Replace the placeholders with your mission details and keep the structure intact for predictable execution.

---

## GOAL
Describe the single objective you want Codex to complete.

- Primary outcome:
- Success criteria:
- Deadline or urgency:

## CONTEXT
Summarize the background knowledge, existing assets, or prior attempts.

- Current state:
- Related files or services:
- Stakeholders or dependencies:

## CONSTRAINTS
List requirements that must be respected.

- Technical constraints:
- Policy or compliance constraints:
- Resource limits:

## AVAILABLE RESOURCES
Identify tools, data sources, credentials, and reusable components.

- Internal resources:
- External APIs or services:
- Reference material:

## WORKFLOW STRATEGY
Outline the proposed steps Codex should follow.

1. Plan
2. Execute
3. Validate
4. Report

> Include decision points, fallbacks, or monitoring signals when needed.

## VALIDATION & METRICS
Define how success will be measured and what evidence is required.

- Tests or checks:
- Observability signals:
- Acceptance thresholds:

## OUTPUT FORMAT
Specify the structure, tone, and delivery channel of the final response.

- Required sections:
- Formatting rules:
- Additional assets (links, files, screenshots):

## FOLLOW-UP
Capture next steps, escalation paths, or iteration triggers.

- If success:
- If blocked:
- Additional notes:

> ALWAYS Use .codex/templates/master_prompt.md with GOAL: <งานที่ต้องการ>

ตัวยืน: ยึดตามเทมเพลตนี้ทุกครั้ง และแทนที่ข้อความในวงเล็บมุมด้วยรายละเอียดของงานจริง
TEMPLATE
)"

mkdir -p "$TEMPLATE_DIR"

if [[ -f "$TARGET_FILE" ]]; then
  if cmp -s <(printf '%s\n' "$EXPECTED_CONTENT") "$TARGET_FILE"; then
    echo "Master prompt template already installed."
    echo "ใช้เทมเพลตเดิมได้เลย: $TARGET_FILE"
    echo "Use .codex/templates/master_prompt.md with GOAL: <งานที่ต้องการ>"
    exit 0
  else
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_file="${TARGET_FILE}.backup-${timestamp}"
    cp "$TARGET_FILE" "$backup_file"
    echo "Existing template differed. Backed up to $backup_file"
  fi
else
  echo "Master prompt template missing. Creating new file."
fi

printf '%s\n' "$EXPECTED_CONTENT" > "$TARGET_FILE"

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
