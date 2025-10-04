#!/usr/bin/env bash
set -euo pipefail
echo "[verify] preflight"
bash ./.codex/preflight.sh
echo "[verify] dev up"
bash ./run/dev_up_simple.sh
echo "[verify] smoke"
bash ./run/smoke_api_ui.sh
echo "[verify] OK"
