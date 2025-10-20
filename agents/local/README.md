# Local Orchestrator & Delegation

**Phase 7.2: Flip the execution model**

CLC writes specs → Local executes → Auto-learning

---

## Quick Start

### 1. Run Smoke Test

```bash
# Create smoke task
cat > queue/inbox/tsk_smoke.json <<'JSON'
{
  "id": "tsk_smoke",
  "title": "Smoke Test",
  "risk": "low",
  "skills": ["bash"],
  "steps": [
    {"skill": "bash", "args": ["-c", "echo 'SMOKE_OK'"]}
  ],
  "memory": {"kind": "solution", "text": "Smoke test passed"}
}
JSON

# Execute
node agents/local/orchestrator.cjs --once --verbose
```

**Expected:**
```
✅ tsk_smoke.json: OK
```

### 2. Run Weekly Review

```bash
cp queue/examples/tsk_weekly_review.json queue/inbox/
node agents/local/orchestrator.cjs --once
```

### 3. Test Policy Gates

```bash
# High-risk task will be blocked
cp queue/examples/tsk_git_deploy.json queue/inbox/
node agents/local/orchestrator.cjs --once
# Output: ❌ BLOCKED - approval_required

# Approve for single run
LOCAL_ALLOW_HIGH=1 node agents/local/orchestrator.cjs --once
```

---

## Usage

```bash
# Process queue once and exit
node orchestrator.cjs --once

# Continuous polling (every 5 seconds)
node orchestrator.cjs

# Verbose mode
node orchestrator.cjs --once --verbose
```

---

## Task Spec Format

```json
{
  "id": "tsk_example",
  "title": "Example Task",
  "priority": "low",
  "risk": "low",
  "skills": ["bash", "node"],
  "steps": [
    {
      "skill": "bash",
      "args": ["-c", "echo 'Step 1'"]
    },
    {
      "skill": "node",
      "args": ["scripts/example.cjs"],
      "timeout": 30000,
      "optional": false
    }
  ],
  "acceptance": [
    "Step 1 completed",
    "Output file exists"
  ],
  "memory": {
    "kind": "solution",
    "text": "Example task completed successfully"
  }
}
```

---

## Skills

Built-in skills ready to use:

- **bash** - Shell commands with guardrails
- **node** - Node.js script execution
- **git** - Safe git operations (blocks force push to main/master)
- **http** - HTTP requests (localhost + trusted domains only)
- **ops_atomic** - Integration with run/ops_atomic.sh
- **reportbot** - Integration with agents/reportbot/index.cjs
- **self_review** - Integration with agents/reflection/self_review.cjs

---

## Policy Gates

**Automatic blocking:**
- Destructive operations (rm -rf /, mkfs, dd, shutdown)
- Force push to main/master
- chmod 777 on root
- Fork bombs
- High-risk tasks (score ≥ 60)

**Approval required:**
```bash
LOCAL_ALLOW_HIGH=1 node orchestrator.cjs --once
```

---

## Auto-Learning

Every task execution automatically:

1. **Writes Telemetry** (NDJSON to g/telemetry/*.log)
2. **Records Memory** (via memory/index.cjs)
3. **Generates Log** (detailed execution log in g/logs/)

Feeds into:
- Phase 7.1 Self-Review (analyzes telemetry)
- Phase 6.5-B Memory System (recalls patterns)

---

## Files

```
agents/local/
├── README.md              (this file)
├── orchestrator.cjs       (main executor)
├── policy.cjs             (risk gates)
└── skills/
    ├── bash.sh
    ├── node.cjs
    ├── git.sh
    └── http.cjs

queue/
├── inbox/                 (new tasks)
├── running/               (executing)
├── done/                  (completed)
├── failed/                (blocked/failed)
└── examples/              (example task specs)
```

---

## Examples

See `queue/examples/` for ready-to-use task specs:

- **tsk_weekly_review.json** - Weekly self-review + ops check
- **tsk_health_check.json** - System health monitoring
- **tsk_git_deploy.json** - Git push with approval gate

---

## Token Savings

**Before (Direct Execution):** ~6500 tokens per task
**After (Delegation):** ~700 tokens per task
**Savings:** 89%

CLC only writes tiny JSON specs instead of executing full commands with context.

---

## Documentation

**Full documentation:** `docs/PHASE7_2_DELEGATION.md`

**Related:**
- Phase 7.1 Self-Review: `docs/PHASE7_COGNITIVE_LAYER.md`
- Memory System: `docs/CONTEXT_ENGINEERING.md`
- Telemetry: `boss-api/telemetry.cjs`

---

**Status:** ✅ COMPLETE - Production Ready
**Version:** 1.0.0 (2025-10-20)
