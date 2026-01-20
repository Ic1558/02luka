---
created_by: Codex
created_at: 2026-01-14
title: Main Blueprint Roadmap - Core State Bus
scope: One state bus + one runtime log + one intake CLI
---
# Main Blueprint Roadmap - Core State Bus

Goals
- One canonical snapshot: `g/tools/core_latest_state.py` is the only writer of `g/core_state/latest.json` and `g/core_state/latest.md`
- One runtime activity log: `g/core_state/work_notes.jsonl` (append-only, non-blocking, best-effort, git-ignored)
- One intake CLI: `g/tools/core_intake.py` reads `latest.json` and tails `work_notes.jsonl`
- UI is viewer only: menu bar, dashboard, and bots read state bus + notes; writes go only to work notes

Milestone 0 - Stabilize invariants
- Confirm `latest.json` is deterministic and written only by `g/tools/core_latest_state.py`
- Add or verify `.gitignore` for `g/core_state/work_notes.jsonl` (and runtime path overrides)
- Document runtime path policy and symlink guard for `work_notes.jsonl`

Milestone 1 - Runtime writeback (P2)
- Move work note writeback from `latest.json` to `work_notes.jsonl`
- Update `bridge/lac/writer.py` to append to `work_notes.jsonl` only
- Update `g/tools/CORE_STATE_BUS.md` and `g/docs/CORE_STATE_BUS.md` to match new write path

Milestone 2 - Unify intake CLI
- Keep `g/tools/core_intake.py` as the single entry point
- Deprecate or wrap `bridge/lac/core_intake.py` to call the tool entry point
- Remove duplicate docs or consolidate to one canonical doc
- Ensure intake reads `latest.json` + tail of `work_notes.jsonl` and returns brief (duplicate hint, recent lane work, busy flag)

Milestone 3 - Wire agents
- Ensure each lane calls intake at start and appends a work note at end
- Standardize work note schema (timestamp, lane, task_id, summary, status, artifact_path)
- Add a simple verification flow for notes (append and read-back)

Milestone 4 - Visual layer
- Menu bar and dashboard render combined signal (snapshot + last note age)
- UI remains read-only against `latest.json` and `work_notes.jsonl`

Immediate next step
- Move writeback from `latest.json` to `work_notes.jsonl`
- Remove duplication of `core_intake` and docs so there is a single source of truth

Success criteria
- `latest.json` only written by `g/tools/core_latest_state.py`
- `work_notes.jsonl` is append-only, non-blocking, and ignored by git
- `g/tools/core_intake.py` is the only intake entry point used by agents and UI
- UI reads only; all writes go to work notes
