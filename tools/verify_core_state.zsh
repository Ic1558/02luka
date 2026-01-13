#!/usr/bin/env zsh
set -euo pipefail

# Adapted for current environment
REPO="$HOME/02luka"
cd "$REPO"

echo "== repo =="
pwd
echo

echo "== git status =="
git status --porcelain -uno
if [[ -n "$(git status --porcelain -uno)" ]]; then
  echo "FAIL: repo is dirty"
  exit 1
fi
echo "OK: repo clean"
git --no-pager log -1 --oneline
echo

# Adjusted paths for this environment
DECISION_LOG="g/telemetry/decision_log.jsonl"
RULES_FILE="g/core_history/rule_table.json" # Using the one we generate since g/rules doesn't exist
COREH_DIR="g/core_history"

echo "== decision_log check =="
if [[ -f "$DECISION_LOG" ]]; then
  CNT=$(wc -l < "$DECISION_LOG" | tr -d ' ')
  echo "OK: $DECISION_LOG exists (lines=$CNT)"
else
  echo "WARN: $DECISION_LOG missing (path may differ)"
fi
echo

echo "== rules check =="
if [[ -f "$RULES_FILE" ]]; then
  SHA=$(shasum -a 256 "$RULES_FILE" | awk '{print $1}')
  echo "OK: $RULES_FILE sha256=$SHA"
else
  echo "WARN: $RULES_FILE missing (path may differ)"
fi
echo

echo "== core_history artifacts check =="
if [[ -d "$COREH_DIR" ]]; then
  ls -la "$COREH_DIR" || true
  echo

  for f in latest.json rule_table.json index.json; do
    if [[ -f "$COREH_DIR/$f" ]]; then
      echo "-- validate JSON: $COREH_DIR/$f"
      python3 -c "import json; json.load(open('$COREH_DIR/$f','r')); print('OK')"
      echo "size_bytes=$(wc -c < "$COREH_DIR/$f" | tr -d ' ')"
    else
      echo "INFO: missing $COREH_DIR/$f (not generated yet)"
    fi
    echo
  done

  if [[ -f "$COREH_DIR/latest.md" ]]; then
    echo "-- latest.md size_bytes=$(wc -c < "$COREH_DIR/latest.md" | tr -d ' ')"
    echo "-- latest.md preview:"
    head -n 20 "$COREH_DIR/latest.md"
  else
    echo "INFO: missing $COREH_DIR/latest.md (not generated yet)"
  fi
else
  echo "INFO: $COREH_DIR not present (aggregation not run yet)"
fi
echo

echo "== quick bridge sanity (optional file-based) =="
# Checking existence of bridge directories
[[ -d "bridge/inbox" ]] && echo "OK: bridge/inbox exists" || echo "WARN: bridge/inbox missing"
[[ -d "bridge/outbox" ]] && echo "OK: bridge/outbox exists" || echo "WARN: bridge/outbox missing"
[[ -d "bridge/processed" ]] && echo "OK: bridge/processed exists" || echo "WARN: bridge/processed missing"
echo

echo "DONE: verification checks complete"
