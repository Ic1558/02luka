## Summary

* Add `tools/trading_import.zsh` for importing broker CSV statements into the normalized JSONL ledger
* Optional MLS lesson stub emission for TTA/MLS analysis
* Define `g/schemas/trading_journal.schema.json` plus CSV template example
* Document ingestion flow in `g/manuals/trading_import_manual.md`

## Fixes

✅ **Timestamp Parsing Fix (Resolves Code Review P1)**
- `parse_timestamp()` now returns `None` for invalid/unrecognized formats (strict rejection)
- Rows with invalid timestamps are skipped with detailed logging
- Schema validation enforces ISO-8601 `date-time` format
- Prevents downstream consumers from receiving non-normalized timestamps

**Before:** Unrecognized formats like `15-11-2025 09:15` were passed through as raw text  
**After:** Invalid formats return `None`, row is skipped with error log

## Testing

```bash
tools/trading_import.zsh g/trading/import/statement_example.csv --market TFEX --account BIZ-01 --emit-mls
```

## Status

- ✅ Merge conflicts resolved (dashboard.js, trading_snapshot.zsh)
- ✅ WIP commits squashed into single commit
- ✅ Timestamp fix verified and working
- ✅ Ready for review/merge

classification:  
task_type: PR_FEAT  
primary_tool: codex_cli  
needs_pr: true  
security_sensitive: false  
reason: "Adds a trading journal CSV importer that normalizes trades into JSONL and optionally emits an MLS entry for TTA/MLS analysis."

