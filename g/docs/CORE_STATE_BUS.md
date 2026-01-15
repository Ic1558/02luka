# Core State Bus

The system state is decoupled into two components:
1.  **Snapshot** (`g/core_state/latest.json`): System telemetry, processes, git status. Written ONLY by `g/tools/core_latest_state.py`.
2.  **Journal** (`g/core_state/work_notes.jsonl`): Append-only log of agent work. Written by `writer.py` and agents.

## Read Usage (Intake View)

To get a unified view of the system (Snapshot + Recent Journal):

```bash
# JSON Output (Machine Readable)
python3 g/tools/core_intake.py --json

# Text Brief (Human Readable)
python3 g/tools/core_intake.py
```

## Write Usage (Work Notes)

Work notes are appended to `work_notes.jsonl` (Atomic, Non-blocking).

### Python API
```python
from bridge.lac.writer import write_work_note

write_work_note("dev", "WO-123", "Task Started", "running")
```

### CLI (Intake)
```bash
python3 g/tools/core_intake.py --task-id "WO-NEW" --summary "Fixing bug"
```

## Verification

```bash
# 1. Check Snapshot
python3 g/tools/core_latest_state.py --dry-run

# 2. Check Journal Integrity
tail g/core_state/work_notes.jsonl

# 3. Check Unified Intake
python3 g/tools/core_intake.py
```
