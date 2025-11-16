#!/usr/bin/env bash
set -euo pipefail
BASE="$HOME/02luka"
source "$BASE/venv/kim_bot/bin/activate"
# shellcheck disable=SC2046
export $(grep -v '^\s*#' "$BASE/config/kim.env" | xargs -I{} echo {})
exec python "$BASE/agents/kim_bot/kim_telegram_bot.py"
