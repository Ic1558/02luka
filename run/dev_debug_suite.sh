#!/usr/bin/env bash
set -euo pipefail
bash ./.codex/preflight.sh || true
bash ./run/dev_up_simple.sh
bash ./run/smoke_api_ui.sh || true
BASE_URL=http://127.0.0.1:5173 npx playwright test g/tests/ui/ui.smoke.spec.ts --project=chromium --reporter=line --timeout=15000 || true
bash ./g/tools/model_router.sh diagnostics || true
curl -s -X POST 127.0.0.1:4000/api/optimize -H 'Content-Type: application/json' -d '{"prompt":"debug suite"}' || true
