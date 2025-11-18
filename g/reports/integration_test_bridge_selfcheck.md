# Integration Test: Bridge Self-Check Protocol v3.2 Alignment

**PR:** #364  
**Date:** 2025-11-18  
**Purpose:** Verify escalation prompts route correctly through Mary/GC per Protocol v3.2

---

## Test Steps

### 1. Trigger Workflow Manually

```bash
gh workflow run bridge-selfcheck.yml \
  --ref feat/bridge-selfcheck-protocol-v3-alignment \
  -f ci_strict=1
```

### 2. Monitor Workflow Run

```bash
# Watch the workflow run
gh run watch

# Or check status
gh run list --workflow=bridge-selfcheck.yml --limit 1
```

### 3. Verify Escalation Prompt (if issues detected)

After workflow completes, check for escalation prompt artifact:

```bash
# Download escalation prompt artifact
gh run download <RUN_ID> -n escalation-prompt

# View the prompt
cat escalation-prompt/escalation_prompt.txt
```

**Expected Content:**

For **critical** issues:
```
NEEDS ELEVATION → Mary/GC → (route to CLC/Gemini)
เหตุผล: พบ critical issues ใน bridge/self-check ตาม Context Protocol v3.2
การดำเนินการ:
  1) ให้ Mary/GC ตรวจ zone (locked vs non-locked)
  2) ถ้า locked → ส่ง CLC (privileged writer)
  3) ถ้า non-locked → ส่ง Gemini (patch mode, primary operational writer)

Reference: g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md Section 2.2, 4
```

For **warning** issues:
```
ATTENTION → Mary/GC (for review)
เหตุผล: พบ warnings ใน bridge/self-check (ไม่ถึง critical) ตาม Context Protocol v3.2
การดำเนินการ: Mary/GC ตัดสินใจว่าจะ escalate ไป CLC/Gemini หรือรอรอบถัดไป

Reference: g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md Section 2.2, 4
```

### 4. Verify MLS Event

Check MLS ledger for the new tag:

```bash
# Check today's MLS ledger
cat mls/ledger/$(date +%Y-%m-%d).jsonl | jq 'select(.tags[] == "context-protocol-v3.2")' | tail -1
```

**Expected:** MLS event should include `"context-protocol-v3.2"` in tags array.

---

## Success Criteria

- ✅ Workflow runs successfully
- ✅ Escalation prompt includes Protocol v3.2 reference
- ✅ Escalation routes through Mary/GC (not directly to CLC)
- ✅ MLS event tagged with `context-protocol-v3.2`
- ✅ Governance header visible in workflow file

---

## Notes

- If bridge is healthy, no escalation prompt will be generated
- To test escalation, you may need to simulate issues or wait for actual issues
- The workflow runs on schedule (00:00 Asia/Bangkok) if no manual trigger
