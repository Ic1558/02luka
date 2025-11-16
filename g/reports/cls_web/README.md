# CLS Web Integration Reports - Phase 20

This directory contains reports, logs, and health metrics for the Claude Code Sessions (CLS) Web integration and load testing.

## Directory Structure

```
cls_web/
├── README.md                           # This file
├── phase20_health_latest.json          # Latest health check report
├── coordinator_health_latest.json      # CI coordinator health report
├── session_*.json                      # Individual session reports
├── dlq_*.json                          # Dead letter queue events
└── load_test_*.md                      # Load test summaries
```

## Report Types

### Health Reports
- **phase20_health_latest.json**: Real-time health metrics from CLS Web Bridge
  - Active session count
  - Total/completed/failed session metrics
  - Events processed
  - Error counts

- **coordinator_health_latest.json**: CI event coordinator health
  - Queue depths (high/normal/low/deadletter)
  - Event routing metrics
  - Lane-specific statistics

### Session Reports
- **session_*.json**: Detailed session lifecycle data
  - Session ID and metadata
  - Start/end times and duration
  - Events processed per session
  - Final status (completed/failed/timeout)

### Dead Letter Queue Reports
- **dlq_*.json**: Failed events that exhausted retries
  - Original event data
  - Retry history
  - Failure reason
  - Timestamp information

### Load Test Reports
- **load_test_*.md**: Human-readable load test summaries
  - Test configuration and parameters
  - Performance metrics and statistics
  - Bottlenecks and issues identified
  - Recommendations

## Metrics Collected

### Bridge Metrics
- `totalSessions`: Total sessions created
- `activeSessions`: Currently active sessions
- `completedSessions`: Successfully completed sessions
- `failedSessions`: Failed sessions
- `eventsProcessed`: Total events processed
- `errors`: Error count

### Coordinator Metrics
- `totalEvents`: Total events routed
- `processedEvents`: Successfully processed events
- `failedEvents`: Failed events (after retries)
- `retriedEvents`: Events that were retried
- `deadLetterEvents`: Events moved to DLQ
- `eventsByLane`: Per-lane event counts
- `eventsByPriority`: Per-priority event counts

## Configuration

### CLS Web Bridge
Environment variables:
- `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`: Redis connection
- `CLS_MAX_CONCURRENT`: Max concurrent sessions (default: 10)
- `CLS_SESSION_TIMEOUT`: Session timeout in ms (default: 300000)
- `CLS_HEALTH_INTERVAL`: Health check interval in ms (default: 30000)
- `CLS_LOG_LEVEL`: Logging level (debug/info/warn/error)

### CI Coordinator
Environment variables:
- `CI_MAX_RETRIES`: Max retry attempts (default: 3)
- `CI_RETRY_DELAY`: Initial retry delay in ms (default: 1000)
- `CI_RETRY_BACKOFF`: Retry backoff multiplier (default: 2.0)
- `CI_HEALTH_INTERVAL`: Health check interval in ms (default: 30000)
- `CI_LOG_LEVEL`: Logging level (debug/info/warn/error)

## Usage

### Starting CLS Web Bridge
```bash
node tools/cls_web_bridge.cjs
```

### Starting CI Coordinator
```bash
node tools/ci_coordinator.cjs
```

### Running Load Tests
```bash
# Heavy load test (triggered by [run-heavy] PR label)
tools/ci/cls_web_gate.sh
```

### Viewing Health Status
```bash
# Latest health reports
cat g/reports/cls_web/phase20_health_latest.json
cat g/reports/cls_web/coordinator_health_latest.json

# Session reports
ls -lt g/reports/cls_web/session_*.json | head -5

# Dead letter queue
ls -lt g/reports/cls_web/dlq_*.json | head -5
```

## Load Test Scenarios

### Light Load
- 5 concurrent sessions
- 10 events/minute
- Duration: 5 minutes

### Medium Load
- 10 concurrent sessions
- 25 events/minute
- Duration: 10 minutes

### Heavy Load (Phase 20 Default)
- 10 concurrent sessions
- 50 events/minute
- Duration: 15 minutes
- All CI jobs enabled (validate + ops-gate + daily-proof + cls-observer)

## Monitoring

### Redis Queue Inspection
```bash
# Check queue depths
redis-cli llen ci:queue:high
redis-cli llen ci:queue:normal
redis-cli llen ci:queue:low
redis-cli llen ci:queue:dlq

# View latest health data
redis-cli get ci:health:latest | jq
redis-cli get cls:metrics:health:latest | jq
```

### Session Inspection
```bash
# List active sessions
redis-cli keys "cls:session:*"

# Get session details
redis-cli get cls:session:<session-id> | jq
```

## Troubleshooting

### High Dead Letter Queue Count
- Check `dlq_*.json` files for failure patterns
- Review retry configuration
- Check Redis connectivity
- Verify lane configurations

### Low Throughput
- Check active session count vs max concurrent
- Review queue depths for bottlenecks
- Check coordinator health metrics
- Verify Redis performance

### Session Timeouts
- Increase `CLS_SESSION_TIMEOUT`
- Check session activity timestamps
- Review event processing times
- Check for hung processors

## Integration with CI

The CLS Web integration is triggered automatically in CI when:
1. PR has `[run-heavy]` in title, OR
2. PR has `cls` label, OR
3. Changes affect `tools/cls_*` or `.github/workflows/cls_web.yml`

Reports are uploaded as GitHub Actions artifacts:
- `cls-web-health-report`
- `cls-web-load-test-report`

## Related Documentation

- [CLS.md](../../../CLS.md) - Claude Code Sessions overview
- [02luka.md](../../../02luka.md) - Project documentation
- [.github/workflows/cls_web.yml](../../../.github/workflows/cls_web.yml) - CI workflow
- [tools/cls_web_bridge.cjs](../../../tools/cls_web_bridge.cjs) - Bridge implementation
- [tools/ci_coordinator.cjs](../../../tools/ci_coordinator.cjs) - Coordinator implementation

## Contact

For issues or questions:
- GitHub Issues: https://github.com/Ic1558/02luka/issues
- Label: `cls`, `ci`, `phase-20`
