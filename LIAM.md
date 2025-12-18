# Liam Agent (02luka)

For full agent identity, see `personas/LIAM_PERSONA_v2.md`.

---

## 🧠 Agent Memory — Lessons Learned

### PR Management (2025-12-19)

**CRITICAL RULES:**
1. **NEVER direct push to main** — main accepts changes via PR only
2. **Always use branch → PR → merge workflow**
3. **Read docs before action:** `g/docs/PR_MANAGEMENT_DECISION_FRAMEWORK_v1.md`, `g/docs/PR_AUTOPILOT_RULES.md`

**3 Gates Before Any PR Action:**
- Gate A: Zone Classification (GOVERNANCE/LOCKED_CORE/DOCS/OPEN/AUTO_GENERATED)
- Gate B: Dependency Order (governance first)
- Gate C: Mergeability Check

**Default merge strategy:** `--squash` (1 PR = 1 commit)

---

### Workflow Protocol (2025-12-19)

**FUNDAMENTAL WORKFLOW:**
1. READ — Latest session + telemetry + relevant docs
2. DISCOVER — Related files (Phase 0)
3. PLAN — Match requirements exactly
4. DRY-RUN — Test without changes
5. VERIFY — Evidence/logs
6. EXECUTE — Only after verify passes
7. SAVE — save-now + check telemetry

**Key principle:** "Verification is proof. Without proof, there is no claim."

---

### Telemetry & Sessions (2025-12-19)

**Always check telemetry before/after major tasks:**
```bash
ls -la g/telemetry/ | tail -5
cat g/telemetry/save_sessions.jsonl | tail -3
```

**Always read latest session at start:**
```bash
cat g/reports/sessions/session_*.ai.json | tail -1
```

**Always save with agent ID:**
```bash
cd ~/02luka && AGENT_ID=liam SAVE_SOURCE=terminal ./tools/save.sh
```

---

### Safe Auto-Run Commands

| Safe (auto-run) | Unsafe (ask permission) |
|-----------------|------------------------|
| `git add`, `git commit` | `rm -rf` |
| `git push` (via PR) | `sudo` anything |
| `--dry-run` commands | External API calls |
| `pytest`, tests | Database writes |
| Read files, `ls`, `cat`, `grep` | Force push to main |

---

## References

- `g/docs/WORKFLOW_PROTOCOL_v1.md`
- `g/docs/WORKFLOW_PRE_ACTION_CHECKLIST.md`
- `g/docs/PR_MANAGEMENT_DECISION_FRAMEWORK_v1.md`
- `g/docs/PR_AUTOPILOT_RULES.md`
