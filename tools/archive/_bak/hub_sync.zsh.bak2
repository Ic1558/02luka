#!/usr/bin/env zsh
set -euo pipefail
cd "$(dirname "$0")/.."

export LUKA_MEM_REPO_ROOT="${LUKA_MEM_REPO_ROOT:-${HOME}/LocalProjects/02luka-memory}"
export HUB_INDEX_PATH="${HUB_INDEX_PATH:-${PWD}/hub/index.json}"
export REDIS_URL="${REDIS_URL:-redis://:gggclukaic@127.0.0.1:6379}"

node hub/hub_autoindex.mjs
