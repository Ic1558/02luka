# /health-check

**Goal:** Run the target system health check and summarize.

## Usage

- Automatically detects available health check scripts
- Returns pass/fail + summary

## Steps (tool-facing)

1) Detect target health script:
   - `tools/system_health_check.zsh` (primary)
   - `tools/memory_hub_health.zsh` (alternative)
   - Or first `tools/*_health_check.zsh` found

2) Run and capture exit/status:
   ```bash
   "$HEALTH_SCRIPT" > "$OUTPUT" 2>&1
   EXIT_CODE=$?
   ```

3) Emit JSON summary → `g/reports/system/system_health_$(date +%Y%m%d_%H%M).json`:
   ```json
   {
     "timestamp": "ISO8601",
     "script": "path/to/script",
     "exit_code": 0,
     "status": "pass|fail",
     "summary": "brief summary"
   }
   ```

## Example

```
/health-check
```

This will:
- Detect and run appropriate health check
- Capture output and exit code
- Generate JSON summary
- Return pass/fail status
