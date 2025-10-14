#!/usr/bin/env bash
set -e
bash ./.codex/preflight.sh
bash ./run/dev_up_simple.sh
bash ./run/smoke_api_ui.sh
