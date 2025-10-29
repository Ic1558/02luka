#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${REPO_ROOT}/package.json" ]]; then
  echo "[fix-ci] Unable to locate repository root from ${SCRIPT_DIR}" >&2
  exit 1
fi

cd "${REPO_ROOT}"

echo "[fix-ci] Repository root: ${REPO_ROOT}"

echo "[fix-ci] Step 1/4: Installing Node dependencies"
npm ci

echo "[fix-ci] Step 2/4: Syntax checks for Phase 4 services"
node --check gateway/health_proxy.js
node --check run/mcp_webbridge.cjs
node --check api/boss_api.cjs

echo "[fix-ci] Step 3/4: Running smoke tests (local stub)"
bash scripts/smoke.sh

echo "[fix-ci] Step 4/4: Generating self-review report"
node agents/reflection/self_review.cjs --days=7 --output "test-results/self_review_ci.md" >/dev/null

echo "[fix-ci] All validation steps completed"
