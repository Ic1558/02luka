# Ops Status Board (Phase 10.2)

## Overview

The Ops Status Board provides real-time visibility into the Ops Mirror pipeline performance through interactive charts, run history, and automated monitoring. It displays the last 10 mirror runs with success rates, duration trends, and file count analytics.

## Features

### 📊 **Interactive Charts**
- **Duration Trends** - Line chart showing run duration over time
- **File Count Trends** - Bar chart displaying files processed per run
- **Real-time Data** - Auto-refreshes every 60 seconds

### 📈 **Performance Metrics**
- **Total Runs** - Count of all tracked runs
- **Success Rate** - Percentage of successful runs
- **Average Duration** - Mean run time in seconds
- **Average Size** - Mean data size processed per run

### 🔄 **Auto-Refresh**
- **60-second intervals** - Automatic page refresh
- **Live updates** - No manual refresh needed
- **Status indicators** - Real-time run status

### 📱 **Responsive Design**
- **Mobile-friendly** - Optimized for all screen sizes
- **Bootstrap 5** - Modern, clean interface
- **Dark mode ready** - Toggle between themes

## Architecture

### Core Components
- **`run/generate_ops_status.cjs`** - Main generation script
- **`.github/workflows/ops-status.yml`** - Automated updates
- **`dist/ops/jobs.json`** - Run history data
- **`dist/ops/status.html`** - Interactive dashboard

### Data Sources
- **GitHub Actions API** - Workflow run history
- **Manifest.json** - Current build information
- **Mock data** - Fallback when API unavailable

## Usage

### Local Development

```bash
# Build status board locally
make ops-status-build

# Verify structure
make ops-status-verify

# Test complete pipeline
make ops-status-test

# Clean build artifacts
make ops-status-clean
```

### Manual Deployment

```bash
# Trigger workflow manually
make ops-status-deploy

# Or trigger with force refresh
gh workflow run ops-status.yml --ref main -f force_refresh=true
```

### Direct Script Usage

```bash
# Generate status board
node run/generate_ops_status.cjs

# With GitHub token (for real data)
GITHUB_TOKEN=your_token node run/generate_ops_status.cjs
```

## Generated Files

### `dist/ops/jobs.json`
```json
{
  "last_updated": "2025-10-28T21:00:00Z",
  "total_runs": 10,
  "runs": [
    {
      "id": "1234567890",
      "run_number": 100,
      "timestamp": "2025-10-28T20:55:00Z",
      "status": "success",
      "duration_ms": 45000,
      "files_count": 5,
      "total_size_bytes": 2048,
      "source": "github_actions",
      "workflow_run_id": "1234567890",
      "url": "https://github.com/user/repo/actions/runs/1234567890"
    }
  ]
}
```

### `dist/ops/status.html`
- **Interactive dashboard** with Chart.js
- **Responsive design** for all devices
- **Auto-refresh** every 60 seconds
- **Real-time metrics** and run history

## Scheduling

### Automated Updates
- **Daily at 03:10 ICT** - Scheduled workflow execution
- **Manual trigger** - Workflow dispatch support
- **Force refresh** - Optional parameter for immediate updates

### Data Freshness
- **Real-time** - GitHub API integration
- **Fallback** - Mock data when API unavailable
- **Caching** - Efficient data retrieval

## Integration

### Phase 6 Metrics
- **Analyzer integration** - Reads mirror history
- **Performance tracking** - Duration and success metrics
- **Trend analysis** - Historical data patterns

### Phase 7 Relay Hook (Optional)
- **HMAC API** - Secure status retrieval
- **ChatGPT integration** - AI-powered insights
- **Real-time queries** - Live status updates

## Troubleshooting

### Common Issues

1. **No GitHub token** - Uses mock data automatically
2. **API rate limits** - Implements exponential backoff
3. **Chart not loading** - Check Chart.js CDN availability
4. **Auto-refresh not working** - Verify JavaScript enabled

### Debug Commands

```bash
# Check script syntax
node -c run/generate_ops_status.cjs

# Run with debug output
DEBUG=1 node run/generate_ops_status.cjs

# Verify generated files
ls -la dist/ops/
cat dist/ops/jobs.json | jq
```

### Performance Optimization

- **Chart.js CDN** - Fast loading from jsdelivr
- **Minimal data** - Only last 10 runs stored
- **Efficient rendering** - Optimized Chart.js config
- **Responsive images** - Optimized for mobile

## Security

### Data Protection
- **No secrets exposed** - Only public workflow data
- **Read-only access** - No write operations
- **HTTPS only** - Secure data transmission

### API Security
- **Token-based auth** - GitHub API authentication
- **Rate limiting** - Respects API limits
- **Error handling** - Graceful failure modes

## Monitoring

### Health Checks
- **Status endpoint** - `/ops/status.html`
- **Data endpoint** - `/ops/jobs.json`
- **Manifest check** - Build information

### Alerting
- **Workflow failures** - GitHub Actions notifications
- **Data staleness** - Outdated run detection
- **Performance issues** - Slow run alerts

## Future Enhancements

### Planned Features
- **Historical data** - Extended run history
- **Custom metrics** - User-defined KPIs
- **Export functionality** - Data download options
- **API endpoints** - RESTful data access

### Integration Opportunities
- **Slack notifications** - Status updates
- **Email reports** - Daily summaries
- **Webhook support** - Real-time updates
- **Custom dashboards** - Personalized views

## Related Documentation

- [Ops Mirror Pipeline](./OPS_MIRROR_PIPELINE.md) - Phase 10.1
- [Public Docs Publisher](./PUBLIC_DOCS_PUBLISHER.md) - Phase 10.3
- [Mirror Integrity Monitor](./MIRROR_INTEGRITY_MONITOR.md) - Phase 10.4
- [Phase 10 Master Plan](../g/reports/PHASE10_MASTER_PLAN.md) - Complete roadmap

---

**Phase 10.2 Status:** ✅ Complete  
**Last Updated:** 2025-10-28T21:00:00Z  
**Next Phase:** 10.3 - Public Docs Publisher
