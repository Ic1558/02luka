#!/usr/bin/env bash
set -euo pipefail
REQ="$(cat -)"
NOW=$(date -Iseconds)
cat <<JSON
{"ok":true,"steps":[{"op":"mock","ms":123}],"result":{"mock":true},"perf":{"totalMs":123},"ts":"$NOW"}
JSON
