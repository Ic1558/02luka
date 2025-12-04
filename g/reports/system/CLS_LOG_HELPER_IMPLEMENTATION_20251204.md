# CLS Log Helper Implementation (2025-12-04)

## Migrations
- tools/governance_index_generator.zsh: error handler now emits CLS audit events through g/tools/cls_log.zsh instead of appending raw JSON to g/telemetry/cls_audit.jsonl.

## Example schema_version 1.0 event
```json
{"schema_version":"1.0","timestamp":"2025-12-04T07:41:22Z","agent":"CLS","action":"cls_log_helper_validation","category":"maintenance","status":"completed","severity":"info","source":"cls_script","message":"Validated cls_log helper after migration","details":{"scripts_migrated":["tools/governance_index_generator.zsh"],"log_format":"compact_jsonl","schema_version":"1.0","note":"Post-migration validation event"}}
```

## Usage notes
- Wrapper: `g/tools/cls_log.zsh --action <action> --category <category> --status <status> --message "<summary>" [--severity <level>] [--source <origin>] [--details-file <json_path>]`
- Python entrypoint: `python3 g/tools/cls_log.py` with the same flags; defaults to severity=info and source=cls_script.
- Output path defaults to /Users/icmini/02luka/g/telemetry/cls_audit.jsonl; override with `CLS_AUDIT_PATH` if needed. Parent directories are created automatically.
- Details file must contain a JSON object (e.g., build via `jq -n '{key:\"value\"}' > /tmp/details.json`).

## Migration Status (2025-12-04)

### Phase 1: Infrastructure ✅
- ✅ Guard script created: `g/tools/ci_check_cls_log_usage.zsh`
- ✅ Helper functions created: `g/tools/cls_log_helpers.zsh`
- ✅ Migration logged via cls_log helper

### Helper Functions Available:
```zsh
source g/tools/cls_log_helpers.zsh

cls_log_wo_drop "WO-123" "CLC" "bridge/inbox/CLC/WO-123.yaml"
cls_log_wo_implement "WO-123" "completed"
cls_log_guard "guard_health_check" "completed" "All guards passed"
cls_log_sot_modification "WO-123" "user_explicit_request" "file1,file2"
```

### Next Steps:
- Use helper functions for all new CLS operations
- Migrate existing direct writes gradually
- Integrate guard script into CI pipeline

