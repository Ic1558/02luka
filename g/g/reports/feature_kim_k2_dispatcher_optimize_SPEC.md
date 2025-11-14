# Kim K2 Dispatcher — PR Readiness Score Optimization

**Date:** 2025-11-12  
**Status:** Draft  
**PR:** #272  
**Current Score:** 62.5 / 100  
**Target Score:** 80+ / 100  
**Author:** CLS → CLC

---

## Executive Summary

PR #272 adds Kim K2 dispatcher functionality but has a low readiness score (62.5/100). This specification outlines optimizations to improve the score to 80+ without affecting other systems.

**Key Insight:** The score is low primarily due to missing documentation and limited test coverage. These can be added without changing core functionality.

---

## Problem Statement

### Current State
- **PR #272:** "Add Kim K2 dispatcher, tooling, and documentation"
- **Readiness Score:** 62.5 / 100 (too low, under-evaluated)
- **Components:**
  - `core/nlp/nlp_command_dispatcher.py` - Main dispatcher
  - `core/nlp/profile_store.py` - Profile persistence
  - `core/nlp/start_dispatcher.sh` - Launch helper
  - `tools/kim_health_check.zsh` - Health check
  - `tools/kim_ab_test.zsh` - A/B testing
  - `tests/test_kim_profile_router.py` - Basic tests

### Score Breakdown Analysis

Based on `config/pr_score.yaml` weights:

| Category | Weight | Current | Target | Gap |
|----------|--------|---------|--------|-----|
| CI status | 25% | ? | 1.0 | ? |
| Scope risk | 15% | ? | 1.0 | ? |
| Change size | 10% | ? | 0.7-1.0 | ? |
| Mergeability | 10% | ? | 1.0 | ? |
| Freshness | 10% | ? | 1.0 | ? |
| **Docs/tests** | **10%** | **0.0** | **1.0** | **-10%** |
| Governance | 10% | ? | 1.0 | ? |
| Reality hooks | 10% | ? | 1.0 | ? |

**Primary Gap:** Documentation and tests (10% weight) likely scoring 0.0

### Success Criteria
- Score: 80+ / 100
- No breaking changes to existing functionality
- No impact on other systems
- Documentation complete
- Test coverage improved

---

## Solution Design

### Optimization Strategy

**Focus Areas (High Impact, Low Risk):**

1. **Documentation (docs_tests: 10%)**
   - Add comprehensive README
   - API documentation
   - Configuration guide
   - Operational runbook

2. **Test Coverage (docs_tests: 10%)**
   - Expand unit tests
   - Add integration tests
   - Add error handling tests
   - Add edge case coverage

3. **CI Status (25%)**
   - Ensure all CI checks pass
   - Fix any linting issues
   - Verify test suite runs

4. **Governance (10%)**
   - Verify no forbidden paths
   - Check compliance

### Files to Add/Enhance

#### Documentation
1. `core/nlp/README.md` - Main documentation
   - Architecture overview
   - Setup instructions
   - API reference
   - Configuration guide
   - Troubleshooting

2. `docs/kim_k2_dispatcher.md` - User guide
   - Quick start
   - Command reference
   - Examples
   - Best practices

3. `core/nlp/CHANGELOG.md` - Version history
   - Track changes
   - Migration notes

#### Tests
1. `tests/test_nlp_command_dispatcher.py` - Expanded tests
   - Error handling
   - Edge cases
   - Integration scenarios

2. `tests/test_profile_store_edge_cases.py` - Profile store tests
   - TTL expiration
   - Concurrent access
   - Invalid data handling

3. `tests/integration/test_kim_k2_flow.py` - Integration tests
   - End-to-end flow
   - Redis integration
   - Profile switching

### Code Quality Improvements

1. **Type Hints**
   - Ensure all functions have type hints
   - Add return type annotations

2. **Error Handling**
   - More specific exceptions
   - Better error messages
   - Logging improvements

3. **Documentation Strings**
   - Complete docstrings for all public functions
   - Module-level documentation

---

## Data Schema

### Profile Store Schema
```json
{
  "chat_id": {
    "profile": "kim_k2_poc",
    "updated_at": "2025-11-12T04:00:00.000000Z"
  }
}
```

### Dispatcher Event Schema
```json
{
  "ts": "2025-11-12T04:00:00.000000Z",
  "event": "kim.dispatch.sent",
  "chat_id": "123456",
  "profile": "kim_k2_poc",
  "provider": "k2_thinking",
  "one_off": false
}
```

---

## Testing Strategy

### Unit Tests
- Profile loading and validation
- Command parsing (`/use`, `/k2`)
- Profile store TTL logic
- Error handling paths

### Integration Tests
- Redis pub/sub flow
- Profile persistence
- Event emission
- End-to-end message flow

### Manual Tests
- Health check script
- A/B testing tool
- LaunchAgent operation

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking changes | High | Only add docs/tests, no code changes |
| Test failures | Medium | Run tests before committing |
| Documentation gaps | Low | Review with existing docs |
| CI failures | Medium | Fix linting/formatting issues |

---

## Acceptance Criteria

✅ **All must pass:**

1. Readiness score: 80+ / 100
2. Documentation: README + API docs complete
3. Tests: Coverage improved, all passing
4. CI: All checks green
5. Governance: No violations
6. No breaking changes: Existing functionality unchanged

---

## Dependencies

- **Existing:** Kim K2 dispatcher code (already implemented)
- **External:** None (documentation and tests only)
- **System:** Python 3.8+, pytest

---

## Timeline

- **Documentation:** 1-2 hours
- **Tests:** 2-3 hours
- **CI fixes:** 30 minutes
- **Total:** 4-6 hours

---

**End of Specification**
