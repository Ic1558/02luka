# Telemetry Reliability Pack v1.1

**Phase 14.2 – Production-Ready Telemetry System**

Last Updated: 2025-11-06

---

## Overview

The Telemetry Reliability Pack v1.1 provides a robust, validated telemetry infrastructure for the 02luka ecosystem. This pack includes:

- **Schema v1.1**: Unified event schema with mandatory fields and validation rules
- **Emitter**: Standard event generation tool with automatic event_id calculation
- **Validator**: Comprehensive validation tool with strict mode and reporting
- **CI Integration**: Automated validation on every pull request
- **Fixtures**: Test samples for validation and regression testing

---

## Schema v1.1

### Required Fields

All telemetry events **must** include:

| Field       | Type   | Description                                    | Example                                      |
|-------------|--------|------------------------------------------------|----------------------------------------------|
| `ts`        | string | RFC3339 timestamp (UTC, Z suffix)             | `2025-11-06T12:00:00Z`                       |
| `event`     | string | Event name (dot notation)                      | `rag.ctx.hit`                                |
| `component` | string | Source component (enum)                        | `rag`, `bridge`, `gg`, `cls`, etc.           |
| `event_id`  | string | SHA256 hash of canonical JSON (64-char hex)    | `a1b2c3d4e5f6...`                            |

### Optional Fields

| Field         | Type    | Default | Description                              |
|---------------|---------|---------|------------------------------------------|
| `level`       | string  | `info`  | Log level: `debug`, `info`, `warn`, `error` |
| `data`        | object  | `{}`    | Arbitrary event payload                  |
| `duration_ms` | number  | -       | Operation duration in milliseconds       |
| `batch_id`    | string  | -       | Batch identifier for grouped operations  |
| `source`      | string  | -       | Source path or agent name                |
| `__normalized`| boolean | `true`  | Schema conformance flag                  |

### Component Enum

Valid components:
- `gg` – Golden Goose (LLM worker)
- `cls` – Command Line System
- `cdc` – Change Data Capture
- `gm` – Global Manager
- `bridge` – Bridge service
- `rag` – Retrieval Augmented Generation
- `router` – Router/Gateway

### Event ID Calculation

The `event_id` is computed as:

```bash
event_id = SHA256(canonical_json)
```

Where `canonical_json` is:
- All keys sorted alphabetically
- No whitespace (compact format)
- **Excludes** the `event_id` field itself

Example:
```json
{"__normalized":true,"component":"rag","data":{"hits":4},"event":"rag.ctx.hit","level":"info","ts":"2025-11-06T12:00:00Z"}
```

---

## Tools

### Emitter: `tools/telemetry_emit.zsh`

Generates compliant telemetry events with automatic `event_id` calculation.

#### Usage

```bash
./tools/telemetry_emit.zsh \
  --event <event_name> \
  --component <component> \
  [--level <level>] \
  [--data <json_object>] \
  [--sink <output_file>] \
  [--ts <timestamp>] \
  [--batch-id <id>] \
  [--source <path>]
```

#### Examples

**Basic event:**
```bash
./tools/telemetry_emit.zsh \
  --event rag.ctx.hit \
  --component rag \
  --data '{"query":"Telemetry","hits":4}'
```

**With custom options:**
```bash
./tools/telemetry_emit.zsh \
  --event bridge.sync.start \
  --component bridge \
  --level info \
  --data '{"batch":1}' \
  --batch-id "batch-20251106-001" \
  --source "bridge/sync.py" \
  --sink g/telemetry_unified/unified.jsonl
```

#### Output

```
✓ Event emitted
  sink: g/telemetry_unified/unified.jsonl
  event: rag.ctx.hit
  event_id: a758f0045e4131bf814e34d507609c94555938b7aea259aadb0fe74068410e07
```

---

### Validator: `tools/telemetry_validate.zsh`

Validates JSONL telemetry files against schema v1.1.

#### Usage

```bash
./tools/telemetry_validate.zsh \
  --path <jsonl_file> \
  [--strict] \
  [--report <report_file>]
```

#### Options

- `--path <file>`: JSONL file to validate (required)
- `--strict`: Enable strict mode (disallow unknown fields)
- `--report <file>`: Generate markdown validation report

#### Examples

**Basic validation:**
```bash
./tools/telemetry_validate.zsh --path g/telemetry_unified/unified.jsonl
```

**Strict validation with report:**
```bash
./tools/telemetry_validate.zsh \
  --path tests/telemetry/fixtures/ok_sample.jsonl \
  --strict \
  --report g/reports/telemetry/validation_report.md
```

#### Output

```
Validating: tests/telemetry/fixtures/ok_sample.jsonl
Mode: STRICT (unknown fields will fail)

✅ VALIDATION PASSED
   Total events: 3
   Mode: STRICT
```

#### Validation Rules

The validator checks:
1. ✅ JSON syntax validity
2. ✅ Required fields presence (`ts`, `event`, `component`, `event_id`)
3. ✅ RFC3339 timestamp format with Z suffix
4. ✅ Component enum validation
5. ✅ Level enum validation (if present)
6. ✅ Event ID format (64-char hex)
7. ✅ Duplicate event_id detection
8. ✅ (Strict mode) No unknown fields

---

## CI Integration

### GitHub Actions Workflow

The telemetry validation workflow runs automatically on every pull request.

**Workflow**: `.github/workflows/telemetry-validate.yml`

#### Jobs

1. **validate-ok**: Validates test fixtures in strict mode
   - Ensures `tests/telemetry/fixtures/ok_sample.jsonl` passes validation
   - Validates `g/telemetry_unified/unified.jsonl` (non-blocking)

2. **expect-fail**: Validates bad fixtures (should fail)
   - Ensures `tests/telemetry/fixtures/bad_sample.jsonl` fails validation
   - Prevents regression in validation logic

#### Triggering

The workflow runs on:
- Pull requests to `main` branch
- Direct pushes to `main` branch

---

## Test Fixtures

### Location

- `tests/telemetry/fixtures/ok_sample.jsonl` – Valid events
- `tests/telemetry/fixtures/bad_sample.jsonl` – Invalid events

### Valid Sample (`ok_sample.jsonl`)

Contains 3 correctly formatted events:
1. `bridge.sync.start` – Bridge synchronization start
2. `ingest.ok` – Data ingestion success
3. `rag.ctx.hit` – RAG context retrieval

### Invalid Sample (`bad_sample.jsonl`)

Contains 3 intentionally malformed events:
1. Missing required fields (`ts`, `event_id`)
2. Invalid timestamp format
3. Missing `event` field

---

## Local Testing

### Quick Test

```bash
# Generate a test event
./tools/telemetry_emit.zsh \
  --event test.local \
  --component gg \
  --data '{"test":true}'

# Validate it
./tools/telemetry_validate.zsh \
  --path g/telemetry_unified/unified.jsonl \
  --strict
```

### Full Test Suite

```bash
# 1. Validate good fixtures
./tools/telemetry_validate.zsh \
  --path tests/telemetry/fixtures/ok_sample.jsonl \
  --strict \
  --report /tmp/validate_ok.md

# 2. Validate bad fixtures (expect failure)
./tools/telemetry_validate.zsh \
  --path tests/telemetry/fixtures/bad_sample.jsonl \
  --strict \
  && echo "ERROR: Should have failed!" \
  || echo "✓ Correctly failed"

# 3. Generate fresh events and validate
rm -f /tmp/test_events.jsonl
./tools/telemetry_emit.zsh --event test.1 --component gg --sink /tmp/test_events.jsonl
./tools/telemetry_emit.zsh --event test.2 --component rag --sink /tmp/test_events.jsonl
./tools/telemetry_validate.zsh --path /tmp/test_events.jsonl --strict
```

---

## Optional: LaunchAgent Heartbeat

For macOS users, a LaunchAgent can be configured to emit periodic heartbeats.

### LaunchAgent Configuration

**File**: `~/Library/LaunchAgents/com.02luka.telemetry.heartbeat.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.02luka.telemetry.heartbeat</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>~/02luka/tools/telemetry_emit.zsh --event system.heartbeat --component gg --level info --data "{\"host\":\"$HOST\"}" --sink ~/02luka/g/telemetry_unified/unified.jsonl</string>
    </array>
    <key>StartInterval</key>
    <integer>600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/telemetry_heartbeat.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/telemetry_heartbeat.err</string>
</dict>
</plist>
```

### Load the Agent

```bash
launchctl load ~/Library/LaunchAgents/com.02luka.telemetry.heartbeat.plist
launchctl start com.02luka.telemetry.heartbeat
```

### Verify Heartbeats

```bash
tail -f g/telemetry_unified/unified.jsonl | jq 'select(.event == "system.heartbeat")'
```

---

## Troubleshooting

### Validation Fails with "Invalid JSON"

**Cause**: JSONL file contains malformed JSON on one or more lines.

**Solution**: Use `jq` to identify the problematic line:
```bash
jq -c . < your_file.jsonl
```

### Event ID Mismatch

**Cause**: The `event_id` in the file doesn't match the SHA256 of canonical JSON.

**Solution**: Regenerate events using `telemetry_emit.zsh` to ensure correct `event_id` calculation.

### Strict Mode Fails on Unknown Fields

**Cause**: Event contains fields not in schema v1.1.

**Solution**: Remove unknown fields or update schema if they are legitimate additions.

### Duplicate Event IDs

**Cause**: Two events have identical content, resulting in the same `event_id`.

**Solution**: Ensure events have unique content (different `ts`, `data`, etc.).

---

## Migration from Legacy Telemetry

If you have existing telemetry data, migrate it to v1.1:

1. **Add missing fields**: Ensure `ts`, `event`, `component`, `event_id` are present
2. **Standardize timestamps**: Convert all timestamps to RFC3339 with Z suffix
3. **Calculate event_id**: Use the emitter to regenerate events with correct `event_id`
4. **Validate**: Run validator in strict mode to ensure compliance

---

## References

- **Schema**: `config/telemetry_unified.yaml`
- **Emitter**: `tools/telemetry_emit.zsh`
- **Validator**: `tools/telemetry_validate.zsh`
- **CI Workflow**: `.github/workflows/telemetry-validate.yml`
- **Fixtures**: `tests/telemetry/fixtures/`
- **Reports**: `g/reports/PHASE_14_TELEMETRY_HARDENING.md`

---

## Acceptance Criteria

✅ **Schema v1.1** defined in `config/telemetry_unified.yaml`
✅ **Emitter** generates events with valid `event_id`
✅ **Validator** enforces all schema rules
✅ **CI workflow** runs on PRs and validates fixtures
✅ **Test fixtures** include both valid and invalid samples
✅ **Documentation** covers all tools and usage patterns

---

**Phase 14.2 Complete** – Telemetry system is production-ready and fully validated.
