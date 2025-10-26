# WO-251026-PHASE77-HARNESS-CREATE
Create missing Phase 7.7 test harness and checklist.

## Deliverables
- tools/test_browseros_phase77.sh (executable)
- docs/BROWSEROS_VERIFICATION_CHECKLIST.md
- g/reports/phase7_7_summary.md (on run)

## Acceptance
- CI can invoke tools/test_browseros_phase77.sh
- Artifacts upload from Actions: phase7_7_summary.md, web_actions.jsonl (+ rollups if available)

## Post-steps
- Make the script executable.
- Commit and push.
- Trigger the existing Phase 7.7 CI workflow (manually or by touching the harness file).
