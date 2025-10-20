#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pushd "$ROOT" >/dev/null
mkdir -p knowledge/exports

echo "==> Installing local deps"
npm i sqlite3 --silent

echo "==> Full sync"
node knowledge/sync.cjs --full --export

echo "==> Stats"
node knowledge/index.cjs --stats
popd >/dev/null
