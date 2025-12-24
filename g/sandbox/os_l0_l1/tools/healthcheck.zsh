#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
ROOT="$SCRIPT_DIR"
while [[ "$ROOT" != "/" && ! -d "$ROOT/.git" ]]; do
  ROOT="$(cd "$ROOT/.." && pwd)"
done
if [[ ! -d "$ROOT/.git" ]]; then
  echo "[healthcheck] unable to locate repo root from $SCRIPT_DIR" >&2
  exit 1
fi

HC_ROOT="$ROOT/g/sandbox/os_l0_l1"
DB_PATH="$HC_ROOT/data/os_sandbox.db"
SCENARIO_PATH="scenarios/L3_PLAN_FLOW_001.json"

EXTENDED=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --extended) EXTENDED=true ;;
    --db) DB_PATH="$2"; shift ;;
    *)
      echo "Usage: $0 [--extended] [--db <path>]" >&2
      exit 1
      ;;
  esac
  shift
done

echo "[healthcheck] DB=$DB_PATH extended=$EXTENDED"
python3 "$HC_ROOT/tools/os_l3_plan.py" --db "$DB_PATH" verify-chain

if $EXTENDED; then
  echo "[healthcheck] running extended L3 scenario"
  zsh "$HC_ROOT/tools/init_db.zsh"
  (cd "$HC_ROOT" && python3 tools/os_l3_plan.py --db "$DB_PATH" apply-scenario "$SCENARIO_PATH")
  (cd "$HC_ROOT" && python3 tools/os_l3_plan.py --db "$DB_PATH" apply-scenario "scenarios/L3_CONTRACT_FLOW_001.json")
  python3 "$HC_ROOT/tools/os_l3_plan.py" --db "$DB_PATH" verify-chain
  (cd "$HC_ROOT" && python3 tools/os_l3_plan.py --db "$DB_PATH" list-plans)
  (cd "$HC_ROOT" && python3 tools/os_l3_plan.py --db "$DB_PATH" list-items --plan-id P-L3-DEMO-001)
  (cd "$HC_ROOT" && python3 tools/os_l3_plan.py --db "$DB_PATH" list-items --plan-id P-L3-CONTRACT-001)
fi
