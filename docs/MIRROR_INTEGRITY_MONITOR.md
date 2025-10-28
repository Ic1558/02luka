# Mirror Integrity Monitor (Phase 10.4)

## Overview

The Mirror Integrity Monitor performs daily link and hash verification of the public mirror, ensuring all published URLs are accessible and content integrity is maintained. It generates alerts for broken links, content mismatches, and performance issues.

## Features

### 🔍 **URL Verification**
- **HTTP status checks** - Validates 200, 301, 302 responses
- **Content type validation** - Ensures correct MIME types
- **Response time monitoring** - Tracks latency metrics
- **Size validation** - Checks file sizes are reasonable

### 🔐 **Hash Verification**
- **SHA256 hashing** - Content integrity verification
- **Manifest comparison** - Optional hash manifest support
- **Change detection** - Identifies unauthorized modifications
- **Tamper detection** - Alerts on content changes

### 🚨 **Alert System**
- **Critical failures** - Immediate alerts for required URLs
- **Warning conditions** - Alerts for non-critical issues
- **Performance alerts** - Slow response time notifications
- **Phase 6 integration** - Connects to existing alert engine

### 📊 **Reporting**
- **JSON reports** - Machine-readable integrity data
- **TSV exports** - Tabular format for analysis
- **Historical tracking** - Long-term trend analysis
- **Dashboard integration** - Real-time status display

## Architecture

### Core Components
- **`run/verify_mirror_integrity.cjs`** - Main verification script
- **`.github/workflows/mirror-integrity.yml`** - Automated monitoring
- **`dist/ops/integrity.json`** - Current integrity status
- **`dist/ops/integrity.tsv`** - Tabular integrity data

### Monitoring Targets
- **Critical URLs** - Required for system operation
- **Important URLs** - Should be accessible
- **Optional URLs** - May be unavailable

## Usage

### Local Development

```bash
# Run integrity check
make mirror-check

# Generate report
make mirror-report

# Check alerts
make mirror-alerts

# Test complete pipeline
make mirror-test
```

### Manual Deployment

```bash
# Trigger workflow manually
gh workflow run mirror-integrity.yml --ref main

# With custom base URL
gh workflow run mirror-integrity.yml --ref main -f base_url=https://custom.domain.com
```

### Direct Script Usage

```bash
# Run with default URL
node run/verify_mirror_integrity.cjs

# Run with custom URL
MIRROR_BASE_URL=https://custom.domain.com node run/verify_mirror_integrity.cjs
```

## Generated Files

### `dist/ops/integrity.json`
```json
{
  "check_timestamp": "2025-10-28T21:00:00Z",
  "base_url": "https://ops.theedges.work",
  "overall_status": "healthy",
  "summary": {
    "total": 10,
    "successful": 10,
    "failed": 0,
    "critical_failed": 0,
    "total_time": 2500
  },
  "checks": [
    {
      "url": "/ops/status.html",
      "status_code": 200,
      "content_type": "text/html",
      "size_bytes": 14884,
      "latency_ms": 245,
      "success": true,
      "critical": true,
      "sha256": "abc123..."
    }
  ]
}
```

### `dist/ops/integrity.tsv`
- **Tabular format** - Easy analysis and import
- **All check results** - Complete verification data
- **Machine readable** - Automated processing support

### Alert Files
- **`g/state/alerts/integrity_*.json`** - Individual alert files
- **`g/logs/ops_alerts.log`** - Centralized alert log
- **`g/state/integrity_history.jsonl`** - Historical data

## Monitoring Targets

### Critical URLs (Must be 200)
- `/ops/_health.html` - Health check endpoint
- `/ops/manifest.json` - Build manifest
- `/ops/latest.json` - Current OPS data
- `/docs/index.html` - Docs landing page

### Important URLs (Should be 200)
- `/ops/latest.tsv` - Tabular OPS data
- `/ops/dashboard.html` - OPS dashboard
- `/ops/status.html` - Status board
- `/ops/jobs.json` - Run history

### Optional URLs (May be 404)
- `/ops/dashboard.html` - If API unavailable
- `/docs/assets/docs.css` - If not generated
- `/docs/assets/docs.js` - If not generated

## Alert Conditions

### Critical Alerts
- **Required URL returns 404** - System unavailable
- **Required URL returns 500** - Server error
- **Content type mismatch** - Wrong MIME type
- **Hash mismatch** - Content tampering detected

### Warning Alerts
- **Optional URL returns 404** - Feature unavailable
- **High latency (>5s)** - Performance issue
- **Unexpected content type** - Configuration issue
- **Size anomaly** - Unusual file size

### Info Alerts
- **Slow response (>2s)** - Performance monitoring
- **Content type warning** - Non-critical mismatch
- **Size warning** - Unusual but acceptable size

## Scheduling

### Automated Monitoring
- **Daily at 04:00 ICT** - Scheduled verification
- **Manual trigger** - Workflow dispatch support
- **Custom base URL** - Override default URL

### Data Retention
- **Integrity history** - Unlimited retention
- **Alert files** - 30-day retention
- **Log files** - 90-day retention

## Integration

### Phase 6 Alert Engine
- **Alert type** - `mirror_integrity`
- **Severity levels** - `critical`, `warning`, `info`
- **Payload format** - Structured alert data
- **Cooldown periods** - Prevents alert storms

### Phase 10.1 - Ops Mirror Pipeline
- **Monitors output** - Verifies published content
- **Dependency tracking** - Ensures pipeline success
- **Quality assurance** - Validates mirror integrity

### Phase 10.2 - Live Mirror Status Board
- **Status integration** - Shows integrity status
- **Historical data** - Tracks integrity trends
- **Alert display** - Shows current issues

### Phase 10.3 - Public Docs Publisher
- **Docs verification** - Ensures docs are accessible
- **Content validation** - Verifies HTML generation
- **Asset checking** - Validates CSS/JS files

## Troubleshooting

### Common Issues

1. **All URLs return 404** - Base URL incorrect or service down
2. **High latency** - Network issues or server overload
3. **Content type mismatches** - Server configuration issues
4. **Hash mismatches** - Content changes or caching issues

### Debug Commands

```bash
# Check script syntax
node -c run/verify_mirror_integrity.cjs

# Run with debug output
DEBUG=1 node run/verify_mirror_integrity.cjs

# Check specific URL
curl -I https://ops.theedges.work/ops/status.html

# Verify integrity files
ls -la dist/ops/integrity.*
cat dist/ops/integrity.json | jq
```

### Performance Optimization

- **Parallel requests** - Concurrent URL checking
- **Timeout handling** - Prevents hanging requests
- **Retry logic** - Handles temporary failures
- **Efficient hashing** - Stream-based SHA256 calculation

## Security

### Data Protection
- **No secrets exposed** - Only public URL verification
- **Read-only access** - No write operations
- **HTTPS only** - Secure data transmission

### Alert Security
- **Rate limiting** - Prevents alert storms
- **Cooldown periods** - Reduces noise
- **Severity filtering** - Focus on critical issues

## Monitoring

### Health Checks
- **Integrity endpoint** - `/ops/integrity.json`
- **Alert files** - `g/state/alerts/`
- **Log files** - `g/logs/ops_alerts.log`

### Alerting
- **Workflow failures** - GitHub Actions notifications
- **Critical failures** - Immediate alert generation
- **Performance issues** - Latency monitoring

## Future Enhancements

### Planned Features
- **Custom URL lists** - User-defined monitoring targets
- **Threshold configuration** - Adjustable alert conditions
- **Historical analysis** - Trend reporting and analytics
- **API endpoints** - RESTful integrity data access

### Integration Opportunities
- **Slack notifications** - Real-time alert delivery
- **Email reports** - Daily integrity summaries
- **Webhook support** - External system integration
- **Custom dashboards** - Personalized monitoring views

## Related Documentation

- [Ops Mirror Pipeline](./OPS_MIRROR_PIPELINE.md) - Phase 10.1
- [Live Mirror Status Board](./OPS_STATUS_BOARD.md) - Phase 10.2
- [Public Docs Publisher](./PUBLIC_DOCS_PUBLISHER.md) - Phase 10.3
- [Phase 10 Master Plan](../g/reports/PHASE10_MASTER_PLAN.md) - Complete roadmap

---

**Phase 10.4 Status:** ✅ Complete  
**Last Updated:** 2025-10-28T21:10:00Z  
**Phase 10.x Status:** Complete
