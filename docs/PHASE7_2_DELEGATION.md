# Phase 7.2: Local Orchestrator & Delegation

**Status:** ✅ COMPLETE
**Date:** 2025-10-20
**Prerequisites:** Phase 6 (Memory) + Phase 7.1 (Self-Review)

---

## Overview

Phase 7.2 flips the execution model from "CLC executes everything" to "CLC writes specs, local executes with learning loops."

**Before Phase 7.2:**
- CLC executes bash/node/git commands directly
- High token usage for execution context
- Limited guardrails and safety checks
- No automatic learning from execution

**After Phase 7.2:**
- CLC writes tiny task specs (JSON/YAML)
- Local orchestrator executes with:
  - Policy gates (risk scoring, approval flow)
  - Auto-learning (telemetry + memory integration)
  - Skills registry (bash, node, git, http, ops_atomic, reportbot, self_review)
  - Fail-safe execution with timeouts
- Token savings: 80-90% reduction (only spec → result, not full execution)

---

## Architecture

```
CLC/Codex/User
     ↓
  writes task spec (JSON)
     ↓
queue/inbox/
     ↓
Local Orchestrator (orchestrator.cjs)
     ↓
Policy Gates (policy.cjs)
     ↓
Skills (bash, node, git, http, etc.)
     ↓
Telemetry + Memory + Logs
     ↓
queue/done/ or queue/failed/
```

---

## Components

### 1. Task Queue (Filesystem-Based)

```
queue/
├── inbox/       # New tasks (JSON/YAML files)
├── running/     # Currently executing
├── done/        # Successfully completed
└── failed/      # Failed or blocked
```

**Simple and robust:**
- No database dependencies
- Human-readable task specs
- Easy to inspect/debug
- Works offline

### 2. Local Orchestrator (`agents/local/orchestrator.cjs`)

**Responsibilities:**
- Poll queue/inbox/ for new tasks
- Execute steps sequentially with timeouts
- Write telemetry (NDJSON format)
- Record memories (auto-learning)
- Move tasks to done/failed/
- Generate execution logs

**Usage:**
```bash
# Process queue once and exit
node agents/local/orchestrator.cjs --once

# Continuous polling (every 5 seconds)
node agents/local/orchestrator.cjs

# Verbose mode for debugging
node agents/local/orchestrator.cjs --once --verbose
```

**Built-in Skills:**
- `bash` - Shell commands with guardrails
- `node` - Node.js script execution
- `git` - Safe git operations
- `http` - HTTP requests (localhost/trusted only)
- `ops_atomic` - Integration with run/ops_atomic.sh
- `reportbot` - Integration with agents/reportbot/index.cjs
- `self_review` - Integration with agents/reflection/self_review.cjs

### 3. Policy Engine (`agents/local/policy.cjs`)

**Risk Scoring (0-100):**
- Declared risk (low/medium/high): +10/+30/+60
- Dangerous patterns: +70
- Git push operations: +20
- Force flags: +30
- Priority urgent: +15

**Approval Thresholds:**
- Risk < 60: Auto-approve
- Risk ≥ 60: Requires `LOCAL_ALLOW_HIGH=1`
- High risk or urgent priority: Requires approval

**Dangerous Pattern Detection:**
- Destructive file operations (rm -rf /, mkfs, dd)
- System operations (shutdown, reboot)
- Permission bombs (chmod 777 /)
- Fork bombs (:|:)
- Git force push to main/master
- Code injection (eval, exec)

**Approval Flow:**
```bash
# Task blocked with approval_required
❌ tsk_git_deploy.json: BLOCKED - approval_required

# Approve for single run
LOCAL_ALLOW_HIGH=1 node agents/local/orchestrator.cjs --once
```

### 4. Skills (`agents/local/skills/`)

**bash.sh** - Safe bash execution
```bash
#!/usr/bin/env bash
# Rejects dangerous commands (belt & suspenders with policy.cjs)
# No interactive TTY
# Timeout handled by orchestrator
```

**node.cjs** - Node.js execution
```javascript
// Simple pass-through to node
// Inherits stdio for clean output
```

**git.sh** - Safe git operations
```bash
# Read-only operations: Always allowed (status, log, diff, show)
# Write operations: Allowed with warnings
# Force push to main/master: BLOCKED
# Hard reset: Requires manual confirmation
```

**http.cjs** - HTTP requests
```javascript
// Localhost + trusted domains only
// Blocks external requests by default
// 30s timeout
// JSON response handling
```

---

## Task Spec Format

### Minimal Example

```json
{
  "id": "tsk_example",
  "title": "Example Task",
  "priority": "low",
  "risk": "low",
  "skills": ["bash"],
  "steps": [
    {
      "skill": "bash",
      "args": ["-c", "echo 'Hello from delegation'"]
    }
  ],
  "acceptance": ["Printed message"],
  "memory": {
    "kind": "solution",
    "text": "Example task completed successfully"
  }
}
```

### Full Example (Weekly Review)

```json
{
  "id": "tsk_weekly_review",
  "title": "Weekly Self-Review & Report Generation",
  "priority": "medium",
  "risk": "low",
  "skills": ["self_review", "ops_atomic", "bash"],
  "steps": [
    {
      "skill": "self_review",
      "args": ["--days=7"],
      "timeout": 30000
    },
    {
      "skill": "ops_atomic",
      "args": [],
      "timeout": 30000,
      "optional": true
    },
    {
      "skill": "bash",
      "args": ["-c", "echo 'Review completed'"]
    }
  ],
  "acceptance": [
    "Report file exists under g/reports/self_review_*.md",
    "OPS_SUMMARY.json updated"
  ],
  "memory": {
    "kind": "plan",
    "text": "Weekly self-review executed successfully"
  },
  "notify": {
    "channels": ["general"],
    "level": "info"
  }
}
```

### Task Spec Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique task identifier |
| `title` | Yes | Human-readable title |
| `priority` | No | low/medium/high/urgent (default: medium) |
| `risk` | No | low/medium/high (default: medium) |
| `skills` | Yes | Array of skill names |
| `steps` | Yes | Array of execution steps |
| `acceptance` | No | Array of acceptance criteria (lightweight checks) |
| `memory` | No | Memory entry to record on success |
| `notify` | No | Notification config (future use) |

### Step Fields

| Field | Required | Description |
|-------|----------|-------------|
| `skill` | Yes | Skill name (bash, node, git, http, etc.) |
| `args` | Yes | Array of arguments to skill |
| `timeout` | No | Timeout in milliseconds (default: 120000) |
| `optional` | No | If true, failure won't stop task (default: false) |

---

## Workflows

### 1. CLC Delegates a Task

**Old Way (Direct Execution):**
```javascript
// CLC executes directly (high token usage)
const result = await bash('bash scripts/generate_report.sh');
// Sends full context, execution logs, errors back to user
```

**New Way (Delegation):**
```javascript
// CLC writes tiny task spec
const task = {
  id: 'tsk_generate_report',
  title: 'Generate Report',
  risk: 'low',
  skills: ['bash'],
  steps: [{ skill: 'bash', args: ['scripts/generate_report.sh'] }],
  memory: { kind: 'solution', text: 'Report generated successfully' }
};

fs.writeFileSync('queue/inbox/tsk_generate_report.json', JSON.stringify(task));
// Local picks up and executes
// Only result comes back (90% token savings)
```

### 2. Scheduled Weekly Review

**Create task:**
```bash
cat > queue/inbox/tsk_weekly_review.json <<'JSON'
{
  "id": "tsk_weekly_review",
  "title": "Weekly Review",
  "risk": "low",
  "skills": ["self_review", "ops_atomic"],
  "steps": [
    {"skill": "self_review", "args": ["--days=7"]},
    {"skill": "ops_atomic"}
  ],
  "memory": {"kind": "plan", "text": "Weekly review completed"}
}
JSON
```

**Execute:**
```bash
node agents/local/orchestrator.cjs --once
```

**Schedule with LaunchAgent:**
```xml
<!-- ~/Library/LaunchAgents/com.02luka.weekly.review.plist -->
<plist>
  <dict>
    <key>Label</key>
    <string>com.02luka.weekly.review</string>
    <key>ProgramArguments</key>
    <array>
      <string>/opt/homebrew/bin/node</string>
      <string>/path/to/agents/local/orchestrator.cjs</string>
      <string>--once</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
      <key>Weekday</key><integer>1</integer>
      <key>Hour</key><integer>9</integer>
      <key>Minute</key><integer>0</integer>
    </dict>
  </dict>
</plist>
```

### 3. High-Risk Deployment

**Task requires approval:**
```json
{
  "id": "tsk_deploy",
  "title": "Deploy to Production",
  "priority": "urgent",
  "risk": "high",
  "skills": ["git", "bash"],
  "steps": [
    {"skill": "git", "args": ["push", "origin", "main"]},
    {"skill": "bash", "args": ["scripts/deploy_prod.sh"]}
  ]
}
```

**Automatic block:**
```bash
$ node agents/local/orchestrator.cjs --once
❌ tsk_deploy.json: BLOCKED - approval_required
```

**Manual approval:**
```bash
$ LOCAL_ALLOW_HIGH=1 node agents/local/orchestrator.cjs --once
✅ tsk_deploy.json: OK
```

---

## Integration with Existing Systems

### Phase 7.1 Self-Review

```json
{
  "skill": "self_review",
  "args": ["--days=7"]
}
```

**Equivalent to:**
```bash
node agents/reflection/self_review.cjs --days=7
```

### ops_atomic.sh

```json
{
  "skill": "ops_atomic",
  "args": []
}
```

**Equivalent to:**
```bash
bash run/ops_atomic.sh
```

### Reportbot

```json
{
  "skill": "reportbot",
  "args": ["--type", "summary"]
}
```

**Equivalent to:**
```bash
node agents/reportbot/index.cjs --type summary
```

---

## Auto-Learning

Every task execution automatically:

**1. Writes Telemetry (NDJSON)**
```javascript
{
  "ts": "2025-10-20T18:54:13.166Z",
  "task": "local_exec",
  "pass": 1,
  "warn": 0,
  "fail": 0,
  "duration_ms": 24,
  "meta": {
    "id": "tsk_smoke",
    "title": "Smoke Test",
    "steps_count": 3,
    "acceptance_passed": true
  }
}
```

**2. Records Memory**
```javascript
{
  "kind": "solution",
  "text": "Phase 7.2 smoke test passed - delegation stack operational",
  "meta": {
    "id": "tsk_smoke",
    "duration_ms": 24
  },
  "importance": 0.5,    // Auto-calculated
  "queryCount": 0,      // Phase 6.5-B tracking
  "lastAccess": "2025-10-20T18:54:13.197Z"
}
```

**3. Generates Execution Log**
```json
{
  "status": "ok",
  "results": [
    {
      "step": "bash",
      "args": ["-c", "echo 'SMOKE_OK'"],
      "code": 0,
      "stdout": "SMOKE_OK\n",
      "stderr": ""
    }
  ],
  "acceptance": [
    {"rule": "Printed SMOKE_OK", "ok": true}
  ],
  "duration_ms": 24
}
```

This feeds into:
- Phase 7.1 Self-Review (analyzes telemetry)
- Phase 6.5-B Memory System (recalls similar situations)
- Future Phase 7.3 Proactive Suggestions

---

## Token Savings

### Before Phase 7.2 (Direct Execution)

**CLC receives full context:**
```
User request: "Run weekly review"
↓
CLC thinks: [3000 tokens]
↓
CLC executes: bash scripts/review.sh
↓
Full execution output: [2000 tokens]
↓
Error traces, file contents: [1000 tokens]
↓
CLC responds: [500 tokens]
---
Total: ~6500 tokens
```

### After Phase 7.2 (Delegation)

**CLC writes tiny spec:**
```
User request: "Run weekly review"
↓
CLC thinks: [500 tokens]
↓
CLC writes: task JSON (200 chars)
↓
Local executes (no tokens)
↓
Result: "OK, duration 2.3s"
↓
CLC responds: [200 tokens]
---
Total: ~700 tokens (89% savings!)
```

---

## Testing

### Smoke Test

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
  "acceptance": ["Printed SMOKE_OK"],
  "memory": {"kind": "solution", "text": "Smoke test passed"}
}
JSON

# Execute
node agents/local/orchestrator.cjs --once --verbose
```

**Expected Output:**
```
🚀 Phase 7.2: Local Orchestrator & Delegation
Mode: ONCE
Verbose: ON

=== Local Orchestrator: Processing 1 task(s) ===

🔄 Executing: tsk_smoke.json
[skill] bash -c echo 'SMOKE_OK'
✅ tsk_smoke.json: OK

=== Processed 1 task(s) ===
```

**Verify:**
```bash
# Task moved to done
ls queue/done/tsk_smoke.json

# Telemetry written
tail -1 g/telemetry/*.log

# Memory recorded
node memory/index.cjs --recall "smoke test" --topK 1

# Execution log created
ls g/logs/local_*.json
```

### Policy Gate Test

```bash
# Create high-risk task
cp queue/examples/tsk_git_deploy.json queue/inbox/

# Should block
node agents/local/orchestrator.cjs --once
# Output: ❌ tsk_git_deploy.json: BLOCKED - approval_required

# Verify in failed/
ls queue/failed/tsk_git_deploy.json

# Approve and retry
LOCAL_ALLOW_HIGH=1 node agents/local/orchestrator.cjs --once
```

---

## Acceptance Criteria

✅ **All criteria met (2025-10-20)**

- [x] `orchestrator.cjs` processes tasks from queue/inbox/
- [x] Policy gates block dangerous/high-risk tasks
- [x] `LOCAL_ALLOW_HIGH=1` approval flow works
- [x] Telemetry NDJSON written for each execution
- [x] Memory entries recorded on success/failure
- [x] Queue rotation: inbox → running → done/failed
- [x] Skills execute correctly (bash, node, git, http)
- [x] Built-in integrations work (ops_atomic, reportbot, self_review)
- [x] Execution logs generated in g/logs/
- [x] Smoke test passes
- [x] High-risk task blocked by policy
- [x] Optional steps don't fail task
- [x] Timeout handling works
- [x] Token savings demonstrated (89% reduction)

---

## Files Created

```
agents/local/
├── orchestrator.cjs       (352 lines) - Main executor
├── policy.cjs             (198 lines) - Risk gates
└── skills/
    ├── bash.sh            (33 lines)  - Safe bash
    ├── node.cjs           (29 lines)  - Node.js
    ├── git.sh             (63 lines)  - Safe git
    └── http.cjs           (113 lines) - HTTP requests

queue/
├── inbox/                 (new tasks)
├── running/               (executing)
├── done/                  (completed)
├── failed/                (blocked/failed)
└── examples/
    ├── tsk_weekly_review.json
    ├── tsk_health_check.json
    └── tsk_git_deploy.json

docs/
└── PHASE7_2_DELEGATION.md (this file)
```

---

## Future Enhancements

### Phase 7.3 - Advanced Features

- **Continuous mode daemon** - Run orchestrator as background service
- **Discord notifications** - Send results to Discord on DONE/FAILED
- **Task dependencies** - Wait for task A before starting task B
- **Retry logic** - Auto-retry failed tasks with exponential backoff
- **Task scheduling** - Cron-like scheduling within task spec
- **Parallel execution** - Run multiple tasks concurrently
- **Task templates** - Reusable task patterns with variables

### Phase 7.4 - Learning & Optimization

- **Success rate tracking** - Track which skills/tasks succeed most
- **Failure pattern detection** - Automatically detect recurring failures
- **Auto-optimization** - Suggest timeout adjustments based on history
- **Predictive risk scoring** - ML-based risk scoring from past executions
- **Smart approval** - Auto-approve low-risk patterns after N successes

---

## Related Documentation

- **Phase 7 Overview:** `docs/PHASE7_COGNITIVE_LAYER.md`
- **Phase 7.1 Self-Review:** `agents/reflection/self_review.cjs`
- **Memory System:** `docs/CONTEXT_ENGINEERING.md`
- **Telemetry:** `boss-api/telemetry.cjs`

---

**Last Updated:** 2025-10-20
**Maintained By:** CLC (Implementation) + Boss (Architecture)
**Status:** ✅ COMPLETE - Production Ready
**Version:** 1.0.0 (Phase 7.2 MVP)
