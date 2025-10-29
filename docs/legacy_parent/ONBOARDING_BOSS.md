# Boss Workflow (Option C)

## Quick Start

**Work exclusively from the `boss/` directory** - everything you need is here.

### Daily Workflow

1. **Open catalogs:**
   - `boss/reports/index.md` - All reports, latest first + grouped by project
   - `boss/memory/index.md` - Agent session memory

2. **Create new content:**
   ```bash
   # Create a report
   PROJECT=<proj> TAGS=a,b make report name="Title"

   # Create a memo/session note
   TAGS=x,y make mem agent=clc title="Note"
   ```

3. **Check system health:**
   ```bash
   make status  # Latest proof + quick metrics
   ```

4. **Search across everything:**
   ```bash
   make boss-find q="search term"
   ```

## Rules (Single Source of Truth)

- **Reports** → `g/reports/` only
- **Sessions** → `memory/<agent>/` only
- **Boss catalogs** → Auto-generated, never edit manually

## Front-Matter Template

All new reports/sessions require front-matter:

```yaml
---
project: general  # or: diplomat110, system-stabilization, etc.
tags: [ops, deployment, fix]  # categories
---
# Your Title

Content here...
```

## Quick Commands

```bash
make boss          # Refresh catalogs + show paths
make status        # Latest proof + metrics
make validate-zones # Check structure compliance
make proof         # Generate full structure proof
make boss-find q="keyword"  # Search everything
```

## Structure SLA

- Out-of-zone files: ≤ 1% (or < 10 files)
- Findability: ≤ 2 clicks from `boss/`
- Daily Proof: Must pass; fix same day if fails

## Emergency (BREAKGLASS)

If guards block urgent work, see `docs/BREAKGLASS.md`
