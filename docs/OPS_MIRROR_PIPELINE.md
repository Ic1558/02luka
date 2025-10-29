# Ops Mirror Pipeline (Phase 10.1)

## Overview

The Ops Mirror Pipeline automatically publishes Live Ops outputs to GitHub Pages as a static, read-only "Ops Mirror". This provides public access to operational data without requiring authentication or access to private systems.

## What It Does

- **Nightly Automation**: Runs at 02:50 Asia/Bangkok (19:50 UTC)
- **Data Sources**: Fetches from Boss API or falls back to cached data
- **Static Output**: Generates clean HTML, JSON, and TSV files
- **Public Access**: Publishes to GitHub Pages for public consumption

## Architecture

```
Live Ops System → Boss API → GitHub Actions → GitHub Pages
                     ↓
                Cached Data (fallback)
```

## Generated Files

The pipeline creates the following files in `dist/ops/`:

- **`_health.html`** - Health check endpoint (returns OK status)
- **`manifest.json`** - Build metadata (version, timestamp, build_id)
- **`latest.json`** - Current OPS summary with Docker VM metrics
- **`latest.tsv`** - Tabular format of OPS data
- **`dashboard.html`** - Rendered dashboard (if API available)
- **`.nojekyll`** - Enables SPA support on GitHub Pages

## Usage

### Local Development

```bash
# Build Ops Mirror locally (from cache)
make ops-mirror-local

# Verify structure
make ops-mirror-verify

# Test complete pipeline
make ops-mirror-test

# Clean build artifacts
make ops-mirror-clean
```

### Manual Deployment

```bash
# Trigger workflow manually
make ops-mirror-deploy

# Or trigger with specific source
gh workflow run ops-mirror.yml --ref main -f source=cache
```

### Direct Script Usage

```bash
# Build from cache
./g/tools/build_ops_mirror.zsh --from-cache

# Build from API
./g/tools/build_ops_mirror.zsh --from-api=https://ops.theedges.work/api/ops/latest
```

## Data Sources

### Primary (API)
- **OPS Summary**: `GET https://ops.theedges.work/api/ops/latest`
- **Dashboard**: `GET https://ops.theedges.work/api/ops/dashboard`

### Fallback (Cache)
- **Parsed JSON**: `~/Library/02luka_runtime/ops/ops_summary_parsed.json`
- **Table TSV**: `~/Library/02luka_runtime/ops/ops_summary_table.tsv`
- **Dashboard HTML**: Any cached dashboard files

## Public URLs

Once deployed, the following URLs are available:

- **Health Check**: `https://[username].github.io/02luka/ops/_health.html`
- **Manifest**: `https://[username].github.io/02luka/ops/manifest.json`
- **Latest Data**: `https://[username].github.io/02luka/ops/latest.json`
- **Table Data**: `https://[username].github.io/02luka/ops/latest.tsv`
- **Dashboard**: `https://[username].github.io/02luka/ops/dashboard.html`

## Caching Strategy

- **JSON Files**: `Cache-Control: no-store` (always fresh)
- **HTML Files**: `Cache-Control: max-age=60` (1 minute cache)
- **Static Assets**: Standard GitHub Pages caching

## Troubleshooting

### Build Failures

1. **Check API availability**:
   ```bash
   curl -s https://ops.theedges.work/api/ops/latest
   ```

2. **Verify cache data**:
   ```bash
   ls -la ~/Library/02luka_runtime/ops/
   ```

3. **Test script locally**:
   ```bash
   ./g/tools/build_ops_mirror.zsh --from-cache
   ```

### Deployment Issues

1. **Check workflow status**:
   ```bash
   gh run list --workflow=ops-mirror.yml
   ```

2. **View workflow logs**:
   ```bash
   gh run view [run-id] --log
   ```

3. **Verify Pages deployment**:
   - Check GitHub Pages settings
   - Verify artifact upload
   - Check deployment logs

### Data Issues

1. **Missing VM metrics**: Ensure Docker VM data is included in OPS summary
2. **Empty TSV**: Check JSON to TSV conversion logic
3. **Missing dashboard**: API may be unavailable during build

## Security

- **Public Data Only**: No secrets or private data exposed
- **Read-Only**: Static files only, no dynamic content
- **No Authentication**: Public access without credentials
- **Cached Fallback**: Works even when live systems are down

## Monitoring

- **Build Status**: Check GitHub Actions workflow runs
- **Data Freshness**: Monitor manifest.json timestamps
- **Health Checks**: Use `_health.html` for uptime monitoring
- **Error Tracking**: Review workflow logs for issues

## Rollback

To disable the pipeline:

1. **Disable workflow**: Go to GitHub Actions → ops-mirror.yml → Disable
2. **Delete workflow**: Remove `.github/workflows/ops-mirror.yml`
3. **Clean Pages**: Remove `ops/` directory from Pages deployment

## Future Enhancements

- **Historical Data**: Archive previous runs
- **Metrics Dashboard**: Visual charts and graphs
- **API Endpoints**: RESTful access to data
- **Real-time Updates**: WebSocket or Server-Sent Events
- **Custom Domains**: Use custom domain for Pages

## Related Documentation

- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Ops System Documentation](./OPS_SYSTEM.md)
- [Boss API Documentation](../boss-api/API_REFERENCE.md)
