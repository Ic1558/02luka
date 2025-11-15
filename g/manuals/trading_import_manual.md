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

## 4. Timestamp Format Support

The importer accepts the following timestamp formats:

### Supported Date Formats
- `YYYY-MM-DD` (e.g., `2025-11-15`)
- `DD/MM/YYYY` (e.g., `15/11/2025`)
- `MM/DD/YYYY` (e.g., `11/15/2025`)
- `YYYYMMDD` (e.g., `20251115`)

### Supported Time Formats
- `HH:MM:SS` (e.g., `09:15:22`)
- `HH:MM` (e.g., `09:15`)
- `HHMMSS` (e.g., `091522`)

### Supported Combined Formats
- `YYYY-MM-DD HH:MM:SS` (e.g., `2025-11-15 09:15:22`)
- `YYYY-MM-DD HH:MM` (e.g., `2025-11-15 09:15`)
- `DD/MM/YYYY HH:MM:SS` (e.g., `15/11/2025 09:15:22`)
- `DD/MM/YYYY HH:MM` (e.g., `15/11/2025 09:15`)
- `MM/DD/YYYY HH:MM:SS` (e.g., `11/15/2025 09:15:22`)
- `MM/DD/YYYY HH:MM` (e.g., `11/15/2025 09:15`)
- `YYYYMMDD HHMMSS` (e.g., `20251115 091522`)

### ISO-8601 Formats
- `YYYY-MM-DDTHH:MM:SS` (e.g., `2025-11-15T09:15:22`)
- `YYYY-MM-DDTHH:MM:SS±HH:MM` (with timezone, e.g., `2025-11-15T09:15:22+07:00`)
- `YYYY-MM-DDTHH:MM` (e.g., `2025-11-15T09:15`)

**Important:**
- All timestamps are normalized to ISO-8601 format (`YYYY-MM-DDTHH:MM:SS`) before being persisted.
- Unknown or invalid timestamp formats are rejected, and the row is skipped with an error message.
- The importer validates timestamps against the `trading_journal.schema.json` schema to ensure compliance.

## 5. Error Handling

- **Invalid timestamps**: Rows with timestamps that cannot be parsed are skipped. A warning message is printed to stderr with details about the skipped row.
- **Schema validation**: If `jsonschema` is installed, entries are validated against `g/schemas/trading_journal.schema.json` before being persisted. Invalid entries are skipped with an error message.
- **Missing required fields**: Rows without a `symbol` or valid `side` are skipped.

## 6. Notes

- You can re-run imports as needed. Without `--append`, the JSONL is overwritten.
- Works with multiple brokers as long as their columns map to the expected headers listed above.
- Keep the CSV exports around (e.g., under `g/trading/import/raw/`) if you want a paper trail.
- For schema validation, install `jsonschema`: `pip install jsonschema` (optional but recommended).
