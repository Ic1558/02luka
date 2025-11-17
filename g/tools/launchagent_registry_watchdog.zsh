#!/usr/bin/env zsh

# launchagent_registry_watchdog.zsh
# Stub watchdog for LaunchAgent registry consistency.
# CURRENT STATUS: DIAGNOSTIC ONLY — DO NOT MODIFY FILES.

set -euo pipefail

SOT="${SOT:-$HOME/02luka}"

REGISTRY_FILE="$SOT/g/docs/LAUNCHAGENT_REGISTRY.md"

echo "[watchdog] LaunchAgent Registry Watchdog (STUB)"
echo "[watchdog] SOT: $SOT"
echo "[watchdog] Registry: $REGISTRY_FILE"

if [ ! -f "$REGISTRY_FILE" ]; then
  echo "[watchdog] WARNING: Registry file not found."
  exit 0
fi

# NOTE:
# - In a future PR, this script will:
#   * Parse LaunchAgent plists
#   * Compare against the registry
#   * Check for missing locked-zone notes (e.g. LPE worker)
# - For now, it only reports basic info.

echo "[watchdog] OK (stub-only, no checks implemented yet)."
exit 0

