# Trading Journal Import Manual

Use this guide to normalize broker CSV exports into the shared `trading_journal.jsonl` ledger and optionally emit an MLS lesson entry for visibility.

## 1. Prepare your CSV export

1. Export the trade history/statement from your broker.
2. Save the CSV inside the repo under `g/trading/import/`. Example: `g/trading/import/statement_2025-11-15.csv`.
3. (Optional) Keep raw statements in `g/trading/import/raw/` if you want to archive the untouched files.

The importer expects headers that roughly match: `Date`, `Time`, `Symbol`, `Side`, `Volume`, `Price`, `Fee`, `Tax`, `Net P/L`, `Order ID`, `Remark`. Extra columns are ignored.

## 2. Run the importer

From the repo root:

```bash
cd ~/02luka

# Basic import
tools/trading_import.zsh g/trading/import/statement_2025-11-15.csv

# Specify market/account, append, and emit an MLS entry
tools/trading_import.zsh g/trading/import/statement_2025-11-15.csv \
  --market TFEX \
  --account "BIZ-01" \
  --append \
  --emit-mls
```

### Arguments
- `CSV_PATH` (required): path to the exported CSV.
- `--market`: default market label for rows that do not include one (e.g., `TFEX`, `SET`, `CME`).
- `--account`: default account name.
- `--append`: append to the existing JSONL (otherwise overwrite).
- `--emit-mls`: add a lightweight MLS lesson stub documenting the import.

## 3. Output locations

- Normalized journal: `g/trading/trading_journal.jsonl` (one JSON object per line).
- Optional MLS entry: `g/knowledge/mls_lessons.jsonl`.

## 4. Notes

- You can re-run imports as needed. Without `--append`, the JSONL is overwritten.
- Works with multiple brokers as long as their columns map to the expected headers listed above.
- Keep the CSV exports around (e.g., under `g/trading/import/raw/`) if you want a paper trail.
