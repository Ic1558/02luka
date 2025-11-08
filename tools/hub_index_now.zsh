#!/usr/bin/env zsh
set -euo pipefail
cd "$(dirname "$0")/.."
node hub/hub_autoindex.mjs
