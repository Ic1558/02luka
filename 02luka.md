# 02LUKA – System Overview (Cursor + CLC)

## 1) Dual Memory System (Cursor ↔ CLC)
- **Cursor AI Memory**: `.codex/hybrid_memory_system.md`  
- **CLC Memory (SOT)**: `a/section/clc/memory/`  
- **Memory Bridge**: `.codex/codex_memory_bridge.yml` (mode: `mirror-latest`, `selective-merge`)  
- **Autosave Engine**: `.codex/autosave_memory.sh` → `g/reports/memory_autosave/autosave_*.md`

### How it works
1. Edit docs in repo → commit → pre-commit triggers autosave & (optional) write-through.
2. Pre-push gate (preflight + mapping + smoke) ต้องผ่านก่อนขึ้น remote.
3. Memory bridge sync ระหว่าง Cursor/CLC ตาม `mirror-latest`.

---

## 2) CLC Reasoning Model v1.1 (Unified)
- **Spec**: `a/section/clc/logic/REASONING_MODEL_EXPORT.yaml`  
- **Linked in Hybrid Memory**: `.codex/hybrid_memory_system.md` → `reasoning_model.import`  
- **Pipeline (7 steps)**: observe_context → expand_constraints → plan → act_small → self_check → reflect_and_trim → finalize_or_iterate (≤2)  
- **Rubric**: solution_fit / safety / maintainability / observability  
- **Anti-patterns**: Duct Taper, Box Ticker, Goons/Flunkies, Path Confusion  
- **Playbooks**: morning routine, LaunchAgents fix, memory sync  
- **Failure Modes**: API:4000, UI:5173, shebang/perm, Drive placeholder

**Starter prompt (Cursor):**

Use 02LUKA CLC Reasoning v1.1.
GOAL: Add a small, reversible improvement.
ACCEPTANCE: preflight OK, smoke OK, report in g/reports/, atomic patch only.
Follow pipeline v1.1; template: pt-small-safe-change.
Output: heredoc patch + apply/rollback commands.

---

## 3) Morning Routine (one-liner)
```bash
bash ./.codex/preflight.sh && bash ./run/dev_up_simple.sh && bash ./run/smoke_api_ui.sh
```

---

## 4) Runtime Path Rules (Important)
- ✅ ใช้: `~/dev/02luka-repo` หรือ `/workspaces/02luka-repo`
- ❌ ห้าม runtime บน CloudStorage (Stream/Mirror) เช่น `/Library/CloudStorage/GoogleDrive-*/My Drive/*`
- ✅ LaunchAgents logs → `~/Library/Logs/02luka/{label}.(out|err)`

---

## 5) Policy Packs
- **Drive**: `a/section/clc/logic/policies/drive.yaml`
- **LaunchAgents**: `a/section/clc/logic/policies/launchagents.yaml`
- **Guard CLI**: `g/tools/policy_guard.sh` (advisory in pre-push)

---

## 6) Checkpoints & Tags

| Tag | Date | Description |
|-----|------|-------------|
| v2025-10-05-cursor-ready | 2025-10-05 | DevContainer ready, preflight OK |
| v2025-10-05-stabilized | 2025-10-05 | System stabilized, audit + boot guard |
| v2025-10-05-docs-stable | 2025-10-05 | Dual Memory + docs unified |
| v2025-10-04-locked | 2025-10-04 | Dual Memory locked baseline |

**Use:**
```bash
git fetch --tags
git checkout v2025-10-05-docs-stable     # read-only
git checkout main && git pull            # back to latest
```

---

## 7) Verification Quicklinks
- **Reasoning wire report**: `g/reports/REASONING_MODEL_WIRE_*.md`
- **Policy applied report**: `g/reports/POLICY_PACKS_APPLIED_*.md`
- **Memory autosave**: `g/reports/memory_autosave/autosave_*.md`

Last Session: 251005_034023
