#!/usr/bin/env zsh
set -euo pipefail

id="${1:?PR number required}"

tmp="g/reports/ci/quickcheck_${id}_$(date +%Y%m%d_%H%M%S).md"

git fetch origin pull/${id}/head:tmp/pr-${id}

git switch tmp/pr-${id}

bash tools/ci/validate.sh || true

{

  echo "# Quickcheck PR #$id"

  echo "## tail boss-api log"

  echo '```'

  tail -n 200 .tmp/boss-api.out.log 2>/dev/null || true

  echo '```'

} > "$tmp"

git switch - &>/dev/null || true

git branch -D tmp/pr-${id} &>/dev/null || true

echo "Report: $tmp"

