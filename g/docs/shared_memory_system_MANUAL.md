# Shared Memory System - User Manual

**Version:** 1.0.0  
**Date:** 2025-11-12  
**System:** 02luka Unified Shared Memory

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Agent Integration](#agent-integration)
4. [Usage Examples](#usage-examples)
5. [Monitoring & Metrics](#monitoring--metrics)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)
8. [Reference](#reference)

---

## Overview

The Shared Memory System enables all 02luka agents (GC, CLS, GPT/GG, Gemini) to share context, reduce token duplication, and coordinate work without redundant "alert" messages.

### Key Benefits

- **Token Savings:** 70-85% reduction in token usage
- **Agent Coordination:** All agents aware of each other's status
- **Unified Context:** Single source of truth for system state
- **No Redundancy:** Eliminates repeated context explanations

### System Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Shared Memory System                                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │ GC       │  │ CLS      │  │ GPT/GG   │            │
│  │ (Claude) │  │ (Cursor) │  │ (ChatGPT)│            │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘            │
│       │             │              │                  │
│       └─────────────┼──────────────┘                  │
│                     │                                  │
│              ┌──────▼──────┐                         │
│              │ Shared Memory │                         │
│              │ context.json  │                         │
│              └──────┬───────┘                          │
│                     │                                  │
│              ┌──────▼──────┐                         │
│              │ Bridge System │                         │
│              │ (inbox/outbox)│                         │
│              └──────────────┘                          │
│                     │                                  │
│              ┌──────▼──────┐                         │
│              │ Gemini      │                         │
│              │ (CLI)       │                         │
│              └──────────────┘                          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Initial Setup

```bash
# 1. Run setup script (one-time)
cd ~/02luka
./tools/setup_shared_memory.zsh

# 2. Verify installation
./tools/shared_memory_health.zsh

# Expected output: All ✅ checks pass
```

### Verify System Status

```bash
# Check health
./tools/shared_memory_health.zsh

# Check metrics
./tools/memory_metrics.zsh

# View shared context
./tools/memory_sync.sh get | jq .
```

---

## Agent Integration

### GC (Claude Desktop)

**Location:** `tools/gc_memory_sync.sh`

**Commands:**
- `update` - Update GC status to active
- `push <json>` - Push context data
- `get` - Get GC's shared context

**Usage:**
```bash
# Update status
~/02luka/tools/gc_memory_sync.sh update

# Push context
~/02luka/tools/gc_memory_sync.sh push '{"task":"current work","phase":2}'

# Get context
~/02luka/tools/gc_memory_sync.sh get
```

**Example Workflow:**
```bash
# Before starting work
~/02luka/tools/gc_memory_sync.sh update

# During work
~/02luka/tools/gc_memory_sync.sh push '{"current_task":"feature X","progress":50}'

# After completing work
~/02luka/tools/gc_memory_sync.sh push '{"completed":"feature X","result":"success"}'
```

---

### CLS (Cursor)

**Location:** `agents/cls_bridge/cls_memory.py`

**Functions:**
- `before_task()` - Load shared context
- `after_task(result)` - Update context and save results

**Usage:**
```python
from agents.cls_bridge.cls_memory import before_task, after_task

# Load context before task
context = before_task()
print(f"Current agents: {context.get('agents', {})}")
print(f"Current work: {context.get('current_work', {})}")

# Do your work...

# Save result after task
after_task({
    "task": "feature_implementation",
    "status": "completed",
    "result": "success",
    "details": "..."
})
```

**Example Workflow:**
```python
# In your Cursor script
from agents.cls_bridge.cls_memory import before_task, after_task

# Get context
ctx = before_task()

# Check what others are working on
if ctx.get('current_work', {}).get('task') == 'blocking_task':
    print("Waiting for blocking task to complete...")
    return

# Do work
result = implement_feature()

# Save result
after_task({
    "task": "feature_implementation",
    "result": result,
    "timestamp": datetime.now().isoformat()
})
```

---

### GPT/GG (ChatGPT)

**Location:** `agents/gpt_bridge/gpt_memory.py`

**Functions:**
- `get_context_for_gpt()` - Get formatted context for GPT system message
- `save_gpt_response(response)` - Save GPT response to shared memory

**Usage:**
```python
from agents.gpt_bridge.gpt_memory import GPTMemoryBridge

bridge = GPTMemoryBridge()

# Get context formatted for GPT
context = bridge.get_context_for_gpt()

# Use in GPT API call
response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[
        {"role": "system", "content": context},
        {"role": "user", "content": user_message}
    ]
)

# Save response
bridge.save_gpt_response(response.choices[0].message.content)
```

**Example Workflow:**
```python
from agents.gpt_bridge.gpt_memory import GPTMemoryBridge
import openai

bridge = GPTMemoryBridge()

# Get shared context
system_context = bridge.get_context_for_gpt()

# Make GPT call with context
response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[
        {"role": "system", "content": system_context},
        {"role": "user", "content": "What should I work on next?"}
    ]
)

answer = response.choices[0].message.content

# Save to shared memory
bridge.save_gpt_response(answer)
```

---

### Gemini

**Location:** `tools/gemini_memory_wrapper.sh`

**Usage:**
```bash
# Instead of: gemini-cli "your question"
# Use: gemini_memory_wrapper.sh "your question"

gemini_memory_wrapper.sh "What are we working on?"
```

**Features:**
- Automatically loads shared context
- Builds system prompt with agent status
- Updates memory after execution
- Transparent wrapper (same interface as gemini-cli)

**Example Workflow:**
```bash
# Ask Gemini with shared context
gemini_memory_wrapper.sh "What should I focus on next?"

# Gemini will see:
# - Active agents and their status
# - Current work being done
# - System context
```

---

## Usage Examples

### Example 1: Multi-Agent Coordination

**Scenario:** GC starts a task, CLS needs to know about it

```bash
# GC starts work
~/02luka/tools/gc_memory_sync.sh push '{"task":"database_migration","status":"in_progress"}'
```

```python
# CLS checks context
from agents.cls_bridge.cls_memory import before_task

context = before_task()
current_work = context.get('current_work', {})

if current_work.get('task') == 'database_migration':
    print("GC is doing database migration, waiting...")
    # Don't start conflicting work
```

---

### Example 2: Token Savings

**Before (without shared memory):**
```
GC: "I'm working on feature X, here's the context..."
CLS: "I'm working on feature X, here's the context..."
GPT: "I'm working on feature X, here's the context..."
Total: ~5000 tokens per task
```

**After (with shared memory):**
```
GC: "Update memory: working on feature X"
CLS: "Read memory: GC working on feature X"
GPT: "Read memory: GC working on feature X"
Total: ~1000 tokens per task
Savings: 80%
```

---

### Example 3: Context Sharing

**GC shares context:**
```bash
~/02luka/tools/gc_memory_sync.sh push '{
  "current_feature": "user_authentication",
  "progress": 75,
  "blockers": ["API key validation"],
  "next_steps": ["Add 2FA support"]
}'
```

**CLS reads context:**
```python
from agents.cls_bridge.cls_memory import before_task

context = before_task()
gc_context = context.get('agents', {}).get('gc', {}).get('context', {})

if gc_context.get('blockers'):
    print(f"GC blocked on: {gc_context['blockers']}")
    # Offer help or work around blockers
```

---

## Monitoring & Metrics

### Health Checks

```bash
# Run comprehensive health check
./tools/shared_memory_health.zsh

# Expected output:
# ✅ shared_memory exists
# ✅ context.json exists
# ✅ context.json valid JSON
# ✅ memory_sync.sh executable
# ✅ bridge_monitor.sh executable
# ✅ LaunchAgent: bridge loaded
# ✅ gc_memory_sync.sh executable
# ✅ cls_memory.py exists
# ✅ LaunchAgent: metrics loaded
# ✅ health passed
```

### Metrics Collection

**Manual Collection:**
```bash
./tools/memory_metrics.zsh

# Output:
# metrics: agents=4 total=1000 saved=700 (70%)
```

**Automatic Collection:**
- Metrics collected hourly via LaunchAgent
- Stored in: `metrics/memory_usage.ndjson`

**View Metrics:**
```bash
# View recent metrics
tail -10 metrics/memory_usage.ndjson | jq .

# Calculate average savings
cat metrics/memory_usage.ndjson | jq -s 'map(.saved_pct) | add / length'
```

### Bridge Activity

**Check Inbox:**
```bash
ls -lh bridge/memory/inbox/
```

**Check Processed:**
```bash
ls -lh bridge/memory/processed/
```

**Monitor Logs:**
```bash
# Bridge monitor log
tail -f logs/bridge_monitor.log

# Metrics log
tail -f logs/memory_metrics.out.log
```

---

## Troubleshooting

### Issue: Health Check Fails

**Symptoms:**
```bash
./tools/shared_memory_health.zsh
# ❌ shared_memory missing
```

**Solution:**
```bash
# Re-run setup
./tools/setup_shared_memory.zsh

# Verify
./tools/shared_memory_health.zsh
```

---

### Issue: GC Memory Sync Not Working

**Symptoms:**
```bash
~/02luka/tools/gc_memory_sync.sh update
# Error: memory_sync.sh not found
```

**Solution:**
```bash
# Check if Phase 1 is deployed
test -f ~/02luka/tools/memory_sync.sh && echo "✅ Exists" || echo "❌ Missing"

# If missing, deploy Phase 1
~/02luka/tools/setup_shared_memory.zsh
```

---

### Issue: CLS Bridge Import Error

**Symptoms:**
```python
from agents.cls_bridge.cls_memory import before_task
# ModuleNotFoundError
```

**Solution:**
```bash
# Check if module exists
test -f ~/02luka/agents/cls_bridge/cls_memory.py && echo "✅ Exists" || echo "❌ Missing"

# If missing, deploy Phase 2
~/02luka/tools/install_phase2_gc_cls.zsh
```

---

### Issue: Bridge Monitor Not Processing

**Symptoms:**
```bash
ls bridge/memory/inbox/*.json
# Files exist but not processed
```

**Solution:**
```bash
# Check LaunchAgent status
launchctl list | grep com.02luka.memory.bridge

# If not loaded, reload
launchctl unload ~/Library/LaunchAgents/com.02luka.memory.bridge.plist
launchctl load ~/Library/LaunchAgents/com.02luka.memory.bridge.plist

# Check logs
tail -20 logs/bridge_monitor.err.log
```

---

### Issue: Metrics Not Collecting

**Symptoms:**
```bash
ls metrics/memory_usage.ndjson
# File not updating
```

**Solution:**
```bash
# Check LaunchAgent
launchctl list | grep com.02luka.memory.metrics

# If not loaded, reload
launchctl unload ~/Library/LaunchAgents/com.02luka.memory.metrics.plist
launchctl load ~/Library/LaunchAgents/com.02luka.memory.metrics.plist

# Manual test
./tools/memory_metrics.zsh
```

---

### Issue: Context Not Updating

**Symptoms:**
```bash
./tools/memory_sync.sh get | jq '.agents.gc'
# Status not updating
```

**Solution:**
```bash
# Check file permissions
ls -l shared_memory/context.json

# Check if bridge monitor is processing
tail -10 logs/bridge_monitor.log

# Manual update test
./tools/memory_sync.sh update test_agent active
./tools/memory_sync.sh get | jq '.agents.test_agent'
```

---

## Best Practices

### 1. Update Status Regularly

**Good:**
```bash
# Update status when starting work
~/02luka/tools/gc_memory_sync.sh update

# Update context during work
~/02luka/tools/gc_memory_sync.sh push '{"progress": 50}'
```

**Bad:**
```bash
# Never updating status
# Other agents don't know you're working
```

---

### 2. Use Structured Context

**Good:**
```json
{
  "task": "feature_implementation",
  "progress": 75,
  "blockers": ["API key"],
  "next_steps": ["Add tests"]
}
```

**Bad:**
```json
{
  "note": "working on stuff"
}
```

---

### 3. Check Context Before Starting Work

**Good:**
```python
from agents.cls_bridge.cls_memory import before_task

context = before_task()
current_work = context.get('current_work', {})

if current_work.get('task') == 'blocking_task':
    # Wait or work around
    pass
```

**Bad:**
```python
# Starting work without checking context
# May conflict with other agents
```

---

### 4. Save Results After Tasks

**Good:**
```python
from agents.cls_bridge.cls_memory import after_task

result = do_work()
after_task({
    "task": "feature_implementation",
    "result": result,
    "status": "completed"
})
```

**Bad:**
```python
# Not saving results
# Other agents don't know what was done
```

---

### 5. Monitor Token Savings

**Good:**
```bash
# Check metrics regularly
./tools/memory_metrics.zsh

# Track savings over time
cat metrics/memory_usage.ndjson | jq -s 'map(.saved_pct) | add / length'
```

**Bad:**
```bash
# Not monitoring
# Don't know if system is working
```

---

## Reference

### File Locations

**Core System:**
- Shared Memory: `shared_memory/context.json`
- Bridge Inbox: `bridge/memory/inbox/`
- Bridge Outbox: `bridge/memory/outbox/`
- Bridge Processed: `bridge/memory/processed/`
- Metrics: `metrics/memory_usage.ndjson`

**Tools:**
- Memory Sync: `tools/memory_sync.sh`
- Bridge Monitor: `tools/bridge_monitor.sh`
- GC Helper: `tools/gc_memory_sync.sh`
- Metrics: `tools/memory_metrics.zsh`
- Health Check: `tools/shared_memory_health.zsh`
- Gemini Wrapper: `tools/gemini_memory_wrapper.sh`

**Bridges:**
- CLS Bridge: `agents/cls_bridge/cls_memory.py`
- GPT Bridge: `agents/gpt_bridge/gpt_memory.py`

**LaunchAgents:**
- Bridge Monitor: `~/Library/LaunchAgents/com.02luka.memory.bridge.plist`
- Metrics: `~/Library/LaunchAgents/com.02luka.memory.metrics.plist`

---

### Environment Variables

```bash
export LUKA_SOT="/Users/icmini/02luka"
export LUKA_HOME="/Users/icmini/02luka/g"
```

---

### Context Schema

```json
{
  "version": "1.0",
  "last_update": "2025-11-12T08:00:00+07:00",
  "agents": {
    "gc": {
      "status": "active",
      "last_seen": "2025-11-12T08:00:00+07:00",
      "context": {}
    },
    "cls": {
      "status": "active",
      "last_seen": "2025-11-12T08:00:00+07:00"
    },
    "gg": {
      "status": "active",
      "last_seen": "2025-11-12T08:00:00+07:00"
    },
    "gemini": {
      "status": "active",
      "last_seen": "2025-11-12T08:00:00+07:00"
    }
  },
  "current_work": {
    "task": "feature_implementation",
    "phase": 2,
    "progress": 75
  },
  "paths": {
    "sot": "/Users/icmini/02luka",
    "working": "/Users/icmini/02luka/g",
    "bridge": "/Users/icmini/02luka/bridge"
  },
  "token_usage": {
    "total": 1000,
    "saved": 700
  }
}
```

---

### Command Reference

**Memory Sync:**
```bash
# Update agent status
./tools/memory_sync.sh update <agent> <status>

# Get shared context
./tools/memory_sync.sh get
```

**GC Helper:**
```bash
# Update status
./tools/gc_memory_sync.sh update

# Push context
./tools/gc_memory_sync.sh push '<json>'

# Get context
./tools/gc_memory_sync.sh get
```

**Metrics:**
```bash
# Collect metrics
./tools/memory_metrics.zsh

# View metrics
cat metrics/memory_usage.ndjson | jq .
```

**Health:**
```bash
# Run health check
./tools/shared_memory_health.zsh
```

---

### SLO Targets

- **SLO-1:** Health check passes 100%
- **SLO-2:** Metrics written ≥ 1 record/hour
- **SLO-3:** Token saved/total ≥ 40% (Week 1), 70%+ (Week 2)

---

### Support

**Documentation:**
- SPEC: `g/reports/feature_shared_memory_*_SPEC.md`
- PLAN: `g/reports/feature_shared_memory_*_PLAN.md`
- Code Review: `g/reports/CODE_REVIEW_shared_memory_*.md`

**Rollback:**
- Phase 1: `tools/rollback_shared_memory.zsh`
- Phase 2: `tools/rollback_shared_memory_phase2.zsh`

---

**Last Updated:** 2025-11-12  
**Version:** 1.0.0

