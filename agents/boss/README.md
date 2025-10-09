# Agent: boss

**Memory:** [memory/boss/](../../memory/boss/)
**Owner:** boss
**Type:** Catalog & Index Management

## Scope
- Maintain reports catalog (boss/reports/index.md)
- Maintain memory catalog (boss/memory/index.md)
- Auto-generate UX layer over SOT data
- Provide "By Project" grouping of reports
- Enable quick navigation and discovery
- Generate daily HTML dashboards
- Surface latest reports and memory entries

## Commands
- Refresh catalogs: `make boss-refresh` (when script exists)
- Generate daily HTML: `make boss-daily`
- Search: `make boss-find q="…"`
- View status: `make status`

## Generated Files
- `boss/reports/index.md` - Reports catalog
- `boss/memory/index.md` - Memory catalog
- `views/ops/daily/index.html` - Daily dashboard

## Architecture
- **Option C (Hybrid Spine):**
  - SOT: `g/reports/`, `memory/{agent}/`
  - UX: `boss/reports/`, `boss/memory/` (auto-generated)
  - Guards: validate-zones, pre-push hooks
  - Daily proof: CI workflow at 08:12 ICT
