#!/usr/bin/env bash
set -euo pipefail

# Ops Sandbox Runner — dry-run + allowlist
# Usage:
#   tools/ops_sandbox.sh --dry-run "docker compose config -q"
#   tools/ops_sandbox.sh --dry-run "make -n deploy"
#   tools/ops_sandbox.sh --dry-run "yq '.github.workflows' -P .github/workflows/ci.yml"

ALLOWLIST_REGEX='\b(docker compose config -q|make -n\b|yq\b|jq\b|bash -n\b)\b'
DENYLIST_REGEX='\b(rm\s+-rf|dd\s+if=|mkfs|mount|userdel|groupdel|chown|chmod\s+[^-].*\s+-R|shutdown|reboot|launchctl\s+(load|unload)|brew\s+uninstall)\b'

log_dir="g/reports/ci"
mkdir -p "$log_dir"
log_file="$log_dir/ops_sandbox_$(date -u +%Y%m%dT%H%M%SZ).log"

dry_run=1
cmd=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    --exec)    dry_run=0; shift ;;
    *)         cmd="$*"; break ;;
  esac
done

if [[ -z "${cmd}" ]]; then
  echo "Usage: tools/ops_sandbox.sh [--dry-run|--exec] \"<command>\"" | tee -a "$log_file"
  exit 2
fi

echo "[sandbox] $(date -u +%FT%TZ) cmd=${cmd}" | tee -a "$log_file"

# quick safety checks
if [[ "$cmd" =~ $DENYLIST_REGEX ]]; then
  echo "[block] denied by denylist" | tee -a "$log_file"; exit 3
fi
if ! [[ "$cmd" =~ $ALLOWLIST_REGEX ]]; then
  echo "[block] not in allowlist" | tee -a "$log_file"; exit 4
fi

# always force dry-run style by transforming some commands
transformed="$cmd"
# make → enforce -n
if [[ "$transformed" =~ ^make\  && ! "$transformed" =~ \ -n ]]; then
  transformed="${transformed/ make / make -n }"
fi
# docker compose → config -q only (no up/down)
if [[ "$transformed" =~ ^docker\ compose\  && ! "$transformed" =~ config\ -q ]]; then
  echo "[block] only 'docker compose config -q' is allowed" | tee -a "$log_file"; exit 5
fi

echo "[sandbox] effective: ${transformed}" | tee -a "$log_file"

if [[ $dry_run -eq 1 ]]; then
  echo "[dry-run] not executing, printing intent only." | tee -a "$log_file"
  exit 0
fi

# execute in subshell and capture
set +e
out="$(bash -lc "$transformed" 2>&1)"
code=$?
set -e

printf "%s\n" "$out" | tee -a "$log_file"
echo "[exit] code=${code}" | tee -a "$log_file"
exit $code

