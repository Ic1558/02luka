#!/usr/bin/env zsh
# load_persona_v3.zsh
# Universal Persona Loader for CLS (Cursor) + Liam (Antigravity)
# Usage:
#   ~/02luka/tools/load_persona_v3.zsh cls cursor
#   ~/02luka/tools/load_persona_v3.zsh liam ag
#   ~/02luka/tools/load_persona_v3.zsh liam both

set -u

LUKA_BASE="${LUKA_BASE:-$HOME/02luka}"
PERSONA_DIR="${LUKA_BASE}/personas"
AG_BRAIN_ROOT="${HOME}/.gemini/antigravity/brain"

CLS_ID_FILE="${LUKA_BASE}/CLS.md"

usage() {
  echo "Usage: $(basename "$0") <persona> <target>"
  echo "  persona: cls | liam"
  echo "  target : cursor | ag | both"
  echo
  echo "Examples:"
  echo "  $(basename "$0") cls cursor"
  echo "  $(basename \"$0\") liam ag"
  echo "  $(basename \"$0\") liam both"
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

PERSONA_KEY="$1"
TARGET="$2"

# Map persona key -> file path
case "$PERSONA_KEY" in
  cls)
    PERSONA_FILE="${PERSONA_DIR}/CLS_PERSONA_v2.md"
    ;;
  liam)
    PERSONA_FILE="${PERSONA_DIR}/LIAM_PERSONA_v2.md"
    ;;
  *)
    echo "❌ Unknown persona key: $PERSONA_KEY"
    echo "   Supported: cls, liam"
    exit 1
    ;;
esac

if [[ ! -f "$PERSONA_FILE" ]]; then
  echo "❌ Persona file not found: $PERSONA_FILE"
  echo "   Please create it first under: $PERSONA_DIR"
  exit 1
fi

generate_context_summary() {
  # Generate context summary for Antigravity brain
  # This provides core governance rules without requiring external file access
  cat <<'EOF'
# Context Summary: 02luka System Governance

**Purpose:** This document provides essential governance rules for AI agents operating in the 02luka ecosystem. For full details, see the referenced documents in `~/02luka/g/docs/`.

---

## 1. Two Worlds Model (CRITICAL)

The 02luka system operates in **two distinct layers**:

### Layer 1: CLI / Interactive World
- **Agents:** GMX, Codex CLI, Cursor, Antigravity, GG, GM (Gemini)
- **Governance:** **Advisory** (guidelines, not blockers)
- **Flexibility:** High - Boss has full control
- **Open Zones:** Can be written directly by CLI tools when Boss is present

### Layer 2: Background / Autonomous World
- **Agents:** Mary, LAC workers, CLC, LaunchAgents, background jobs
- **Governance:** **MANDATORY** (strict enforcement)
- **Rules:** Must follow AI_OP_001_v4 and CONTEXT_ENGINEERING_PROTOCOL_v4 strictly
- **Locked Zones:** Only CLC/LPE with Work Order (WO) + SIP + audit

---

## 2. Zones & Writers

### Locked Zones (LZ)
**Paths (examples):**
- `core/**`
- `CLC/**`
- `launchd/**`
- `bridge/core/**`, `bridge/inbox/**`, `bridge/outbox/**`
- Governance docs (`g/docs/AI_OP_001_v4.md`, `CONTEXT_ENGINEERING_PROTOCOL_v4.md`, etc.)

**Rules:**
- Writer: **CLC** (or LPE in emergency with Boss approval)
- Requires: Work Order (WO) when rules say so
- Requires: SIP (`mktemp → validate → mv`)
- Requires: SHA256 evidence + MLS log

### Open Zones (OZ)
**Paths:**
- `apps/**`
- `tools/**`
- `agents/**`
- `tests/**`
- `docs/**` (non-governance)
- `bridge/docs/**`
- `bridge/samples/**`

**Rules:**
- Allowed writers: Gemini, LAC, Codex, CLS, GG, GC (via routing)
- For CLI sessions: WO not required for small, non-critical changes
- Background workers: Must follow AI_OP_001_v4 audit rules

---

## 3. Identity Matrix (Role Definitions)

**CRITICAL:** Each agent must understand their role and boundaries to prevent scope violations.

| Agent | Role | CLI World | Background World | Notes |
|-------|------|-----------|-------------------|-------|
| **GG Core** | Co-Orchestrator | ⚠️ Propose only | ⚠️ Propose only | Planning + coordination, never writes directly |
| **GM Core (Gemini)** | Co-Orchestrator (with GG) | ⚠️ Propose/Coordinate | ❌ No direct write | Shares planning and execution authority in CLI world |
| **CLS** | System Orchestrator / Router | ✅ Write (Open Zones) | ✅ Write (via routing) | Must respect CLI vs Background split |
| **Mary** | Traffic / Safety Router | ❌ | ✅ Enforces Two Worlds rules | Background world traffic control |
| **CLC** | Locked-zone Executor | ❌ | ✅ Write (Locked Zones only) | Primary writer for Locked Zones, background world |
| **LAC** | Auto-Coder | ❌ | ✅ Write (Open Zones) | Autonomous code generation |
| **Codex** | IDE Assistant | ✅ Write (Diff) | ❌ | Diff-only writes |
| **Gemini** | Operational Worker | ✅ Write (Open Zones) | ✅ Write (Open Zones) | For code/content rewrite |
| **Liam** | Explorer & Planner | ✅ Propose/Design | ❌ No direct write | Creative prototyper, system planner |
| **LPE** | Emergency Patcher | ⚠️ Boss Only | ❌ | Dumb executor, Boss approval required |

---

## 4. Work Order (WO) Decision Rule

**WO is required when:**
- Locked Zone changes
- Background world changes (per AI_OP_001_v4)
- Multiple critical issues (2+ issues → create WO)

**WO is NOT required when:**
- Single critical issue (fix directly)
- CLI world, Open Zone, small changes
- Boss is present and approves direct action

---

## 5. Key Principles

1. **Lego Architecture:** Modular, swappable components
2. **First-Writer-Locks:** First agent to write a file owns it until completion
3. **Safety First:** Physical/OS safety cannot be overridden
4. **Boss Override:** Boss live commands override all governance (except safety)

---

## 6. Full Documentation References

For complete details, see:
- `~/02luka/g/docs/AI_OP_001_v4.md` - Core operational protocol
- `~/02luka/g/docs/CONTEXT_ENGINEERING_PROTOCOL_v4.md` - Context engineering rules
- `~/02luka/g/docs/GOVERNANCE_CLI_VS_BACKGROUND_v1.md` - Two Worlds governance

---

**Note:** This summary is designed for AI agents to understand core rules without requiring external file access. Always refer to full documentation for edge cases or detailed specifications.
EOF
}

inject_cursor_cls() {
  # Only meaningful for CLS persona
  if [[ "$PERSONA_KEY" != "cls" ]]; then
    echo "⚠️  Skipping Cursor injection: persona '$PERSONA_KEY' is not CLS."
    return 0
  fi

  mkdir -p "$(dirname "$CLS_ID_FILE")"

  # Use /tmp for atomic operations (cleaner, avoids repo noise)
  local tmp
  tmp="$(mktemp "/tmp/cls_persona_XXXXXX")" || {
    echo "❌ Failed to create temp file for CLS.md"
    exit 1
  }

  cp "$PERSONA_FILE" "$tmp" || {
    echo "❌ Failed to copy persona to temp CLS file"
    rm -f "$tmp"
    exit 1
  }

  mv "$tmp" "$CLS_ID_FILE" || {
    echo "❌ Failed to move temp CLS file into place"
    rm -f "$tmp"
    exit 1
  }

  echo "✅ CLS persona updated at: $CLS_ID_FILE"
  echo "   (No changes made to .cursorrules by this script)"
}

inject_antigravity() {
  mkdir -p "$AG_BRAIN_ROOT"

  # Find latest brain directory (most recently modified)
  local latest
  latest="$(ls -td "$AG_BRAIN_ROOT"/*/ 2>/dev/null | head -1 || true)"

  if [[ -z "${latest:-}" ]]; then
    echo "❌ No Antigravity brain sessions found in: $AG_BRAIN_ROOT"
    echo "   Open Antigravity.app and start a session first."
    exit 1
  fi

  echo "🧠 Antigravity Brain detected:"
  echo "   $latest"

  # Remove only old ACTIVE_PERSONA markers (do NOT touch other files)
  rm -f "${latest}"00_ACTIVE_PERSONA_*.md 2>/dev/null || true

  local persona_basename
  persona_basename="$(print -r -- "$PERSONA_KEY" | tr '[:lower:]' '[:upper:]')"
  local target_file="${latest}00_ACTIVE_PERSONA_${persona_basename}.md"
  local context_file="${latest}01_CONTEXT_SUMMARY.md"

  # 1. Inject persona
  cp "$PERSONA_FILE" "$target_file" || {
    echo "❌ Failed to copy persona into Antigravity brain"
    exit 1
  }

  # 2. Inject context summary (NEW - default behavior)
  generate_context_summary > "$context_file" || {
    echo "❌ Failed to write context summary"
    exit 1
  }

  # 3. Update task.md to reference both
  local task_file="${latest}task.md"
  if [[ -f "$task_file" ]]; then
    {
      echo ""
      echo "> [SYSTEM] Active Persona: ${persona_basename}"
      echo "> See: $(basename "$target_file")"
      echo "> Context: $(basename "$context_file")"
    } >> "$task_file" || true
  fi

  echo "✅ Antigravity persona injected:"
  echo "   $target_file"
  echo "✅ Context summary injected:"
  echo "   $context_file"
}

case "$TARGET" in
  cursor)
    inject_cursor_cls
    ;;
  ag)
    inject_antigravity
    ;;
  both)
    inject_cursor_cls
    inject_antigravity
    ;;
  *)
    echo "❌ Unknown target: $TARGET"
    echo "   Supported: cursor | ag | both"
    exit 1
    ;;
esac

echo "✨ Done."
