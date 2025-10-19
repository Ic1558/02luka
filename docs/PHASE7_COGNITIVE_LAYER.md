# Phase 7: Autonomous Cognitive Layer (MVP Spec)

**Status:** SCAFFOLD - Implementation Roadmap
**Date:** 2025-10-20
**Prerequisites:** Phase 6 + 6.5-A + 6.5-B (Memory + Decay + Patterns)

---

## 1. Overview

Phase 7 transforms 02LUKA from a passive knowledge base into an **autonomous cognitive system** that:
- Reflects on its own performance
- Learns from experience autonomously
- Proactively suggests next actions
- Improves decision-making over time

**Core Principle:** *"Self-aware system that learns and suggests without manual intervention"*

---

## 2. Components

### 2.1 Self-Reflection Engine (`agents/reflection/self_review.cjs`)

**Purpose:** Analyze recent system performance and generate insights

**Inputs:**
- Telemetry logs (`g/telemetry/*.log`)
- Memory index (`g/memory/vector_index.json`)
- Time period (default: 7 days)

**Outputs:**
- Markdown report (`g/reports/self_review_[timestamp].md`)
- Insight memories (auto-recorded)

**Key Functions:**
```javascript
analyzeTelemetry(days)      // Parse telemetry, extract trends
queryRelevantMemories(ctx)   // Find similar past situations
generateInsights(tel, mem)   // Create actionable insights
recordInsights(insights)     // Store as memory entries
```

**Success Criteria:**
- [ ] Parses telemetry NDJSON format correctly
- [ ] Detects improving/stable/declining trends
- [ ] Generates ≥3 insights per review
- [ ] Insight confidence scores >0.5
- [ ] Insights recorded as memories

---

### 2.2 Proactive Suggestions Engine (`agents/suggestions/proactive.cjs`)

**Purpose:** Suggest next actions based on context and patterns

**Inputs:**
- Context description (user-provided or auto-detected)
- Current system state (memory stats, telemetry health)
- Pattern library (from `discoverPatterns()`)

**Outputs:**
- JSON array of suggestions with:
  - `action`: What to do
  - `reason`: Why to do it
  - `confidence`: 0.0-1.0 score
  - `priority`: high/medium/low
  - `command`: Executable command

**Key Functions:**
```javascript
analyzeContext(desc)         // Understand current situation
querySimilarSituations(ctx)  // Find relevant memories
discoverActionPatterns()     // Extract "if X then Y" rules
generateSuggestions(...)     // Create prioritized suggestions
```

**Success Criteria:**
- [ ] Returns ≥2 suggestions for common contexts
- [ ] Confidence scores correlate with accuracy
- [ ] Prioritization matches urgency/impact
- [ ] Commands are executable (valid syntax)
- [ ] Reasoning is clear and specific

---

### 2.3 Integration Points

**Memory System:**
```javascript
// Record insights automatically
memoryModule.remember({
  kind: 'insight',
  text: '[Self-Review] System performance stable over 7 days',
  meta: { confidence: 0.85, source: 'self_review' }
});

// Query for similar situations
const similar = memoryModule.recall({
  query: context.description,
  kind: 'solution',
  topK: 5
});
```

**Telemetry System:**
```javascript
// Read telemetry logs
const logs = fs.readdirSync(TELEMETRY_DIR)
  .filter(f => f.endsWith('.log'))
  .map(f => parseTelemetryLog(path.join(TELEMETRY_DIR, f)));

// Extract metrics
const metrics = {
  totalRuns: logs.length,
  successRate: logs.filter(l => l.status === 'pass').length / logs.length,
  avgDuration: avg(logs.map(l => l.duration))
};
```

**Pattern Discovery:**
```javascript
// Use existing pattern detection
const patterns = memoryModule.discoverPatterns({
  n: 2,
  minOccurrences: 3,
  topK: 10
});

// Extract action sequences
const actionPatterns = patterns
  .filter(p => p.pattern.includes('deploy') || p.pattern.includes('fix'))
  .map(p => ({ ...p, actionable: true }));
```

---

## 3. MVP Implementation Plan

### Phase 7.1: Self-Review (Week 1)

**Tasks:**
1. Implement telemetry parsing (NDJSON → structured data)
2. Build trend detection (improving/stable/declining)
3. Implement insight generation logic
4. Create markdown report template
5. Wire to memory system for auto-recording

**Acceptance:**
- `node agents/reflection/self_review.cjs` generates valid report
- Report includes: telemetry summary, trends, insights, recommendations
- High-confidence insights (>0.7) recorded as memories
- No manual intervention required

---

### Phase 7.2: Proactive Suggestions (Week 2)

**Tasks:**
1. Implement context analysis (keyword extraction, intent detection)
2. Build memory query logic (find similar past situations)
3. Implement suggestion generation with confidence scoring
4. Add priority calculation (impact × urgency)
5. Create JSON output format

**Acceptance:**
- `node agents/suggestions/proactive.cjs --context="text"` returns suggestions
- Suggestions ranked by priority and confidence
- Commands are executable and safe
- Reasoning is clear and data-driven

---

### Phase 7.3: Automation & Slash Commands (Week 3)

**Tasks:**
1. Create `/reflect` slash command → runs self-review
2. Create `/suggest` slash command → runs proactive suggestions
3. Add scheduled self-review (weekly via LaunchAgent)
4. Implement suggestion notifications (Discord integration)
5. Build feedback loop (track suggestion outcomes)

**Acceptance:**
- `/reflect` generates report and notifies via Discord
- `/suggest <context>` returns suggestions in chat
- Weekly self-review runs automatically
- Suggestion outcomes tracked for learning

---

## 4. Example Workflows

### 4.1 Self-Review Workflow

```bash
# Manual review
$ node agents/reflection/self_review.cjs --days=7

=== Self-Review Engine ===

Analyzing last 7 days...

Telemetry Analysis:
- Total runs: 42
- Success rate: 95.2%
- Trend: STABLE ✅

Relevant Memories:
1. [solution] Fixed macOS date command...
2. [insight] TF-IDF better than word count...

Insights Generated:
1. OBSERVATION: System stable with 95% success rate
   Confidence: 90%
   Actionable: No

2. SUGGESTION: Consider decay to reduce memory bloat
   Confidence: 75%
   Actionable: Yes
   Action: node memory/index.cjs --decay --halfLife 60

✅ Report saved: g/reports/self_review_2025-10-20.md
✅ Recorded 2 insights

=== Complete ===
```

### 4.2 Proactive Suggestions Workflow

```bash
# Get suggestions for context
$ node agents/suggestions/proactive.cjs --context="preparing for deployment"

{
  "context": "preparing for deployment",
  "suggestions": [
    {
      "action": "Run full smoke test suite",
      "reason": "Past deployments with smoke tests had 98% success rate",
      "confidence": 0.92,
      "priority": "high",
      "command": "bash run/smoke_api_ui.sh"
    },
    {
      "action": "Verify memory health",
      "reason": "Pattern: deployments preceded by cleanup had fewer issues",
      "confidence": 0.78,
      "priority": "medium",
      "command": "node memory/index.cjs --stats"
    }
  ],
  "metadata": {
    "memoriesQueried": 5,
    "patternsFound": 3,
    "suggestionsGenerated": 2
  }
}
```

---

## 5. Data Sources & Requirements

### Required Data

**Telemetry Logs:**
- Format: NDJSON (one JSON object per line)
- Location: `g/telemetry/*.log`
- Fields: `task`, `status`, `pass`, `warn`, `fail`, `duration`, `timestamp`

**Memory Index:**
- Format: JSON
- Location: `g/memory/vector_index.json`
- Fields: `id`, `kind`, `text`, `importance`, `queryCount`, `lastAccess`

**Pattern Library:**
- Generated: via `discoverPatterns()`
- Extracted: bigrams, trigrams with occurrence counts
- Used for: detecting recurring action sequences

---

## 6. Metrics & Success Criteria

### Phase 7 MVP Success

| Criterion | Target | Measurement |
|-----------|--------|-------------|
| Self-review accuracy | >80% | Manual validation of insights |
| Suggestion relevance | >70% | User feedback (helpful/not) |
| Automation success | >95% | Scheduled runs complete without errors |
| Insight recording | 100% | All high-confidence insights stored |
| Response time | <5s | Time to generate suggestions |

### Learning Effectiveness

**Track over time:**
- Suggestion acceptance rate (how often followed)
- Outcome correlation (did it help?)
- Confidence calibration (does 0.8 confidence = 80% success?)
- Pattern accuracy (do discovered patterns hold?)

---

## 7. Future Enhancements (Post-MVP)

### Phase 7.5: Advanced Learning

- **Reinforcement from outcomes:** Track suggestion results, boost confidence of successful patterns
- **Cross-agent learning:** Share insights between GG, CLC, Codex, Cursor
- **Anomaly detection:** Flag unusual patterns before they become problems
- **Causal reasoning:** Understand "X caused Y" relationships

### Phase 8: Fully Autonomous

- **Self-healing:** Automatically fix detected issues
- **Proactive optimization:** Tune system parameters without intervention
- **Strategic planning:** Generate multi-step plans for complex goals
- **Meta-learning:** Learn how to learn better (improve own algorithms)

---

## 8. Scaffold Status (Current)

### Completed (Phase 7 MVP Scaffold)

- ✅ `agents/reflection/self_review.cjs` structure
- ✅ `agents/suggestions/proactive.cjs` structure
- ✅ Memory integration hooks
- ✅ Placeholder logic with TODOs
- ✅ CLI interfaces
- ✅ Export modules for testing

### Remaining for Full MVP

- [ ] Telemetry parsing implementation
- [ ] Trend detection algorithms
- [ ] Insight generation logic
- [ ] Confidence scoring implementation
- [ ] Suggestion prioritization
- [ ] Integration testing
- [ ] Documentation updates
- [ ] Slash command wiring

---

## 9. Testing Plan

### Unit Tests

```javascript
// Test telemetry parsing
const telemetry = parseTelemetryLog('g/telemetry/20251020.log');
assert(telemetry.length > 0);
assert(telemetry[0].task === 'smoke_api_ui');

// Test insight generation
const insights = generateInsights(telemetryData, memories);
assert(insights.every(i => i.confidence >= 0 && i.confidence <= 1));
assert(insights.every(i => i.text.length > 10));
```

### Integration Tests

```bash
# Test full self-review
node agents/reflection/self_review.cjs --days=7
# Verify report created
# Verify insights recorded in memory

# Test proactive suggestions
node agents/suggestions/proactive.cjs --context="deployment"
# Verify JSON output valid
# Verify suggestions have required fields
# Verify commands are executable
```

### Acceptance Tests

```bash
# Scenario: System performance review
1. Run telemetry tasks for 7 days
2. Execute self-review
3. Verify insights match expected patterns
4. Confirm high-confidence insights recorded

# Scenario: Proactive deployment help
1. Provide context "preparing for deployment"
2. Get suggestions
3. Execute suggested commands
4. Verify suggestions were helpful (manual validation)
```

---

## 10. Related Documentation

- **Memory System:** `docs/CONTEXT_ENGINEERING.md`
- **Memory Hooks:** `docs/MEMORY_HOOKS_SETUP.md`
- **Telemetry:** `g/reports/telemetry_last24h.md`
- **Cognitive Model:** `g/concepts/PHASE6_COGNITIVE_MODEL.md`
- **Phase 6 Report:** `g/reports/OPS_PHASE6_VECTOR_MEMO_SUMMARY.md`

---

## 11. Acceptance Checklist

**MVP Ready When:**
- [ ] `self_review.cjs` generates accurate reports from real telemetry
- [ ] `proactive.cjs` returns relevant suggestions (>70% helpful)
- [ ] Insights auto-recorded in memory
- [ ] Suggestions have valid confidence scores
- [ ] Commands are executable and safe
- [ ] Documentation complete
- [ ] Integration tests pass
- [ ] User validation positive

**Production Ready When:**
- [ ] All MVP criteria met
- [ ] Scheduled automation working
- [ ] Slash commands integrated
- [ ] Feedback loop implemented
- [ ] Metrics tracked over 2+ weeks
- [ ] Suggestion acceptance rate >60%
- [ ] Zero unhandled errors in logs

---

**Last Updated:** 2025-10-20
**Maintained By:** CLC (Implementation) + GG (Strategy)
**Status:** SCAFFOLD - Awaiting Full Implementation
**Version:** 0.1.0 (MVP Spec)
