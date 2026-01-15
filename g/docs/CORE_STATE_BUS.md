# Core State Bus

The canonical snapshot is `g/core_state/latest.json`, written only by `g/tools/core_latest_state.py`.
Agents and tools must treat it as read-only.

Work notes are stored separately in `g/core_state/work_notes.jsonl` (or `~/02luka_ws/g/core_state/work_notes.jsonl` when `LUKA_WS_ROOT` is set).
This keeps runtime writes out of the snapshot and avoids polluting the repo.

## Read Usage

Consumers read `latest.json` to understand system state.
The intake CLI merges the snapshot with recent work notes to provide a brief view.

```bash
python3 g/tools/core_intake.py
python3 g/tools/core_intake.py --json
```

## Write Usage (Work Notes)

Work notes are best-effort and non-blocking. If a lock cannot be acquired, the write is skipped.

```python
from bridge.lac.writer import write_work_note

write_work_note(
    lane="dev",
    task_id="WO-123",
    short_summary="Starting task",
    status="running",
)
```

## Verification

```bash
python3 g/tools/core_intake.py --json
python3 - <<'PY'
from bridge.lac.writer import write_work_note
print(write_work_note("dev", "WO-TEST", "Manual verification", "success"))
PY
```
