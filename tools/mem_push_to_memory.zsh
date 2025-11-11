#!/usr/bin/env zsh
set -euo pipefail

cd "${0:A:h}/.."

echo "== memory push =="

# ตรวจว่ามี diff จริงก่อน
if ! git diff --quiet -- _memory; then
  git commit -am "chore(memory): update _memory subtree"
fi

git subtree push --prefix=_memory memory main

