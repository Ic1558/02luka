# Phase 18 — Ops Sandbox Runner (safe dry-run)

## What

A safe runner to validate ops commands **without mutating the system**.

- Allowlisted: `docker compose config -q`, `make -n`, `yq`, `jq`, `bash -n`

- Denylisted: destructive/system-level commands

- Logs to `g/reports/ci/ops_sandbox_*.log`

## Why

- CI-friendly, fast validate

- Prevent accidental destructive ops during reviews

## Usage

```bash
# dry-run (default)
tools/ops_sandbox.sh --dry-run "docker compose config -q"
tools/ops_sandbox.sh --dry-run "make -n deploy"
tools/ops_sandbox.sh --dry-run "yq '.on' -P .github/workflows/ci.yml"
tools/ops_sandbox.sh --dry-run "jq '.name' .github/workflows/ci.yml 2>/dev/null || true"

# (optional) exec mode for local dev (still allowlist-guarded)
tools/ops_sandbox.sh --exec "make -n deploy"
```
