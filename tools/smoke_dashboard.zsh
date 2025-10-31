#!/usr/bin/env zsh
set -euo pipefail
curl -fsS http://127.0.0.1:4100/health | grep -qi 'ok' && echo "smoke: OK"
