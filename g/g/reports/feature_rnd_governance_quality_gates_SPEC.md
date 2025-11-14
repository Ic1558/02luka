# Feature SPEC: R&D Governance & Quality Gates (Phase 5)

**Feature ID:** `rnd_governance_quality_gates_phase5`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Objective

Add governance and quality gates to the R&D proposal processing pipeline, ensuring only safe, low-risk proposals are auto-approved while requiring human review for medium/high-risk changes. This completes the safety layer for the PR Score → R&D → Mary automation chain.

---

## Problem Statement

Currently, R&D Consumer (Phase 4) converts all proposals to Work Orders without risk assessment:
- No differentiation between low-risk (docs/tests) and high-risk (core logic) changes
- No guardrails on change size or scope
- No automatic review routing for risky proposals
- No traceability back to PRs
- No evidence capture for learning

---

## Solution Overview

A five-component governance system:
1. **RND Policy:** Risk tiers, allow/deny rules, guardrails
2. **Scoring & Gating:** Evaluates proposals, routes to Mary (auto) or CLS (review)
3. **PR ACK Comments:** Posts decision and next steps back to PR
4. **Evidence Capture:** Records outcomes to MLS for learning
5. **Live Control:** Feature flag to enable/disable live mode

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ RND Consumer (Phase 4)                                  │
│ • Processes proposals → creates WOs                      │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ RND Score & Gate (Phase 5 - NEW)                        │
│ • Reads RND policy                                      │
│ • Evaluates risk tier, guards                           │
│ • Routes: AUTO→Mary or HOLD→CLS                         │
└─────────────────┬───────────────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
┌──────────────┐   ┌──────────────────┐
│ Mary (AUTO)  │   │ CLS (REVIEW)     │
│ Low-risk     │   │ Medium/High-risk │
└──────┬───────┘   └────────┬─────────┘
       │                     │
       └──────────┬──────────┘
                  ▼
┌─────────────────────────────────────────────────────────┐
│ PR ACK Comment (Phase 5 - NEW)                          │
│ • Posts decision to PR                                  │
│ • Includes next steps                                   │
└─────────────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ Evidence Capture (Phase 5 - NEW)                        │
│ • Records to MLS: mls/rnd/lessons.jsonl                 │
│ • Includes: PR, outcome, timestamp                      │
└─────────────────────────────────────────────────────────┘
```

---

## Components

### 1. RND Policy (`config/rnd_policy.yaml`)

**Purpose:** Define risk tiers, guardrails, and auto-approval rules

**Structure:**
```yaml
version: 1
defaults:
  live: false              # Global feature flag
  target_score: 85
  max_touch_files: 5
  max_diff_lines: 200
  allow_doc_only_auto: true
  allow_test_only_auto: true
  allow_ci_fix_auto: true
  allow_code_refactor_auto: false

risk_tiers:
  low:
    kinds: [docs, tests, ci, lint]
    auto_approve: true
    requires_review: false
  medium:
    kinds: [small_refactor, config, pipeline]
    auto_approve: false
    requires_review: true
  high:
    kinds: [core_logic, security, finance]
    auto_approve: false
    requires_review: true

guards:
  - name: "touch-limit"
    rule: "changed_files <= defaults.max_touch_files"
  - name: "diff-limit"
    rule: "diff_lines <= defaults.max_diff_lines"
  - name: "no-secrets"
    rule: "secrets_found == 0"
  - name: "tests-green-if-modified"
    rule: "tests_touched ? tests_green : true"
```

### 2. Score & Gate (`tools/rnd_score_and_gate.zsh`)

**Purpose:** Evaluate proposals and route based on risk

**Responsibilities:**
- Read RND policy
- Gather PR metrics (files, lines, tests, CI status)
- Determine risk tier
- Check guardrails
- Route to Mary (auto) or CLS (review)
- Move processed proposals

**Input:**
- R&D proposals: `bridge/inbox/RND/RND-PR-*.yaml`
- Policy: `config/rnd_policy.yaml`

**Output:**
- Auto-approved WOs: `bridge/inbox/ENTRY/WO-*-GATED.yaml`
- Review requests: `bridge/inbox/CLS/REVIEW-*.yaml`
- Processed proposals: `bridge/processed/RND/`
- Log: `logs/rnd_gate.log`

**Schedule:**
- LaunchAgent: Every 7 minutes (`StartInterval: 420`)
- Runs after RND Consumer

**Routing Logic:**
```
IF tier == low AND guards_ok == true AND kind in [docs, tests, ci]:
  → AUTO → Mary (bridge/inbox/ENTRY/)
ELSE:
  → HOLD → CLS Review (bridge/inbox/CLS/)
```

### 3. PR ACK Comment (`tools/rnd_ack_pr_comment.zsh`)

**Purpose:** Post decision back to PR

**Usage:**
```bash
tools/rnd_ack_pr_comment.zsh <pr_number> <outcome> "<note>"
```

**Examples:**
- `tools/rnd_ack_pr_comment.zsh 123 "AUTO-APPROVED" "Low-risk docs change, routed to Mary"`
- `tools/rnd_ack_pr_comment.zsh 124 "HOLD-FOR-REVIEW" "Medium-risk refactor, requires CLS review"`

**Integration:**
- Called by Mary when processing auto-approved WOs
- Called by CLS when completing reviews

### 4. Evidence Capture (`tools/rnd_evidence_append.zsh`)

**Purpose:** Record outcomes to MLS for learning

**Usage:**
```bash
tools/rnd_evidence_append.zsh <proposal_id> <pr_number> <outcome>
```

**Output:**
- MLS lessons: `mls/rnd/lessons.jsonl`
- Format: JSONL with `ts`, `id`, `pr`, `outcome`

**Integration:**
- Called after PR ACK comment
- Records every decision for pattern learning

### 5. Live Control

**Purpose:** Feature flag to enable/disable live mode

**Toggle:**
```bash
# Enable live mode
sed -i '' 's/^  live: .*/  live: true/' ~/02luka/config/rnd_policy.yaml

# Disable (dry-run)
sed -i '' 's/^  live: .*/  live: false/' ~/02luka/config/rnd_policy.yaml
```

**Default:** `live: false` (dry-run)

---

## Data Flow

### Proposal Processing Flow

1. **RND Consumer (Phase 4)**
   - Processes proposals → creates initial WOs
   - Moves to processed

2. **RND Score & Gate (Phase 5)**
   - Reads processed proposals (or intercepts before processing)
   - Evaluates risk tier and guards
   - Routes to Mary (auto) or CLS (review)

3. **Mary/CLS Processing**
   - Executes improvements
   - Calls PR ACK comment
   - Calls evidence capture

4. **Evidence & Learning**
   - Outcomes recorded to MLS
   - Patterns learned for future decisions

---

## Risk Tiers

### Low Risk (Auto-Approve)
- **Kinds:** docs, tests, ci, lint
- **Guards:** Must pass all guardrails
- **Route:** Direct to Mary
- **Examples:**
  - Adding documentation
  - Adding unit tests
  - Fixing CI configuration
  - Linting fixes

### Medium Risk (Review Required)
- **Kinds:** small_refactor, config, pipeline
- **Guards:** Must pass all guardrails
- **Route:** CLS review
- **Examples:**
  - Small code refactoring
  - Configuration changes
  - Pipeline modifications

### High Risk (Review Required)
- **Kinds:** core_logic, security, finance
- **Guards:** Must pass all guardrails
- **Route:** CLS review
- **Examples:**
  - Core business logic changes
  - Security-related changes
  - Financial calculations

---

## Guardrails

### Touch Limit
- **Rule:** `changed_files <= max_touch_files` (default: 5)
- **Purpose:** Prevent large-scope changes from auto-approval

### Diff Limit
- **Rule:** `diff_lines <= max_diff_lines` (default: 200)
- **Purpose:** Prevent large changes from auto-approval

### No Secrets
- **Rule:** `secrets_found == 0`
- **Purpose:** Prevent accidental secret exposure
- **Note:** Scanner hook to be implemented

### Tests Green (if modified)
- **Rule:** `tests_touched ? tests_green : true`
- **Purpose:** Ensure tests pass if test files are modified

---

## Integration Points

### Existing Systems
- **RND Consumer:** Processes proposals (Phase 4)
- **Mary Dispatcher:** Executes auto-approved WOs
- **CLS:** Reviews held proposals
- **GitHub API:** Fetches PR metrics, posts comments

### New Integration
- **RND Policy:** Centralized governance rules
- **Score & Gate:** Risk assessment layer
- **PR ACK:** PR feedback loop
- **Evidence Capture:** MLS learning integration

---

## Safety & Guardrails

### Default: Dry-Run
- Policy defaults to `live: false`
- All decisions logged but not executed
- Safe for testing

### Live Mode
- Only activates when `live: true` in policy
- Auto-approved proposals go to Mary
- Held proposals go to CLS review

### Guardrail Enforcement
- All guards must pass for auto-approval
- Failed guards → automatic hold for review
- No bypass mechanism

---

## Configuration

### Policy File
- Location: `config/rnd_policy.yaml`
- Format: YAML
- Editable: Yes (manual or script)

### Environment Variables
- None (all config in policy file)

### LaunchAgent Tuning
- **Interval:** Edit `StartInterval` in plist (default: 420 seconds)
- **Throttle:** Add `ThrottleInterval` if needed

---

## Success Criteria

✅ **Functional:**
- Policy file exists and readable
- Score & gate evaluates proposals correctly
- Routing works (Mary for auto, CLS for review)
- PR comments posted successfully
- Evidence captured to MLS

✅ **Safety:**
- Low-risk proposals auto-approved
- Medium/high-risk proposals held for review
- Guardrails enforced
- No secrets in auto-approved changes

✅ **Traceability:**
- All decisions logged
- PR comments include outcomes
- Evidence recorded for learning

---

## Future Enhancements

1. **Secret Scanner Integration**
   - Hook in actual secret scanner
   - Replace placeholder `secrets_found=0`

2. **Advanced Risk Scoring**
   - ML-based risk prediction
   - Historical pattern analysis

3. **Paula-Specific Gates**
   - Trading-path change restrictions
   - Policy + simulation evidence requirements

4. **Automated Review Generation**
   - CLS auto-generates review recommendations
   - Reduces manual review time

---

## References

- RND Consumer: `g/reports/feature_rnd_auto_consume_improve_report_SPEC.md`
- PR Score Dispatcher: `g/reports/feature_pr_score_rnd_dispatch_SPEC.md`
- Mary Dispatcher: (existing system)
- CLS: (existing system)
