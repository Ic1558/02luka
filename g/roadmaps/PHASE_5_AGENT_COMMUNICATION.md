# Phase 5: Agent Communication Architecture

**Created:** 2025-11-05
**Status:** Planning
**Goal:** Enable multi-agent coordination for autonomous workflows

---

## 🎯 Vision

Enable agents to work together autonomously:
1. Scanner detects new expense slip
2. Autopilot approves OCR request
3. OCR Worker extracts text
4. Ollama Worker categorizes
5. All agents coordinate without human intervention

---

## 📋 Current Agent Landscape

### Existing Agents

**Intelligence/Planning:**
1. **Scanner** (`tools/local_truth_scan.zsh`)
   - Runs daily at 9 AM
   - Analyzes local data
   - Generates priority recommendations
   - Output: JSON reports, HTML digest

2. **Autopilot** (`agents/rd_autopilot/rd_autopilot.zsh`)
   - Runs every 15 minutes
   - Approves/escalates WO requests
   - Policy-based decision making
   - Input: JSON WO requests in `bridge/outbox/RD/`
   - Output: Approved WOs to `bridge/inbox/LLM/`

**Execution:**
3. **WO Executor** (`agents/wo_executor/wo_executor.zsh`)
   - Runs every 15 minutes (on-demand via WatchPaths)
   - Executes .zsh scripts
   - Input: WO scripts in `bridge/inbox/LLM/`
   - Output: Execution logs, MLS lessons

4. **JSON WO Processor** (`agents/json_wo_processor/`)
   - Processes JSON work orders
   - Local execution
   - Input: JSON WOs in `bridge/inbox/LLM/`
   - Output: Result JSON

**Specialized Workers:**
5. **Ollama Worker** (new concept)
   - AI categorization service
   - Currently: Called directly by OCR script
   - Future: Standalone service accepting requests

---

## 🔄 Current Communication Patterns

### Pattern 1: File-based Queue (Autopilot → Executor)
- **How:** Autopilot writes .zsh files to `bridge/inbox/LLM/`
- **Trigger:** WO Executor picks up via WatchPaths
- **Feedback:** None (fire-and-forget)
- **Status:** ✅ Working (4 WOs executed successfully)

### Pattern 2: Direct Function Call (OCR → Ollama)
- **How:** OCR script calls `ollama_categorize.zsh` directly
- **Trigger:** During OCR execution
- **Feedback:** Synchronous return value
- **Status:** ✅ Working (tested with real slip)

### Pattern 3: Schedule-based Polling (Scanner)
- **How:** Scanner runs on schedule, writes reports
- **Trigger:** Time-based (daily at 9 AM)
- **Feedback:** None (human reviews reports)
- **Status:** ✅ Working

---

## 🏗️ Proposed Architecture

### Message Passing System

**Core Concept:** Lightweight JSON-based message queue

```
bridge/
├── inbox/           # Incoming requests for agents
│   ├── scanner/     # Work for scanner
│   ├── autopilot/   # Work for autopilot
│   ├── ollama/      # Work for AI worker
│   ├── ocr/         # Work for OCR worker
│   └── executor/    # Work for executor
├── outbox/          # Outgoing results from agents
│   ├── scanner/
│   ├── autopilot/
│   ├── ollama/
│   └── ocr/
└── archive/         # Completed workflows
    └── chains/      # Full execution chains
```

### Message Format

```json
{
  "id": "CHAIN-20251105-001",
  "type": "expense_import",
  "status": "pending|in_progress|completed|failed",
  "created_at": "2025-11-05T08:00:00Z",
  "updated_at": "2025-11-05T08:01:23Z",
  "from_agent": "scanner",
  "to_agent": "autopilot",
  "payload": {
    "slip_path": "/path/to/slip.jpg",
    "priority": "normal"
  },
  "chain": [
    {
      "agent": "scanner",
      "status": "completed",
      "output": { "slip_detected": true }
    },
    {
      "agent": "autopilot",
      "status": "in_progress",
      "input": { "cost_estimate": 0.05 }
    }
  ]
}
```

---

## 🎬 Proof of Concept: Expense Import Chain

### Goal
Fully autonomous expense processing from slip detection to categorized ledger entry.

### Workflow

```
Scanner Detects Slip
        ↓
    (writes message to bridge/inbox/autopilot/)
        ↓
Autopilot Reviews Request
        ↓
    (writes message to bridge/inbox/ocr/)
        ↓
OCR Worker Extracts Text
        ↓
    (writes message to bridge/inbox/ollama/)
        ↓
Ollama Worker Categorizes
        ↓
    (writes final result to bridge/outbox/)
        ↓
System Updates Ledger
```

### Implementation Steps

1. **Create Message Bus** (`tools/message_bus.zsh`)
   - `send_message(to_agent, payload)`
   - `read_messages(agent_name)`
   - `mark_complete(message_id)`

2. **Modify Scanner** (add message sending)
   - Detect new slips
   - Send expense_import message to autopilot

3. **Modify Autopilot** (add message receiving)
   - Read expense_import messages
   - Approve/escalate
   - Send approved to OCR queue

4. **Create OCR Worker Agent**
   - Read OCR messages
   - Execute Tesseract
   - Send result to Ollama queue

5. **Create Ollama Worker Agent**
   - Read categorization messages
   - Call `ollama_categorize.zsh`
   - Send categorized result back

6. **Integration Testing**
   - Drop slip in inbox
   - Verify full chain executes
   - Check ledger updated correctly

---

## 📊 Success Metrics

**Phase 5 Complete When:**
- [ ] Message passing system working
- [ ] Scanner → Autopilot chain works
- [ ] Autopilot → OCR → Ollama chain works
- [ ] Full expense import runs end-to-end
- [ ] Chain takes < 2 minutes start-to-finish
- [ ] Error handling graceful (retry logic)
- [ ] MLS captures coordination patterns

---

## 🚧 Challenges & Solutions

### Challenge 1: Race Conditions
**Problem:** Multiple agents may try to process same message

**Solution:** Atomic file locks using `flock` or message status flags

### Challenge 2: Error Propagation
**Problem:** If OCR fails, how does chain recover?

**Solution:** Dead letter queue + retry with exponential backoff

### Challenge 3: Monitoring
**Problem:** How to track chain progress?

**Solution:** Chain ID tracking + dashboard view of active chains

---

## 🎓 Design Principles

1. **Keep it Simple:** File-based messaging (no databases)
2. **Fail Gracefully:** Every agent handles missing inputs
3. **Observable:** Every step logged, trackable
4. **Reversible:** Easy to disable/debug individual agents
5. **Incremental:** Build one chain link at a time

---

## 📅 Timeline

**Week 1 (Nov 5 - In Progress):**
- ✅ Design architecture (this document) - Complete
- ✅ Build message bus utility - Complete, tested, working
- ⏳ Modify Scanner to send messages - Next task
- ⏳ Create chain_status.zsh monitoring tool

**Week 2:**
- Modify Autopilot to receive/send
- Create OCR worker agent
- Test Scanner → Autopilot → OCR

**Week 3:**
- Create Ollama worker agent
- Test full chain end-to-end
- Add error handling & retries

**Week 4:**
- Monitoring & observability
- Dashboard integration
- Production deployment

---

## 🔧 Quick Start

```bash
# Test message bus (WORKING)
~/02luka/tools/message_bus.zsh send autopilot expense_import \
  '{"slip_path":"/path/to/slip.jpg","priority":"normal"}' scanner

~/02luka/tools/message_bus.zsh read autopilot pending

# Update status
~/02luka/tools/message_bus.zsh update <msg_id> autopilot in_progress reviewing

# Forward to next agent
~/02luka/tools/message_bus.zsh forward <msg_id> autopilot ocr approved

# Mark complete
~/02luka/tools/message_bus.zsh complete <msg_id> ocr success

# View system status
~/02luka/tools/message_bus.zsh list

# Monitor chains (tool coming soon)
~/02luka/tools/chain_status.zsh
```

---

**Status:** ✅ Message bus operational, Week 1 in progress
**Risk:** Low (file-based, reversible, fully tested)
**Impact:** High (enables autonomous workflows)
**Next:** Create chain_status.zsh, then modify Scanner
**Documentation:** `/Users/icmini/02luka/g/reports/MESSAGE_BUS_IMPLEMENTATION_20251105.md`
