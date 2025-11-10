# MLS Viewer Documentation

The MLS (Machine Learning System) viewer is a unified command-line tool for querying and analyzing MLS lesson entries across both modern daily ledgers and legacy databases.

## Quick Start

```bash
# View today's entries
~/02luka/tools/mls_view.zsh --today

# Show summary statistics
~/02luka/tools/mls_view.zsh --summary

# View today's summary
~/02luka/tools/mls_view.zsh --today --summary

# Search for specific patterns
~/02luka/tools/mls_view.zsh --grep 'artifact'

# Filter by producer
~/02luka/tools/mls_view.zsh --producer=clc

# Filter by type
~/02luka/tools/mls_view.zsh --type=solution
```

## Data Sources

The viewer automatically handles two data sources:

1. **Daily Ledgers** (Primary): `~/02luka/mls/ledger/YYYY-MM-DD.jsonl`
   - Modern format with structured source metadata
   - Organized by date
   - Default source for date-specific queries

2. **Legacy Database** (Fallback): `~/02luka/g/knowledge/mls_lessons.jsonl`
   - Older format, automatically normalized to modern schema
   - Used when daily ledger is not found or empty
   - All legacy entries are tagged with `producer: "legacy"`

## Options Reference

### Date Selection

- `--today` - Show entries from today (default behavior)
- `--date YYYY-MM-DD` - Show entries from a specific date
- `--file PATH` - Read from a specific JSONL file

### Filtering

- `--type=TYPE` - Filter by entry type
  - Values: `solution`, `failure`, `improvement`, `pattern`, `antipattern`
- `--producer=PROD` - Filter by producer
  - Values: `cls`, `codex`, `clc`, `gemini`, `legacy`
- `--context=CTX` - Filter by context
  - Values: `ci`, `bridge`, `wo`, `local`, `legacy`
- `--by FIELD=VALUE` - Generic field filter (e.g., `type=solution`)
- `--grep PATTERN` - Search in title, summary, and tags
- `--limit=N` - Limit output to N entries

### Output Modes

- `--summary` - Show aggregated statistics only
  - Entry counts by type, producer, context
  - Date range of entries
  - Total entry count
- `--json` - Output raw JSON array
- *(default)* - Pretty-printed table format

## Examples

### Daily Workflow

```bash
# Morning: Check yesterday's lessons
~/02luka/tools/mls_view.zsh --date 2025-11-09

# View high-level summary
~/02luka/tools/mls_view.zsh --today --summary

# Find all CI-related solutions
~/02luka/tools/mls_view.zsh --type=solution --context=ci
```

### Research & Analysis

```bash
# Find all failures to learn from
~/02luka/tools/mls_view.zsh --type=failure

# Search for artifact-related entries
~/02luka/tools/mls_view.zsh --grep 'artifact'

# Get top 5 recent entries from specific producer
~/02luka/tools/mls_view.zsh --producer=clc --limit=5

# Export all entries for external processing
~/02luka/tools/mls_view.zsh --json > export.json
```

### CI/CD Integration

```bash
# In CI pipeline: verify entries exist
if ~/02luka/tools/mls_view.zsh --today --summary | grep -q "Total entries: [1-9]"; then
  echo "✅ MLS entries found for today"
else
  echo "⚠️  No MLS entries found for today"
fi
```

## Entry Schema

### Modern Format (Daily Ledgers)

```json
{
  "ts": "2025-11-10T12:34:56+07:00",
  "type": "solution",
  "title": "Entry Title",
  "summary": "Brief description",
  "memo": "Detailed context",
  "source": {
    "producer": "clc",
    "context": "ci",
    "session": "session_20251110.md",
    "workflow": "build",
    "run_id": "12345",
    "artifact": "artifact.tar.gz",
    "artifact_size": 1024
  },
  "links": {
    "wo_id": "WO-123456"
  },
  "tags": ["tag1", "tag2"],
  "author": "clc",
  "confidence": 0.9
}
```

### Legacy Format (Auto-normalized)

Legacy entries are automatically converted to the modern schema with these defaults:
- `producer`: "legacy"
- `context`: "legacy"
- `author`: "legacy"
- `confidence`: 0.5

## Tips & Best Practices

1. **Use --summary first** - Get an overview before diving into details
2. **Combine filters** - `--type=failure --context=ci` narrows down to actionable insights
3. **Grep is case-insensitive** - Searches title, summary, and tags
4. **Legacy fallback is automatic** - No special flags needed
5. **JSON output for scripts** - Use `--json` when piping to other tools

## Related Tools

- `~/02luka/tools/mls_capture.zsh` - Create new MLS entries
- `~/02luka/g/knowledge/mls_index.json` - High-level statistics index

## Troubleshooting

**"Ledger file not found"**
- Check if date is valid: `ls ~/02luka/mls/ledger/`
- Viewer will automatically fall back to legacy DB if available

**"jq not found"**
- Install jq: `brew install jq` (macOS) or `apt-get install jq` (Linux)

**No entries shown**
- Verify file has content: `wc -l ~/02luka/mls/ledger/$(date +%Y-%m-%d).jsonl`
- Try legacy DB explicitly: `--file ~/02luka/g/knowledge/mls_lessons.jsonl`

**Summary shows unexpected counts**
- Filters are applied before summary calculation
- Use `--summary` without other filters to see all entries

## Session Reports

MLS session reports are stored in:
- `~/02luka/g/reports/mls/sessions/` - Per-session analysis and insights

For migration history, see `migration_report_v2.txt` in this directory.
