#!/usr/bin/env zsh
set -euo pipefail

cd "${0:A:h}/.."
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

echo "== memory pull (branch: $BRANCH) =="
git fetch memory
git subtree pull --prefix=_memory memory main --squash -m "chore(memory): subtree pull"

