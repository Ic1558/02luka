#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [[ "${LOCAL_REVIEW_ENABLED:-0}" != "1" ]]; then
  exit 0
fi

if [[ ! -f "${ROOT}/tools/local_agent_review.py" ]]; then
  echo "[local-review-hook] local_agent_review.py not found; skipping."
  exit 0
fi

echo "[local-review-hook] running local agent review (staged, no-interactive)..."
python3 "${ROOT}/tools/local_agent_review.py" staged --no-interactive --quiet --strict
rc=$?

if [[ $rc -eq 0 ]]; then
  exit 0
fi

if [[ $rc -eq 1 ]]; then
  echo "[local-review-hook] blocking commit due to issues (exit $rc)." >&2
  exit 1
fi

if [[ $rc -eq 3 ]]; then
  echo "[local-review-hook] blocking commit due to detected secrets (exit $rc)." >&2
  exit 1
fi

echo "[local-review-hook] local review failed (exit $rc)." >&2
exit 1
