# Context Engineering Protocol v3.2 - Quick Reference

**Version:** 3.2.0
**Last Updated:** 2025-11-17
**Full Protocol:** `CONTEXT_ENGINEERING_PROTOCOL_v3.md`
**Machine-Readable:** `CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json`
**Why:** `02LUKA_PHILOSOPHY.md`

---

## 🎯 Key Principle (Invariant)

> **"Gemini writes non‑locked zones via patch. CLC writes privileged zones. Codex thinks. LPE transcribes."**

---

## 📊 Capability Matrix (At-a-Glance)

| Agent | Think | Write SOT | Scope | Approval | Token Limit |
|-------|-------|-----------|-------|----------|-------------|
| **GG** | ✅ MUST (strategic) | ✅ CAN (governance only) | Governance docs, policy | Self (Boss oversight) | N/A |
| **GC** | ✅ MUST (tactical) | ✅ CAN (specs, PRPs) | Implementation specs | GG approval | N/A |
| **CLC** | ✅ MUST (operational) | ✅ CAN (code, configs) | Privileged/locked zones | Self-approved | Configurable Budget |
| **Gemini** | ✅ MUST (operational) | ✅ CAN (via patch) | Operational code (non-locked) | Self-approved (patch) | Subscription Quota |
| **Cursor AI (Liam/Andy/CLS)** | ✅ CAN (analysis) | ⚠️ MAY (override) | Code suggestions, small fixes | Boss override for writes | N/A |
| **LPE** | ❌ MUST NOT | ✅ CAN (fallback only) | Boss-dictated writes | Boss approval | N/A |
| **Kim** | ✅ CAN (routing) | ❌ MUST NOT | Task coordination | N/A | N/A |

---

## 🗺️ Zone Rules

### ✅ Allowed Zones (Normal Dev Work)

- `apps/**`, `server/**`, `schemas/**`, `scripts/**`, `tools/**`
- `tests/**`, `docs/**` (except core governance)
- `agents/**` (documentation/definitions only)
- `reports/**`, `g/reports/**` (non-SOT, dev reports only)

### ❌ Locked Zones (Require CLC or Boss Override)

- `/CLC/**`, `/CLS/**` (core protocols)
- `/core/governance/**`
- `memory_center/**`, `memory/**` (SOT)
- `launchd/**` (system LaunchAgents SOT)
- `bridge/**` (production bridges & pipelines)
- `wo_pipeline_core/**`

---

## 🔄 Fallback Decision Tree

```text
┌─────────────────────────────────────┐
│ Smart Writer Unavailable?           │
│ (Gemini/CLC out of tokens or down)  │
└──────────────┬──────────────────────┘
               ↓
     ┌─────────────────────┐
     │ Is this urgent?     │
     └─────┬───────────┬───┘
           │           │
          YES         NO
           │           │
           ↓           ↓
    ┌──────────┐  ┌────────────────┐
    │ Use LPE  │  │ Wait for new   │
    │ Fallback │  │ Smart Writer   │
    │          │  │ session        │
    └──────────┘  └────────────────┘
           │
           ↓
    ┌──────────────────────────┐
    │ LPE Fallback Protocol:   │
    │ 1. Boss dictates change  │
    │ 2. LPE writes (no think) │
    │ 3. Log to MLS            │
    │ 4. Next CLC reviews      │
    └──────────────────────────┘
```

### Emergency Override (CursorAI/Codex)

**Trigger:**

- CLC/Gemini unavailable AND Boss explicit authorization
- Commands: `"REVISION-PROTOCOL → Liam do"` or `"Use Cursor to apply this patch now"`

**Scope:**

- Protocol/documentation updates
- Small, localized code/script fixes
- Non-destructive config changes

**Requirements:**

- Commit tag: `EMERGENCY_LIAM_WRITE`
- MLS log with Boss approval
- CLC must review when available

---

## 🔀 Context Flow Patterns

### Normal Operation (Gemini Active)

```text
Boss request
    ↓
Gemini receives + validates
    ↓
Gemini thinks + plans
    ↓
Gemini writes code/docs (via patch)
    ↓
Gemini commits to git
    ↓
Gemini reports to Boss
    ↓
MLS captures learnings
```

### Codex Suggests Change

```text
Codex provides suggestion
    ↓
Boss decides what to implement
    ↓
IF Gemini/CLC available:
    → Delegate to Gemini/CLC
    → Write + commit
    → MLS: "Codex suggestion implemented by [agent]"
ELSE:
    → Boss uses LPE fallback
    → Boss dictates to LPE
    → MLS: "Codex suggestion via LPE (unavailable)"
```

### GG → GC → Gemini Cascade

```text
GG decides: "We need feature X"
    ↓
GG → GC: "Create implementation spec"
    ↓
GC writes spec + PRP
    ↓
GC → Gemini: "Implement according to spec"
    ↓
Gemini executes implementation
    ↓
Gemini → GC: "Implementation complete"
    ↓
GC reviews + approves
    ↓
GG validates governance compliance
```

---

## 🛡️ Enforcement Mechanisms

### Git Pre-Commit Hook

- **Location:** `.git/hooks/pre-commit`
- **Checks:**
  - Tag CursorAI/Codex commits (warning, not hard block)
  - Validate LaunchAgent scripts exist
  - Verify MLS logging (optional)

### Token Budget Monitoring (CLC)

| Tokens | Action | Rule |
|--------|--------|------|
| < 150K | Normal | CLC MAY continue |
| 150K - 180K | Warning | CLC SHOULD warn Boss |
| 180K - 190K | Alert | CLC MUST alert Boss |
| 190K+ | Fallback | CLC MUST prepare LPE fallback |

### MLS Audit Trail

**Required for all SOT writes:**

- Who (agent)
- When (ISO 8601 timestamp)
- What (file path + content hash)
- Why (reason/context)
- Approval (Boss approval if LPE)

**Query Interface:**

```bash
node ~/02luka/knowledge/index.cjs --hybrid "query"
```

---

## 🚨 Common Scenarios

### Scenario 1: Which Agent Can Write to `/tools`?

**Answer:** Gemini (primary), CLC (if locked zone), CursorAI/Codex (with Boss override)

### Scenario 2: Codex Suggests Fix, Gemini Unavailable

**Answer:**

1. Try CLC
2. If CLC unavailable → LPE fallback (Boss dictates)
3. Log to MLS with approval

### Scenario 3: Need to Update Protocol Document

**Answer:**

- Normal: Gemini (via patch, Safety-Belt Mode)
- Emergency: CursorAI/Codex (with Boss override, tag `EMERGENCY_LIAM_WRITE`)
- Locked: CLC only

### Scenario 4: Large Refactor Across Multiple Files

**Answer:**

- Gemini (primary, use Safety-Belt Mode: phase-based patches)
- If token limit → LPE fallback for remaining phases
- CLC reviews all changes

---

## 📖 Agent Naming Clarification

- **Cursor AI** = Liam / Andy / CLS running in the Cursor AI pane (Layer 4, analysis; backed by Claude 3.5 Haiku).
- **Codex IDE** = OpenAI Codex extension inside Cursor (separate from Cursor AI). Used mainly for big refactors / generation; produces patches that CLC/Gemini/LPE apply.
- **Gemini** = Gemini Code Assist (Layer 4.5, primary operational writer)
- **CLC** = Privileged Writer (Layer 3, locked zones)
- **LPE** = Local Prompt Executor (Layer 5, fallback only)

---

## 🔍 Quick Queries (Use JSON Schema)

For programmatic queries, use `CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json`:

```bash
# Which agent can modify /tools?
jq '.agents[] | select(.write_zones[]? == "non_locked_zones" or .write_scope[]? == "operational_code") | .name' schema.json

# Which zones are locked?
jq '.zones.locked_zones' schema.json

# Fallback chain when Gemini unavailable?
jq '.fallback_ladder.fallback_chain' schema.json
```

---

**For full details, see:** `CONTEXT_ENGINEERING_PROTOCOL_v3.md`
