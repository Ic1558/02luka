# Liam Executor — Notes

## Entrypoint
```bash
python agents/liam/executor.py <path/to/spec.json>
```

## Responsibilities
- Load + validate GMX JSON specs  
- Execute steps:
  - `write_ledger_entry`
  - `write_to_bridge`
- Maintain AP/IO v3.1 structure
- Enforce safe path restrictions

## Expected Structure
```
spec.task_spec.context.steps[]
```
or  
```
spec.gmx_plan.steps[]
```

## Lifecycle events written:
- `task_received`
- `task_scheduled`
- `gmx_spec_executed`
- `task_completed`

## Example Usage

### Run a GMX spec:
```bash
python agents/liam/executor.py g/wo_specs/gmx_liam_mls_logging.json
```

### Dry-run mode:
```bash
python agents/liam/executor.py g/wo_specs/my_spec.json --dry-run
```

## Security
- All `write_to_bridge` operations are confined to `bridge/inbox`
- Uses `ensure_under()` to prevent path traversal
- Validates spec structure before execution
