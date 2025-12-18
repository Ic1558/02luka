# CLS PR Merge Checklist (Fast)

## 1) Identify
- PR number, title, head/base

## 2) Gate A: Zone
- classify by highest-risk file touched

## 3) Gate B: Blockers
- any open GOVERNANCE PR blocking? if yes → WAIT

## 4) Gate C: Mergeability
- MERGEABLE / CONFLICTING / behind?

## 5) If CONFLICTING
- only AUTO_GENERATED? → apply origin/main policy
- otherwise: if GOVERNANCE/LOCKED_CORE → ASK BOSS

## 6) Merge
- DOCS/OPEN + MERGEABLE → merge (squash preferred unless policy says otherwise)

## 7) Verify
- re-check file presence
- run verification commands/scripts if relevant
- note any regen needs (auto-generated)

## 8) Cleanup
- delete branch (local + remote if needed)
- sync main
