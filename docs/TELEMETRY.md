# Telemetry System

Self-metrics for agent runs in the 02luka system.

## Overview

The telemetry system provides lightweight, append-only logging for tracking agent run metrics including pass/warn/fail counts and execution duration. All data is stored locally in `g/telemetry/*.log` files using JSON Lines format.

## Components

### 1. Telemetry Module (`boss-api/telemetry.cjs`)

Core Node.js module providing telemetry functionality:

```javascript
const telemetry = require('./boss-api/telemetry.cjs');

// Record a run
telemetry.record('smoke_api_ui', {
  pass: 5,
  warn: 0,
  fail: 0,
  duration_ms: 1234
});

// Read entries with filters
const entries = telemetry.read({
  since: new Date('2025-10-19'),
  task: 'smoke_api_ui'
});

// Get summary statistics
const stats = telemetry.summary({
  since: new Date(Date.now() - 24 * 60 * 60 * 1000)
});

// Cleanup old logs
telemetry.cleanup(30); // Keep last 30 days
```

### 2. CLI Usage

The telemetry module can be used from the command line:

```bash
# Record a run
node boss-api/telemetry.cjs \
  --task smoke_api_ui \
  --pass 5 \
  --warn 0 \
  --fail 0 \
  --duration 1234

# Show summary for last 24 hours
node boss-api/telemetry.cjs --summary

# Cleanup old logs
node boss-api/telemetry.cjs --cleanup 30
```

### 3. Integration

Telemetry is automatically integrated into:

- **`run/smoke_api_ui.sh`** - Records metrics after smoke tests
- **`run/ops_atomic.sh`** - Records metrics after full OPS runs

Both scripts capture:
- Start/end timestamps
- Pass/warn/fail counts
- Total execution duration in milliseconds

### 4. Report Generation

Generate a markdown report for the last 24 hours:

```bash
bash scripts/generate_telemetry_report.sh
```

Output: `g/reports/telemetry_last24h.md`

The report includes:
- Summary statistics (total runs, pass/warn/fail, duration)
- Breakdown by task
- Last 10 runs with timestamps

## Data Format

### Log File Format

Log files are stored in `g/telemetry/YYYYMMDD.log` using JSON Lines format:

```json
{"ts":"2025-10-19T19:38:56.195Z","task":"smoke_api_ui","pass":5,"warn":0,"fail":0,"duration_ms":1234}
{"ts":"2025-10-19T19:40:12.456Z","task":"ops_atomic","pass":5,"warn":0,"fail":0,"duration_ms":45678}
```

### Entry Schema

Each entry contains:

| Field | Type | Description |
| ----- | ---- | ----------- |
| `ts` | string | ISO 8601 timestamp |
| `task` | string | Task name (e.g., `smoke_api_ui`, `ops_atomic`) |
| `pass` | number | Number of passed tests |
| `warn` | number | Number of warnings |
| `fail` | number | Number of failures |
| `duration_ms` | number | Execution duration in milliseconds |
| `meta` | object | Optional metadata (future use) |

## File Rotation

- Log files are automatically created daily: `g/telemetry/YYYYMMDD.log`
- Old log files can be cleaned up using `telemetry.cleanup(daysToKeep)`
- Default retention: 30 days

## Privacy & Security

- All telemetry data is stored **locally only**
- No external transmission or cloud storage
- Contains only run metrics (no sensitive data)
- Can be disabled by removing telemetry calls from scripts

## Monitoring

View recent telemetry:

```bash
# Show all entries
node boss-api/telemetry.cjs --summary | jq .

# Show entries for specific task
cat g/telemetry/*.log | grep smoke_api_ui

# Count total runs today
wc -l g/telemetry/$(date +%Y%m%d).log
```

## Troubleshooting

### No telemetry data

**Problem:** Telemetry log files are not being created

**Solution:**
1. Check that Node.js is installed: `node --version`
2. Verify telemetry module is executable: `chmod +x boss-api/telemetry.cjs`
3. Check write permissions on `g/telemetry/` directory
4. Run manually to test: `node boss-api/telemetry.cjs --task test --pass 1 --warn 0 --fail 0 --duration 100`

### Old format in logs

**Problem:** JSON parsing errors when reading logs

**Solution:**
1. Backup existing logs: `cp -r g/telemetry g/telemetry.bak`
2. Clean up malformed entries: Use `telemetry.read()` to filter valid entries
3. Or start fresh: `rm g/telemetry/*.log`

## Future Enhancements

Potential improvements:

- [ ] Add trend analysis (success rate over time)
- [ ] Alert on degrading performance (duration increases)
- [ ] Dashboard visualization
- [ ] Integration with Discord notifications
- [ ] Export to external monitoring systems (optional)

## See Also

- [Discord OPS Integration](DISCORD_OPS_INTEGRATION.md) - Notification system
- [API Endpoints](api_endpoints.md) - Boss API reference
- [Repository Structure](REPOSITORY_STRUCTURE.md) - Project layout
