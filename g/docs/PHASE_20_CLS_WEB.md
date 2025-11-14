# Phase 20: CLS Web Integration & Load Test

**Status**: 🟡 In Development
**Started**: 2025-11-06
**Target**: Full production deployment

---

## Overview

Phase 20 introduces a comprehensive Claude Code Sessions (CLS) Web integration with load testing capabilities, enabling full concurrent orchestration across multiple AI lanes (GPT-4, Claude Web, Crude).

## Goals

1. ✅ **CLS Web Bridge**: Bidirectional adapter for web-based Claude sessions
2. ✅ **CI Event Coordinator**: Enhanced event routing with priority queues
3. ✅ **Load Testing**: Heavy stress testing (10 concurrent, 50 events/min)
4. ✅ **Observability**: Real-time health checks and metrics collection
5. ⏳ **Auto-merge Integration**: Touchless deployment with auto-decision

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       GitHub Actions                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Validate │  │ Ops Gate │  │   Daily  │  │CLS Web   │   │
│  │          │  │          │  │   Proof  │  │Load Test │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │              │             │          │
│       └─────────────┴──────────────┴─────────────┘          │
│                           │                                  │
└───────────────────────────┼──────────────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │  Redis Event   │
                    │      Bus       │
                    └───────┬────────┘
                            │
            ┌───────────────┼───────────────┐
            │                               │
    ┌───────▼────────┐            ┌────────▼────────┐
    │ CLS Web Bridge │            │ CI Coordinator  │
    │                │            │                 │
    │ • Sessions     │            │ • Event Router  │
    │ • Lifecycle    │            │ • Retry Logic   │
    │ • Health       │            │ • DLQ Handler   │
    └────────────────┘            └─────────────────┘
            │                               │
            └───────────────┬───────────────┘
                            │
                    ┌───────▼────────┐
                    │   Reports &    │
                    │    Metrics     │
                    │                │
                    │ g/reports/     │
                    │   cls_web/     │
                    └────────────────┘
```

## Components

### 1. CLS Web Bridge (`tools/cls_web_bridge.cjs`)

Node.js service that manages Claude Code Sessions via Redis event bus.

**Features:**
- Session lifecycle management (create, update, end)
- Concurrent session limits and throttling
- Health checks and watchdog integration
- Automatic session timeout and cleanup
- Metrics collection and reporting

**Configuration:**
```bash
# Redis connection
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=<secret>

# Bridge settings
CLS_MAX_CONCURRENT=10           # Max concurrent sessions
CLS_SESSION_TIMEOUT=300000      # Session timeout (5 min)
CLS_HEALTH_INTERVAL=30000       # Health check interval (30s)
CLS_LOG_LEVEL=info              # Logging level
```

**Usage:**
```bash
# Start bridge
node tools/cls_web_bridge.cjs

# With custom config
CLS_MAX_CONCURRENT=20 CLS_LOG_LEVEL=debug node tools/cls_web_bridge.cjs
```

### 2. CI Event Coordinator (`tools/ci_coordinator.cjs`)

Distributed event routing and coordination for CI/CD pipelines.

**Features:**
- Multi-priority event queues (high, normal, low)
- Lane-based routing (GPT-4, Claude Web, Crude)
- Exponential backoff retry logic
- Dead letter queue for failed events
- Real-time metrics and observability

**Configuration:**
```bash
# Retry settings
CI_MAX_RETRIES=3                # Max retry attempts
CI_RETRY_DELAY=1000             # Initial retry delay (1s)
CI_RETRY_BACKOFF=2.0            # Backoff multiplier

# Health checks
CI_HEALTH_INTERVAL=30000        # Health check interval (30s)
CI_LOG_LEVEL=info               # Logging level
```

**Usage:**
```bash
# Start coordinator
node tools/ci_coordinator.cjs

# With custom config
CI_MAX_RETRIES=5 CI_LOG_LEVEL=debug node tools/ci_coordinator.cjs
```

### 3. Load Test Script (`tools/ci/cls_web_gate.sh`)

Bash script for generating synthetic load and stress testing the system.

**Features:**
- Configurable concurrency, duration, and event rate
- Session lifecycle simulation
- CI event generation (build, test, health)
- Real-time progress reporting
- Queue depth monitoring

**Usage:**
```bash
# Default heavy load
./tools/ci/cls_web_gate.sh

# Custom configuration
./tools/ci/cls_web_gate.sh \
  --concurrent 20 \
  --duration 1800 \
  --events-per-min 100

# Options
--concurrent N       Number of concurrent sessions (default: 10)
--duration N         Test duration in seconds (default: 900)
--events-per-min N   Events per minute (default: 50)
```

### 4. GitHub Actions Workflow (`.github/workflows/cls_web.yml`)

CI/CD workflow for automated load testing.

**Triggers:**
- PR with `[run-heavy]` in title
- PR with `cls` label
- Push to `claude/phase-20-cls-web*` branches
- Manual workflow dispatch

**Jobs:**
- **cls-web-load-test**: Runs bridge and coordinator with load generation
- **cls-web-summary**: Aggregates results and uploads artifacts

**Matrix:**
- `component: ['bridge', 'coordinator']` - Tests each independently

## Load Test Levels

### Light
- **Sessions**: 5 concurrent
- **Duration**: 5 minutes (300s)
- **Rate**: 10 events/minute
- **Total**: ~50 events
- **Use case**: Quick smoke test

### Medium
- **Sessions**: 10 concurrent
- **Duration**: 10 minutes (600s)
- **Rate**: 25 events/minute
- **Total**: ~250 events
- **Use case**: Standard integration test

### Heavy (Default)
- **Sessions**: 10 concurrent
- **Duration**: 15 minutes (900s)
- **Rate**: 50 events/minute
- **Total**: ~750 events
- **Use case**: Full stress test and production validation

## Metrics & Observability

### CLS Web Bridge Metrics

```json
{
  "totalSessions": 100,
  "activeSessions": 8,
  "completedSessions": 87,
  "failedSessions": 5,
  "eventsProcessed": 2453,
  "errors": 12
}
```

### CI Coordinator Metrics

```json
{
  "totalEvents": 750,
  "processedEvents": 732,
  "failedEvents": 3,
  "retriedEvents": 15,
  "deadLetterEvents": 3,
  "eventsByLane": {
    "gpt4": 243,
    "claude_web": 258,
    "crude": 249
  },
  "eventsByPriority": {
    "high": 245,
    "normal": 256,
    "low": 249
  }
}
```

### Queue Depths

Monitor Redis queue depths in real-time:

```bash
redis-cli llen ci:queue:high      # High priority queue
redis-cli llen ci:queue:normal    # Normal priority queue
redis-cli llen ci:queue:low       # Low priority queue
redis-cli llen ci:queue:dlq       # Dead letter queue
```

## Reports

All reports are written to `g/reports/cls_web/`:

```
g/reports/cls_web/
├── README.md                           # Documentation
├── phase20_health_latest.json          # Bridge health
├── coordinator_health_latest.json      # Coordinator health
├── load_test_summary.md                # Test summary
├── session_*.json                      # Session reports
└── dlq_*.json                          # Dead letter events
```

### Report Types

1. **Health Reports**: Real-time system health (updated every 30s)
2. **Session Reports**: Individual session lifecycle data
3. **DLQ Reports**: Failed events for debugging
4. **Load Test Summary**: Human-readable test results

## CI Integration

### Automatic Triggering

Load tests run automatically when:

1. PR title contains `[run-heavy]`
2. PR has `cls` label
3. Push to Phase 20 branch
4. Manual workflow dispatch

### Artifacts

GitHub Actions uploads artifacts after every run:

- `cls-web-health-report-*`: Health and metrics
- `cls-web-session-reports-*`: Session data
- `cls-web-dlq-reports-*`: Dead letter queue events
- `cls-web-logs-*`: Service logs

### Checking Results

```bash
# View latest workflow run
gh run list --workflow=cls_web.yml --limit 5

# Download artifacts
gh run download <run-id>

# View summary
cat cls-web-health-report-*/load_test_summary.md
```

## Troubleshooting

### High DLQ Count

**Symptoms**: Many events in dead letter queue

**Solutions**:
- Increase `CI_MAX_RETRIES`
- Check Redis connectivity
- Review `dlq_*.json` files for patterns
- Verify lane configurations

### Low Throughput

**Symptoms**: Events processed slowly, high queue depths

**Solutions**:
- Increase concurrent sessions (`CLS_MAX_CONCURRENT`)
- Check processor health
- Review Redis performance
- Scale horizontally if needed

### Session Timeouts

**Symptoms**: Many failed sessions with timeout status

**Solutions**:
- Increase `CLS_SESSION_TIMEOUT`
- Check event processing times
- Review session activity logs
- Verify health check intervals

### Redis Connection Issues

**Symptoms**: Bridge or coordinator crashes, connection errors

**Solutions**:
- Verify Redis is running: `redis-cli ping`
- Check connection params: `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`
- Review Redis logs
- Check network connectivity

## Testing Locally

### Prerequisites

```bash
# Install dependencies
npm ci

# Start Redis
docker run -d -p 6379:6379 redis:7-alpine

# Or use existing Redis
export REDIS_HOST=localhost
export REDIS_PORT=6379
```

### Run Bridge

```bash
# Terminal 1: Start bridge
node tools/cls_web_bridge.cjs
```

### Run Coordinator

```bash
# Terminal 2: Start coordinator
node tools/ci_coordinator.cjs
```

### Run Load Test

```bash
# Terminal 3: Generate load
./tools/ci/cls_web_gate.sh --concurrent 5 --duration 300 --events-per-min 10
```

### Monitor

```bash
# Terminal 4: Watch metrics
watch -n 2 'cat g/reports/cls_web/phase20_health_latest.json | jq'

# Watch queues
watch -n 1 'redis-cli llen ci:queue:high && redis-cli llen ci:queue:normal'
```

## Performance Targets

| Metric | Target | Measured |
|--------|--------|----------|
| Concurrent sessions | 10 | ✅ 10 |
| Events/minute | 50 | ✅ 50 |
| Event latency (p50) | < 100ms | 🟡 TBD |
| Event latency (p99) | < 500ms | 🟡 TBD |
| Session success rate | > 95% | 🟡 TBD |
| DLQ rate | < 1% | 🟡 TBD |

## Future Enhancements

- [ ] Horizontal scaling with multiple bridge/coordinator instances
- [ ] Dynamic concurrency adjustment based on load
- [ ] Enhanced DLQ replay mechanism
- [ ] Prometheus metrics export
- [ ] Grafana dashboards
- [ ] Alert rules for SLO violations
- [ ] Rate limiting per lane
- [ ] Event priority auto-adjustment
- [ ] Session affinity for stateful operations

## Related Documentation

- [CLS.md](../CLS.md) - Claude Code Sessions overview
- [02luka.md](../02luka.md) - Project documentation
- [g/reports/cls_web/README.md](../g/reports/cls_web/README.md) - Reports documentation
- [GitHub Actions Workflows](../.github/workflows/) - CI/CD pipelines

## Changelog

### 2025-11-06 - Initial Release
- ✅ CLS Web Bridge implementation
- ✅ CI Event Coordinator with retry logic
- ✅ Load testing script with configurable parameters
- ✅ GitHub Actions workflow integration
- ✅ Comprehensive metrics and reporting
- ✅ Documentation and troubleshooting guides

## Contact

**Phase Lead**: Claude (Anthropic AI)
**GitHub**: https://github.com/Ic1558/02luka
**Issues**: https://github.com/Ic1558/02luka/issues
**Labels**: `cls`, `ci`, `phase-20`, `enhancement`
