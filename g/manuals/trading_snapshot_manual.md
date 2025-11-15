# Trading Snapshot CLI Manual

## Overview
`tools/trading_snapshot.zsh` transforms the JSONL journal produced by the trading importer into a human-readable snapshot for any day or custom period. Each run emits a Markdown report under `g/reports/trading/` and, with `--json`, an optional machine-readable JSON companion.

## Requirements
- `jq` is **not** required for this script, but `python3` must be available (it ships with the workspace image).
- `g/trading/trading_journal.jsonl` must exist. The file is created by `tools/trading_import.zsh` in the importer PR.

## Usage
Run the script from the repository root (`~/02luka/g`):

```bash
# Snapshot for the current local day
tools/trading_snapshot.zsh --day today

# Specific day with market/account filters
tools/trading_snapshot.zsh --day 2025-11-15 --market TFEX --account BIZ-01

# Custom inclusive range
tools/trading_snapshot.zsh --from 2025-11-10 --to 2025-11-15 --symbol S50Z25

# Emit JSON summary (stdout) plus the Markdown + JSON files
tools/trading_snapshot.zsh --day 2025-11-15 --json
```

### Supported Flags
- `--day <YYYY-MM-DD|today>`: Summarize a single day. Use `today` to auto-resolve.
- `--from <YYYY-MM-DD>` and `--to <YYYY-MM-DD>`: Inclusive custom range.
- `--market`, `--account`, `--symbol`: Optional filters.
- `--json`: Prints the summary JSON to stdout and stores `trading_snapshot_<range>[filters].json` next to the Markdown file.

## Output
Reports live under `g/reports/trading/` with these names:
- `trading_snapshot_<YYYY-MM-DD>[filters].md` for single days.
- `trading_snapshot_<FROM>_<TO>[filters].md` for custom ranges.
- Matching `.json` file when `--json` is used.

When market/account/symbol filters are supplied, the report name gains slugified suffixes such as `_market-TFEX` or `_account-biz-01` so snapshots from different filter combinations never overwrite each other.

Each Markdown file includes:
1. **Summary**: trades, gross/net PnL, win rate, avg win/loss, max gain/loss.
2. **By Symbol**: trades, net PnL, win rate, volume.
3. **By Strategy**: trades, net PnL, win rate per `strategy_tag` (falls back to `unlabeled`).
4. **Time Buckets**: hourly net PnL and trade counts for quick pacing diagnostics.

## Suggested Workflow
1. After importing trades for the day, run `tools/trading_snapshot.zsh --day <date>`.
2. Drop the generated Markdown (and JSON if needed) into your archive (NAS/Drive) or share in the trading channel.
3. Use the `--json` flag for automation pipelines (e.g., piping into Sheets or Slack bots).

## Troubleshooting
- **"journal not found"**: Ensure `g/trading/trading_journal.jsonl` exists or rerun the importer.
- **Empty sections**: The script intentionally prints `No data.` if a filter excludes all trades or if a field is missing from the journal entries.
- **Timezone**: The script treats dates using the first 10 characters of the trade timestamp (`YYYY-MM-DD`). Ensure the importer writes ISO-8601 timestamps.
