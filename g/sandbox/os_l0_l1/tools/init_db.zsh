#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
ROOT="$SCRIPT_DIR"
while [[ "$ROOT" != "/" && ! -d "$ROOT/.git" ]]; do
  ROOT="$(cd "$ROOT/.." && pwd)"
done
if [[ ! -d "$ROOT/.git" ]]; then
  echo "[init_db] unable to locate repo root from $SCRIPT_DIR" >&2
  exit 1
fi

DB_PATH="$ROOT/g/sandbox/os_l0_l1/data/os_sandbox.db"
CLI="$ROOT/g/sandbox/os_l0_l1/tools/os_l3_plan.py"

mkdir -p "${DB_PATH:h}"
python3 "$CLI" --db "$DB_PATH" init-db --force
echo "[init_db] initialized $DB_PATH"
