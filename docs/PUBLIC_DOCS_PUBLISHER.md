# Public Docs Publisher (Phase 10.3)

## Overview

The Public Docs Publisher converts all `g/manuals/*.md` files to static HTML under `/docs/` on GitHub Pages, creating a searchable public knowledge base synchronized nightly with internal documentation.

## Features

### 📚 **Documentation Conversion**
- **Markdown to HTML** - Custom converter (no external dependencies)
- **Preserves structure** - Headers, lists, code blocks, links
- **Category organization** - Groups by manual type
- **Auto-generated index** - Table of contents for all docs

### 🔍 **Search Functionality**
- **Client-side search** - JavaScript-based indexing
- **Real-time filtering** - Instant search results
- **Category filtering** - Filter by manual type
- **Fuzzy matching** - Approximate string matching

### 🎨 **User Interface**
- **Dark mode toggle** - Light/dark theme switching
- **Responsive design** - Mobile-friendly layout
- **Copy link functionality** - Shareable section links
- **Navigation sidebar** - Easy document browsing

### 📱 **Mobile Support**
- **Responsive layout** - Works on all screen sizes
- **Touch-friendly** - Optimized for mobile devices
- **Fast loading** - Optimized assets and delivery

## Architecture

### Core Components
- **`run/publish_docs.cjs`** - Main conversion script
- **`.github/workflows/docs-publish.yml`** - Automated publishing
- **`dist/docs/`** - Generated HTML output
- **`dist/docs/assets/`** - CSS and JavaScript assets

### File Processing
- **Source:** `g/manuals/*.md` files
- **Output:** `dist/docs/*.html` files
- **Assets:** `dist/docs/assets/docs.css`, `dist/docs/assets/docs.js`
- **Index:** `dist/docs/index.html` with search and navigation

## Usage

### Local Development

```bash
# Build documentation locally
make docs-build

# Verify structure
make docs-verify

# Test complete pipeline
make docs-test

# Clean build artifacts
make docs-clean
```

### Manual Deployment

```bash
# Trigger workflow manually
make docs-deploy

# Or trigger with force refresh
gh workflow run docs-publish.yml --ref main -f force_refresh=true
```

### Direct Script Usage

```bash
# Generate documentation
node run/publish_docs.cjs
```

## Generated Files

### `dist/docs/index.html`
- **Search interface** - Real-time document search
- **Documentation index** - Categorized list of all docs
- **Statistics** - Document count, categories, total size
- **Navigation** - Sidebar with document categories

### Individual HTML Pages
- **Converted from Markdown** - Full HTML conversion
- **Consistent layout** - Header, sidebar, content, footer
- **Dark mode support** - Theme toggle functionality
- **Copy links** - Shareable section links

### Assets
- **`docs.css`** - Complete styling (light/dark themes)
- **`docs.js`** - Search, theme toggle, copy links

## Scheduling

### Automated Publishing
- **Daily at 03:20 ICT** - Scheduled workflow execution
- **Manual trigger** - Workflow dispatch support
- **Force refresh** - Optional parameter for immediate updates

### Data Sources
- **Markdown files** - `g/manuals/*.md`
- **Excluded patterns** - `_private`, `_internal`, `_draft`, `_wip`
- **Included extensions** - `.md` files only

## Integration

### Phase 10.1 - Ops Mirror Pipeline
- **Scheduled after** - Docs publish after Ops Mirror
- **Shared infrastructure** - GitHub Pages deployment
- **Cross-linking** - Links between docs and ops data

### Phase 10.4 - Mirror Integrity Monitor
- **Monitored URLs** - `/docs/index.html` and all doc pages
- **Integrity checks** - Daily verification of all docs
- **Alert integration** - Failed docs trigger alerts

## Troubleshooting

### Common Issues

1. **No markdown files found** - Creates sample documentation
2. **Conversion errors** - Check markdown syntax
3. **Missing assets** - Verify CSS/JS generation
4. **Search not working** - Check JavaScript console

### Debug Commands

```bash
# Check script syntax
node -c run/publish_docs.cjs

# Run with debug output
DEBUG=1 node run/publish_docs.cjs

# Verify generated files
ls -la dist/docs/
ls -la dist/docs/assets/
```

### Performance Optimization

- **Custom markdown converter** - No external dependencies
- **Minimal assets** - Optimized CSS and JavaScript
- **Efficient search** - Client-side indexing
- **Responsive images** - Optimized for mobile

## Security

### Data Protection
- **Public content only** - No secrets or private data
- **Read-only access** - No write operations
- **HTTPS only** - Secure data transmission

### Content Filtering
- **Excluded patterns** - Private/internal documents
- **File type validation** - Markdown files only
- **Size limits** - Reasonable file size limits

## Monitoring

### Health Checks
- **Index page** - `/docs/index.html`
- **Asset files** - CSS and JavaScript availability
- **Search functionality** - Client-side search working

### Alerting
- **Workflow failures** - GitHub Actions notifications
- **Missing files** - Integrity monitor alerts
- **Performance issues** - Slow page load alerts

## Future Enhancements

### Planned Features
- **Historical versions** - Document versioning
- **Export functionality** - PDF/EPUB export
- **API endpoints** - RESTful document access
- **Custom themes** - User-selectable themes

### Integration Opportunities
- **Slack notifications** - New document alerts
- **Email reports** - Weekly documentation summaries
- **Webhook support** - Real-time updates
- **Custom dashboards** - Personalized views

## Related Documentation

- [Ops Mirror Pipeline](./OPS_MIRROR_PIPELINE.md) - Phase 10.1
- [Live Mirror Status Board](./OPS_STATUS_BOARD.md) - Phase 10.2
- [Mirror Integrity Monitor](./MIRROR_INTEGRITY_MONITOR.md) - Phase 10.4
- [Phase 10 Master Plan](../g/reports/PHASE10_MASTER_PLAN.md) - Complete roadmap

---

**Phase 10.3 Status:** ✅ Complete  
**Last Updated:** 2025-10-28T21:10:00Z  
**Next Phase:** 10.4 - Mirror Integrity Monitor
