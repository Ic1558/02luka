#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Ops Status
# @raycast.mode fullOutput
# @raycast.packageName 02luka

# Optional parameters:
# @raycast.icon ✅
# @raycast.refreshTime 5m

# Documentation:
# @raycast.description Quick ops-status report (health, verify, telemetry, spool)
# @raycast.author icmini

cd ~/02luka || exit 1
./tools/bridgectl.zsh ops-status
