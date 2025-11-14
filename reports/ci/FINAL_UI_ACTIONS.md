# Final GitHub UI Actions - Copy/Paste Ready

All git work complete. Execute these 3-4 actions via GitHub web UI:

---

## A) Create Session 2 PR

**URL**: https://github.com/Ic1558/02luka/pull/new/claude/fix-shared-workflows-011CUrNfTZJqiQZpiMhGDmTq

**Title**:
```
ci: improve shared workflows (permissions/triggers/pages/configure-pages)
```

**Body**:
```
This PR applies minimal, workflows-only reliability fixes:
- Adds explicit GITHUB_TOKEN scopes where needed
- Aligns triggers (PR/tag) and ensures fetch-depth: 0 for tag logic
- Completes Pages pipeline: configure-pages@v5, upload → deploy order, concurrency group
- Standardizes ops-gate Redis host/auth handling
Purpose: general CI stability; no code changes outside .github/workflows/.
```

---

## B) Create Session 3 PR (Minimal #169 Replacement)

**URL**: https://github.com/Ic1558/02luka/pull/new/claude/fix-workflow-triggers-169-011CUrNfTZJqiQZpiMhGDmTq

**Title**:
```
ci: fix workflow triggers and permissions (minimal, workflows-only)
```

**Body**:
```
Extracts only the .github/workflows changes from the original #169 (commit c45e725).
Excludes .backup/.codex artifacts and unrelated files.
Intended as a clean replacement for easier review/merge.
```

---

## C) Close PR #164

**URL**: https://github.com/Ic1558/02luka/pull/164

**Comment to paste**:
```
Closing as superseded by commit d58ee6d on main (Redis host/auth already fixed).
This PR would reintroduce drift. If any gap remains, I'll follow up with a minimal delta PR.
```

**Then**: Click "Close pull request" button

---

## D) (Optional) Update PR #183 Metadata

**URL**: https://github.com/Ic1558/02luka/pull/183

**Actions via PR sidebar**:
- **Labels**: `ci`, `automation`, `documentation`, `phase14`
- **Assignee**: `Ic1558`
- **Milestone**: `Phase 14 wrap-up`

**Alternative via CLI** (if permissions allow):
```bash
gh label create ci --color 0366d6 --description "CI-related" || true
gh label create automation --color 0e8a16 --description "Automation tooling" || true
gh label create documentation --color fbca04 --description "Documentation updates" || true
gh label create phase14 --color d93f0b --description "Phase 14 deliverables" || true

gh pr edit 183 --add-label "ci,automation,documentation,phase14"
gh pr edit 183 --add-assignee Ic1558
gh pr edit 183 --milestone "Phase 14 wrap-up"
```

---

## ✅ Verification

After creating the PRs, verify they exist:
```bash
gh pr list --author "claude" --state open
```

---

**Status**: All git operations complete ✅
**Branches pushed**:
- `claude/fix-shared-workflows-011CUrNfTZJqiQZpiMhGDmTq`
- `claude/fix-workflow-triggers-169-011CUrNfTZJqiQZpiMhGDmTq`
- `claude/merge-green-prs-011CUrNfTZJqiQZpiMhGDmTq`

**Ready for**: GitHub UI actions above
