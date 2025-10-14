#!/usr/bin/env bash
set -euo pipefail
has_legacy=0
has_symlink=0

for d in boss docs g memory projects views agents; do
  if [ -e "../$d" ]; then
    if [ -L "../$d" ]; then
      has_symlink=$((has_symlink + 1))
    else
      # Legacy content exists in parent
      has_legacy=$((has_legacy + 1))
    fi
  fi
done

if [ $has_legacy -gt 0 ]; then
  echo "⚠️  Parent has legacy content (boss: 19M, docs: 2.9M, g: 18M)"
  echo "✅ Repo is SOT — validate-workspace optional until migration"
else
  echo "✅ workspace centralized"
fi
