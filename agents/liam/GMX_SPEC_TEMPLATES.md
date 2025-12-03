# GMX Spec Templates — Starter Pack

Liam can generate GMX-ready task specs using these templates.

---

## Basic Template

```json
{
  "task_spec": {
    "context": {
      "title": "Task Title",
      "description": "Detailed description of what needs to be done",
      "agent": "LIAM",
      "steps": [
        {
          "action": "write_ledger_entry",
          "agent": "Liam",
          "event": "task_received",
          "data": {
            "note": "Task description"
          }
        },
        {
          "action": "write_to_bridge",
          "inbox": "LIAM",
          "filename": "WO-EXAMPLE.json",
          "content": {
            "task_spec": {
              "intent": "example",
              "description": "Example work order"
            }
          }
        }
      ]
    }
  }
}
```

---

## Example: MLS Logging Spec

```json
{
  "task_spec": {
    "context": {
      "title": "Add AP/IO logging to MLS CLI tools",
      "description": "Implement AP/IO v3.1 logging in MLS CLI tools",
      "agent": "LIAM",
      "steps": [
        {
          "action": "write_ledger_entry",
          "agent": "Liam",
          "event": "task_received",
          "parent_id": "mls-logging-task-001",
          "data": {
            "note": "GMX has generated spec for MLS logging implementation."
          }
        },
        {
          "action": "write_to_bridge",
          "inbox": "LIAM",
          "filename": "WO-MLS-LOGGING.json",
          "content": {
            "task_spec": {
              "source": "GMX",
              "intent": "implement-mls-logging",
              "target_files": [
                "apps/mls/mls_build_cli_feed.py",
                "apps/mls/mls_cli_prompt.py"
              ],
              "context": {
                "description": "Add write_ledger_entry calls to MLS tools",
                "ap_io_version": "v3.1"
              }
            }
          }
        },
        {
          "action": "write_ledger_entry",
          "agent": "Liam",
          "event": "task_scheduled",
          "parent_id": "mls-logging-task-001",
          "data": {
            "note": "Work Order for MLS logging dispatched to LIAM."
          }
        }
      ]
    }
  }
}
```

---

## Supported Actions

### 1. write_ledger_entry
```json
{
  "action": "write_ledger_entry",
  "agent": "Liam",
  "event": "task_received",
  "parent_id": "optional-parent-id",
  "correlation_id": "optional-correlation-id",
  "data": {
    "key": "value"
  }
}
```

### 2. write_to_bridge
```json
{
  "action": "write_to_bridge",
  "inbox": "LIAM|GEMINI|HYBRID",
  "filename": "WO-NAME.json",
  "content": {
    "task_spec": {}
  }
}
```

---

## Usage

Save spec to `g/wo_specs/my_spec.json`, then:

```bash
python agents/liam/executor.py g/wo_specs/my_spec.json
```
