# Reality Hooks

Date: 2025-11-15

## What is a reality hook?

A reality hook is an executable check that validates the *running* 02luka system,
not just static code. It is described in `g/config/reality_hooks.yaml` and executed
via small shell scripts in `tools/reality_hooks/`.

## Current hooks

### wo_dashboard_reality

- Script: `tools/reality_hooks/wo_dashboard_reality_check.zsh`
- Verifies:
  - `/api/wos` responds and returns valid JSON
  - `/api/services` returns `summary.total` and `services[]`
  - `/api/mls` returns `entries[]` and `summary.total`
- Usage:

  ```bash
  cd ~/02luka/g
  DASHBOARD_URL=http://localhost:8080 \
    tools/reality_hooks/wo_dashboard_reality_check.zsh
  ```

- Exit codes:
  - `0` – all checks passed
  - `1` – missing endpoint / bad JSON / shape mismatch
