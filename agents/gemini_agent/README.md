# Gemini Agent - Heavy Compute Offloader

**Version:** 1.0.0
**Type:** Heavy Compute Specialist (Layer 4.5)
**Status:** Active
**Protocol:** v3.2 compliant

---

## Overview

Gemini is the heavy compute offloader for 02luka. It handles bulk operations, large-scale analysis, and test generation to preserve CLC/Codex tokens for local development work.

---

## Usage

### Direct invocation (when Gemini handler is active):

```bash
# Create work order
cat > /bridge/inbox/GEMINI/WO_test_generation.yaml <<EOF
wo_id: GEMINI_$(date +%Y%m%d_%H%M%S)
task_type: bulk_test_generation
input:
  target_files: ["\$SOT/g/apps/dashboard/**/*.js"]
  test_framework: jest
  coverage_target: 80
output_format: test_suite_patch
review_by: andy
EOF

# Check result (after processing)
cat /bridge/outbox/GEMINI/WO_test_generation_result.yaml
```

### Via Liam/GG routing:

When Liam/GG detect heavy compute tasks, they automatically route to Gemini via work orders.

---

## Capabilities

**Gemini excels at:**

1. **Bulk Test Generation**
   - Generate 50-100+ test cases from specifications
   - Multiple test frameworks (jest, pytest, etc.)
   - Target-driven coverage (80%, 90%, etc.)

2. **Multi-File Analysis**
   - Analyze 50+ files for patterns
   - Produce consolidated reports
   - Identify inconsistencies and recommendations

3. **Large-Scale Code Generation**
   - Scaffolding and boilerplate
   - Repetitive structures (20+ similar files)
   - API endpoint generation

4. **Documentation Generation**
   - API docs from code
   - README from project structure
   - Migration guides

---

## Routing Rules

**When to use Gemini:**

| Condition | Description |
|-----------|-------------|
| **Bulk operations** | Task requires generating/processing 10+ files |
| **Complex analysis** | Multi-file pattern detection, codebase-wide analysis |
| **High token cost** | Estimated >5K tokens, CLC/Codex quota >80% |
| **Repetitive work** | Generate N similar files/tests/configs |

**When NOT to use Gemini:**

| Condition | Use instead |
|-----------|-------------|
| Single-file edits | Andy (Cursor) |
| Governance changes | CLC (Claude Code) |
| Quick patches | Codex local dev |
| Interactive debugging | Local IDE/REPL |

---

## Work Order Format

### Input Template:

```yaml
wo_id: GEMINI_YYYYMMDD_HHMMSS_nnn
task_type: bulk_test_generation | multi_file_analysis | script_generation | doc_generation
priority: P1 | P2 | P3
requester: liam | gg | boss
input:
  # Task-specific parameters
  target_files: ["glob patterns"]
  framework: "jest | pytest | etc"
  options: {}
output_format: test_suite_patch | analysis_report | script_bundle | markdown_docs
review_by: andy | cls
metadata:
  estimated_tokens: 10000
  timeout_minutes: 30
```

### Output Template:

```yaml
wo_id: GEMINI_YYYYMMDD_HHMMSS_nnn
status: success | partial | failed
completed_at: "2025-11-18T06:30:00Z"
output_files:
  - path: "$SOT/path/to/output.ext"
    size: 12345
    description: "What this file contains"
summary: "Human-readable summary of what was generated"
tokens_used: 12450
quality_notes: "Areas needing manual review"
next_steps:
  - "Command to run"
  - "Things to verify"
```

---

## Protocols

**Primary:**
- `$SOT/g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md` (Layer 4.5 + Conservative Additive)
- `$SOT/g/docs/PATH_AND_TOOL_PROTOCOL.md`

**Reference:**
- `$SOT/agents/gemini_agent/PERSONA_PROMPT.md` (Complete behavioral specification)
- `$SOT/g/reports/system/GEMINI_INTEGRATION_PLAN_20251118.md` (Implementation plan)

---

## Integration Architecture

```
┌─────────────────────────────────────────┐
│  ORCHESTRATION LAYER                    │
├─────────────────────────────────────────┤
│  GG (ChatGPT)    │  Liam (Cursor)       │
│  Strategic       │  Local classifier     │
└──────────────┬──────────────────────────┘
               │ creates WO
               ↓
┌─────────────────────────────────────────┐
│  WORK ORDER SYSTEM                      │
├─────────────────────────────────────────┤
│  /bridge/inbox/GEMINI/                  │
│  → gemini_handler.py processes          │
│  → Calls gemini_connector.py            │
│  → Loads context via memory_loader.py   │
│  /bridge/outbox/GEMINI/                 │
└──────────────┬──────────────────────────┘
               │ result reviewed by
               ↓
┌─────────────────────────────────────────┐
│  REVIEW LAYER                           │
├─────────────────────────────────────────┤
│  Andy (Cursor)  │  CLS (Cursor)         │
│  Reviews output │  Verifies safety      │
└─────────────────────────────────────────┘
```

---

## Quota Tracking

Gemini usage is tracked by:

1. **Per-task logging** — Each work order reports tokens_used
2. **Quota tracker** — Aggregates usage across engines (GPT, Gemini, Codex, Claude)
3. **Dashboard widget** — Real-time visualization of token distribution

**Alerts:**
- 80% quota → Warning (still route tasks)
- 95% quota → Stop routing new tasks to Gemini

---

## Testing

**API Connectivity Test:**

```bash
# Set API key
export GEMINI_API_KEY="your-key-here"

# Test connection
python3 $SOT/g/connectors/gemini_connector.py

# Expected output:
# ✅ Gemini connector initialized
# ✅ API test successful
#    Response: Gemini API connection successful
#    Tokens: 15
```

**Work Order Test:**

```bash
# Create test work order
bash $SOT/tools/wo_dispatcher.zsh create GEMINI test \
  --input "Generate hello world test" \
  --output_format "code"

# Check processing
ls -l $SOT/bridge/inbox/GEMINI/
ls -l $SOT/bridge/outbox/GEMINI/
```

---

## Safety Rules

**Gemini MUST NOT:**
- Edit governance zones (`/CLC`, `/CLS`, `bridge/`, `memory/`)
- Make destructive changes without explicit work order
- Bypass review (all output goes through Andy/CLS)
- Execute code (generates specs/code for others to run)

**Gemini SHOULD:**
- Track token usage for every task
- Return complete, production-ready output
- Include test/validation steps
- Note limitations or areas needing human review

---

## Dependencies

**Required:**
- `google-generativeai` Python package
- GEMINI_API_KEY environment variable
- Gemini API subscription (active)

**Install:**

```bash
pip install google-generativeai
```

---

## Files Created (Phase 1)

```
g/connectors/gemini_connector.py          # API client
agents/gemini_agent/PERSONA_PROMPT.md     # Complete persona
agents/gemini_agent/README.md             # This file
bridge/handlers/gemini_handler.py         # Task handler (Phase 1.4)
bridge/memory/gemini_memory_loader.py     # Context loader (Phase 1.5)
```

---

## Version History

- **1.0.0** (2025-11-18) - Initial creation, Phase 1 complete

---

**See:** `PERSONA_PROMPT.md` for complete behavioral specification.
