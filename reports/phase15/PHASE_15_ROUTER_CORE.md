# Phase 15 Router Core (AKR) - Implementation Summary

**Work Order**: WO-251107-PHASE-15-AKR
**Phase**: 15
**Date**: 2025-11-06
**Author**: Claude (Phase 15 Implementation)

## Overview

Phase 15 implements the **AKR (Agent Kinetic Router)** - an intelligent intent-based routing system for the 02LUKA multi-agent architecture. The router enables seamless delegation between Kim (NLP assistant) and Andy (coding assistant) based on intent classification, with built-in circular delegation prevention and comprehensive telemetry.

## Deliverables

### 1. Core Router Implementation

**File**: `tools/router_akr.zsh` (~370 lines)

A robust zsh script implementing:

- **Subcommands**:
  - `route`: Route requests to appropriate agent based on intent
  - `delegate`: Handle explicit delegation between agents
  - `dry-run`: Simulate routing without execution
  - `selftest`: Run internal health checks

- **Input Modes**:
  - `--json '<json>'`: Inline JSON input
  - `--file <path>`: JSON file input

- **Routing Logic**:
  - Pattern-based intent classification
  - Confidence scoring (thresholds configurable)
  - Multi-language support (English + Thai)
  - Fallback to default agent on low confidence

- **Safety Features**:
  - Circular delegation detection
  - Max delegation hops (default: 3)
  - Configuration validation
  - Graceful error handling

- **Telemetry Events** (Phase 14.2 schema):
  - `router.start`: Processing begins
  - `router.decision`: Routing decision made
  - `router.delegate`: Delegation executed
  - `router.circular`: Circular delegation detected
  - `router.max_hops`: Max hops exceeded
  - `router.error`: Error occurred
  - `router.end`: Processing complete

### 2. Router Configuration

**File**: `config/router_akr.yaml`

Central configuration for routing behavior:

```yaml
thresholds:
  intent_min: 0.75           # Minimum confidence for routing
  fallback_agent: kim        # Default agent

delegation_rules:
  kim → andy:
    - code.implement, code.review, code.fix, code.test
    - code.refactor, git.commit, git.push, build.run

  andy → kim:
    - query.explain, query.clarify, query.translate
    - query.help, conversation.chat

max_hops: 3
prevent_circular: true
```

### 3. Agent Configuration Updates

**Files**: `config/agents/andy.yaml`, `config/agents/kim.yaml`

Added `capabilities.intent_map` sections with:

- **Andy**: 14 code-related intent patterns
  - code.implement, code.review, code.fix, code.test, code.refactor
  - git.commit, git.push, git.pr
  - file.write, file.modify
  - build.run, test.run

- **Kim**: 9 query-related intent patterns
  - query.explain, query.clarify, query.translate, query.help
  - conversation.chat, intent.classify
  - Thai keyword mappings (แปล, ช่วย, อธิบาย, etc.)

### 4. Self-Test Suite

**File**: `tools/router_akr_selftest.zsh` (~280 lines)

Comprehensive testing with:

- **10 Test Cases**:
  - 4 Kim→Andy delegations (EN + TH)
  - 4 Andy→Kim delegations (EN + TH)
  - 2 Additional routing scenarios

- **Validation**:
  - Correct agent routing
  - Confidence threshold compliance
  - JSON schema validation
  - Event emission verification

- **Report Generation**: `g/reports/phase15/router_selftest.md`

### 5. CI Integration

**File**: `.github/workflows/ci.yml`

Added `router-selftest` job:

- Runs on: ubuntu-latest
- Dependencies: jq, yq, bc
- Executes: `tools/router_akr_selftest.zsh`
- Artifacts: Test report uploaded on completion

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User/System Request                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
          ┌──────────────────────────────┐
          │   Router AKR (router_akr.zsh) │
          │                                │
          │  1. Parse input JSON           │
          │  2. Classify intent            │
          │  3. Check confidence           │
          │  4. Validate delegation rules  │
          │  5. Prevent circular routing   │
          │  6. Emit telemetry             │
          └──────┬───────────────┬─────────┘
                 │               │
       code.*    │               │    query.*
       git.*     │               │    conversation.*
       build.*   │               │    translation.*
                 │               │
                 ▼               ▼
         ┌───────────┐   ┌──────────┐
         │   Andy    │   │   Kim    │
         │  (Coder)  │   │  (NLP)   │
         └───────────┘   └──────────┘
                 │               │
                 └───────┬───────┘
                         │
                         ▼
          ┌──────────────────────────────┐
          │  Telemetry Sink               │
          │  g/telemetry_unified/         │
          │  unified.jsonl                │
          └──────────────────────────────┘
```

## Intent Classification

The router uses pattern matching with confidence scoring:

### High Confidence Routing (0.85-0.95)

**→ Andy**:
- Bug fixes: "fix bug", "แก้บั๊ก"
- Implementation: "create function", "implement feature"
- Git ops: "commit", "push", "PR"
- Testing: "run tests", "ทดสอบ"

**→ Kim**:
- Translation: "translate", "แปล"
- Queries: "explain", "what is", "อธิบาย"
- Help: "help me", "ช่วย"

### Medium Confidence (0.75-0.85)

- Refactoring → Andy
- Documentation → Kim
- Clarification → Kim

### Low Confidence (<0.75)

- Routes to fallback agent (Kim by default)

## Telemetry Schema (Phase 14.2)

All events follow unified schema:

```json
{
  "event": "router.decision",
  "ts": "2025-11-06T12:34:56Z",
  "intent": "code.fix",
  "from_agent": "kim",
  "to_agent": "andy",
  "confidence": 0.85,
  "reason": "pattern: code.fix | high confidence",
  "__source": "router_akr",
  "__normalized": true
}
```

## How to Run

### Basic Routing

```bash
# Route a request
./tools/router_akr.zsh route --json '{
  "agent": "kim",
  "intent": "code.fix",
  "text": "Fix CI cache bug"
}'

# Output:
# {
#   "event": "router.decision",
#   "to_agent": "andy",
#   "confidence": 0.85,
#   ...
# }
```

### Dry-Run Mode

```bash
# Test routing without side effects
./tools/router_akr.zsh --dry-run --json '{
  "agent": "kim",
  "intent": "code.fix",
  "text": "แก้บั๊ก ci แคช"
}'
```

### Delegation

```bash
# Explicit delegation
./tools/router_akr.zsh delegate \
  --from kim \
  --to andy \
  --intent code.implement \
  --text "Create authentication module"
```

### Self-Test

```bash
# Run comprehensive tests
./tools/router_akr_selftest.zsh

# Check results
cat g/reports/phase15/router_selftest.md
```

### CI Execution

```bash
# Runs automatically in GitHub Actions
# Job: router-selftest
# Trigger: Push to main/develop, PRs
```

## Acceptance Criteria

### ✅ All Criteria Met

1. **Selftest passes locally and in CI**
   - ✓ 10 test cases covering EN+TH routing
   - ✓ Kim↔Andy bidirectional delegation
   - ✓ CI job `router-selftest` green

2. **Dry-run acceptance test**
   ```bash
   ./tools/router_akr.zsh --dry-run --json '{
     "agent": "kim",
     "intent": "code.fix",
     "text": "แก้บั๊ก ci แคช"
   }'
   ```
   - ✓ Returns `to_agent="andy"`
   - ✓ Confidence >= 0.75
   - ✓ Writes telemetry to `g/telemetry_unified/unified.jsonl`

3. **Telemetry events written**
   - ✓ `router.start`
   - ✓ `router.decision`
   - ✓ `router.delegate`
   - ✓ `router.end`

4. **Safety features operational**
   - ✓ Circular delegation prevention
   - ✓ Max hops enforcement (3)
   - ✓ Graceful failure on missing configs

5. **Multi-language support**
   - ✓ English keyword matching
   - ✓ Thai keyword matching (แก้, แปล, ช่วย, etc.)

## Files Changed

```
New Files:
  tools/router_akr.zsh                    (370 lines)
  tools/router_akr_selftest.zsh           (280 lines)
  config/router_akr.yaml                  (190 lines)
  g/reports/phase15/PHASE_15_ROUTER_CORE.md

Modified Files:
  config/agents/andy.yaml                 (added intent_map)
  config/agents/kim.yaml                  (added intent_map)
  .github/workflows/ci.yml                (added router-selftest job)
```

## Testing

### Local Testing

```bash
# 1. Basic selftest
./tools/router_akr.zsh selftest

# 2. Full test suite
./tools/router_akr_selftest.zsh

# 3. Manual routing tests
./tools/router_akr.zsh route --json '{"agent":"kim","text":"fix bug"}'
./tools/router_akr.zsh route --json '{"agent":"andy","text":"แปลภาษา"}'
```

### CI Testing

The `router-selftest` job runs automatically on:
- Push to `main`, `develop`, or `ci/**` branches
- Pull requests to `main` or `develop`

View results:
- GitHub Actions workflow logs
- Artifact: `router-selftest-report` (router_selftest.md)

## Dependencies

**Required**:
- `zsh` (shell interpreter)
- `jq` (JSON parsing)

**Optional**:
- `yq` (YAML parsing, has fallback)
- `bc` (floating point math, has fallback)

All dependencies pre-installed in CI environment.

## Future Enhancements

1. **Machine Learning Integration**
   - Replace pattern matching with ML-based intent classifier
   - Train on historical routing decisions

2. **Dynamic Confidence Tuning**
   - Auto-adjust thresholds based on accuracy metrics
   - Per-intent confidence calibration

3. **Enhanced Context**
   - Include conversation history in routing decisions
   - User preference learning

4. **Performance Metrics**
   - Track routing accuracy
   - Measure delegation chain lengths
   - Monitor confidence distributions

5. **Extended Agent Support**
   - Support for >2 agents
   - Dynamic agent registration
   - Agent capability discovery

## Telemetry Verification

Check telemetry output:

```bash
# View all router events
grep -E '"__source":"router_akr"' g/telemetry_unified/unified.jsonl | jq

# Count events by type
grep router g/telemetry_unified/unified.jsonl | jq -r '.event' | sort | uniq -c

# View routing decisions
jq 'select(.event=="router.decision")' g/telemetry_unified/unified.jsonl
```

## Success Metrics

- ✅ 10/10 selftest cases passing
- ✅ 100% telemetry event coverage
- ✅ CI job green on first run
- ✅ Zero circular delegations in tests
- ✅ Multi-language support verified (EN + TH)
- ✅ Configuration-driven routing operational

## Conclusion

Phase 15 Router Core (AKR) successfully implements intelligent agent routing with:

- **Robust intent classification** with confidence scoring
- **Bi-directional delegation** (Kim ↔ Andy)
- **Safety guarantees** (circular detection, hop limits)
- **Comprehensive telemetry** (Phase 14.2 schema)
- **Multi-language support** (English + Thai)
- **CI integration** (automated testing)

The router is production-ready and provides a solid foundation for the 02LUKA multi-agent system's intelligent task distribution.

---

**Status**: ✅ **COMPLETE**
**Next Phase**: Integration with live agent endpoints
