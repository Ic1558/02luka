# Feature PLAN: R&D Governance & Quality Gates (Phase 5)

**Feature ID:** `rnd_governance_quality_gates_phase5`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Task Breakdown

### Phase 1: Policy Configuration ✅

- [x] **Task 1.1:** Create RND policy file (`config/rnd_policy.yaml`)
  - Define risk tiers (low, medium, high)
  - Set defaults (live, target_score, limits)
  - Define guardrails
  - Set auto-approval rules

### Phase 2: Scoring & Gating ✅

- [x] **Task 2.1:** Create score & gate script (`tools/rnd_score_and_gate.zsh`)
  - Read policy file
  - Gather PR metrics (files, lines, tests, CI)
  - Determine risk tier
  - Check guardrails
  - Route to Mary or CLS

- [x] **Task 2.2:** Create LaunchAgent
  - 7-minute interval (runs after consumer)
  - Run at load
  - Log paths

### Phase 3: PR ACK & Evidence ✅

- [x] **Task 3.1:** Create PR ACK comment script
  - Post decision to PR
  - Include next steps

- [x] **Task 3.2:** Create evidence capture script
  - Append to MLS lessons
  - Record outcomes

### Phase 4: Testing & Verification ✅

- [x] **Task 4.1:** Test policy reading
  - Verify YAML parsing
  - Verify defaults

- [x] **Task 4.2:** Test scoring logic
  - Low-risk → auto-approve
  - Medium/high-risk → hold

- [x] **Task 4.3:** Test routing
  - Verify Mary inbox for auto
  - Verify CLS inbox for review

- [x] **Task 4.4:** Test PR comments
  - Verify comment posting
  - Verify message format

- [x] **Task 4.5:** Test evidence capture
  - Verify MLS append
  - Verify JSONL format

---

## Test Strategy

### Unit Tests

**Test 1: Policy Reading**
```bash
# Read policy values
yamlv() { awk -F': *' -v k="$1" '$1==k{print $2}' "$2" 2>/dev/null || true; }
target_score=$(yamlv "target_score" config/rnd_policy.yaml)
# Expected: 85
```

**Test 2: Risk Tier Determination**
```bash
kind="docs"
tier=medium
[[ "$kind" =~ ^(docs|tests|ci|lint)$ ]] && tier=low
# Expected: tier=low
```

**Test 3: Guardrail Checks**
```bash
changed_files=3
max_files=5
ok_touch=$(( changed_files <= max_files ? 1 : 0 ))
# Expected: ok_touch=1
```

### Integration Tests

**Test 1: End-to-End Flow (Low-Risk)**
```bash
# 1. Create low-risk proposal
cat > bridge/inbox/RND/RND-PR-999-docs.yaml <<EOF
id: RND-PR-999-docs
pr_number: 999
current_score: 70
target_score: 85
kind: docs
EOF

# 2. Run score & gate
tools/rnd_score_and_gate.zsh

# 3. Verify routing
ls -1 bridge/inbox/ENTRY/WO-*-GATED.yaml
# Expected: WO created in Mary inbox

# 4. Verify proposal moved
ls -1 bridge/processed/RND/RND-PR-999-docs.yaml
# Expected: Proposal in processed
```

**Test 2: End-to-End Flow (High-Risk)**
```bash
# 1. Create high-risk proposal
cat > bridge/inbox/RND/RND-PR-999-core.yaml <<EOF
id: RND-PR-999-core
pr_number: 999
current_score: 70
target_score: 85
kind: core_logic
EOF

# 2. Run score & gate
tools/rnd_score_and_gate.zsh

# 3. Verify routing
ls -1 bridge/inbox/CLS/REVIEW-*.yaml
# Expected: Review request in CLS inbox

# 4. Verify proposal moved
ls -1 bridge/processed/RND/RND-PR-999-core.yaml
# Expected: Proposal in processed
```

**Test 3: PR ACK Comment**
```bash
# Test comment posting (use test PR or mock)
tools/rnd_ack_pr_comment.zsh 999 "AUTO-APPROVED" "Low-risk docs change"

# Verify comment posted (check GitHub)
gh pr view 999 --comments | grep "R&D Gate"
```

**Test 4: Evidence Capture**
```bash
# Capture evidence
tools/rnd_evidence_append.zsh "RND-PR-999-test" "999" "AUTO-APPROVED"

# Verify MLS entry
tail -1 mls/rnd/lessons.jsonl | jq .
# Expected: JSON with ts, id, pr, outcome
```

### Edge Cases

**Test 1: Missing Policy File**
```bash
# Temporarily rename policy
mv config/rnd_policy.yaml config/rnd_policy.yaml.bak

# Run gate
tools/rnd_score_and_gate.zsh

# Should handle gracefully (log error, skip)
grep -i "error\|missing" logs/rnd_gate.err.log
```

**Test 2: Invalid PR Number**
```bash
# Create proposal with invalid PR
cat > bridge/inbox/RND/RND-PR-invalid.yaml <<EOF
pr_number: 999999
EOF

# Run gate
tools/rnd_score_and_gate.zsh

# Should handle gracefully (skip invalid PR)
grep -i "error\|skip" logs/rnd_gate.log
```

**Test 3: Guardrail Failures**
```bash
# Create proposal that fails guardrails
# (e.g., too many files, too many lines)

# Run gate
tools/rnd_score_and_gate.zsh

# Should route to CLS review (not auto-approve)
ls -1 bridge/inbox/CLS/REVIEW-*.yaml
# Expected: Review request created
```

---

## Rollback Plan

### Immediate Rollback
```bash
# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.rnd.gate.plist

# Remove files
rm -f ~/Library/LaunchAgents/com.02luka.rnd.gate.plist
rm -f ~/02luka/tools/rnd_score_and_gate.zsh
rm -f ~/02luka/tools/rnd_ack_pr_comment.zsh
rm -f ~/02luka/tools/rnd_evidence_append.zsh
rm -f ~/02luka/config/rnd_policy.yaml

# Preserve logs and evidence
# (keep for audit trail)
```

---

## Deployment Checklist

- [x] **Pre-Deployment:**
  - [x] Verify RND Consumer working (Phase 4)
  - [x] Verify Mary/CLS can process WOs
  - [x] Verify GitHub CLI authenticated

- [x] **Deployment:**
  - [x] Create policy file
  - [x] Create score & gate script
  - [x] Create PR ACK script
  - [x] Create evidence capture script
  - [x] Create LaunchAgent
  - [x] Create CLS inbox directory
  - [x] Load LaunchAgent

- [x] **Post-Deployment:**
  - [x] Run health checks
  - [x] Test low-risk routing
  - [x] Test high-risk routing
  - [x] Test PR comments
  - [x] Test evidence capture
  - [x] Monitor first cycle

---

## Acceptance Criteria

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

## Timeline

- **Phase 1:** ✅ Complete (2 min)
- **Phase 2:** ✅ Complete (5 min)
- **Phase 3:** ✅ Complete (3 min)
- **Phase 4:** ✅ Complete (5 min)

**Total:** ~15 minutes (one-shot installers)

---

## Success Metrics

1. **Safety:** 100% of high-risk proposals held for review
2. **Efficiency:** Low-risk proposals auto-approved within 7 minutes
3. **Traceability:** All decisions logged and commented on PRs
4. **Learning:** Evidence captured for pattern analysis

---

## Next Steps

1. **Monitor First Week:**
   - Check gate logs every 7 minutes
   - Verify routing decisions
   - Review PR comments

2. **Tune Policy:**
   - Adjust risk tier definitions
   - Tune guardrail thresholds
   - Refine auto-approval rules

3. **Enable Live Mode:**
   - Review dry-run decisions
   - When confident: `sed -i '' 's/^  live: .*/  live: true/' config/rnd_policy.yaml`

---

## References

- **SPEC:** `g/reports/feature_rnd_governance_quality_gates_SPEC.md`
- **RND Consumer:** `g/reports/feature_rnd_auto_consume_improve_report_SPEC.md`
- **PR Score Dispatcher:** `g/reports/feature_pr_score_rnd_dispatch_SPEC.md`
