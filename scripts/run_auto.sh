#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CLS_SHELL="${CLS_SHELL:-/bin/bash}"
export CLS_FS_ALLOW="${CLS_FS_ALLOW:-/Volumes/lukadata:/Volumes/hd2:$HOME}"

cd "$ROOT_DIR"
exec node apps/assistant-runtime/index.mjs auto "$@"
