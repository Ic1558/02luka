# Local Agent Review — Usage (Phase 1)

**Version:** v1.0  
**Scope:** SPEC v1.3 / Phase 1 single-call review

## Quickstart

```bash
# Offline dry-run (no API call)
python tools/local_agent_review.py staged --offline --format console

# Normal run (requires LOCAL_REVIEW_ACK=1 and ANTHROPIC_API_KEY)
export LOCAL_REVIEW_ACK=1
export ANTHROPIC_API_KEY=sk-...
python tools/local_agent_review.py staged --format markdown

# Tip: .env.local is auto-loaded from repo root (or CWD) for keys like ANTHROPIC_API_KEY and LOCAL_REVIEW_ACK.
```

## Modes

- `staged` (default): review staged changes
- `unstaged`: review unstaged changes
- `last-commit`: review `HEAD~1..HEAD`
- `branch --target feature`: review against base fallback (`origin/main` → `main` → `master`)
- `range --base main --target feature`: explicit range

## Flags

- `--format {markdown,json,console}`
- `--output <path>` (optional; custom paths are never rotated)
- `--offline/--dry-run`: skip LLM call
- `--no-interactive`: no prompts (hooks use this)
- `--strict`: treat warnings as failures
- `--verbose`: debug logs

## Exit Codes

- `0`: success (no critical; warnings allowed unless `--strict`)
- `1`: blocking issues (critical or strict warnings)
- `2`: system error (git/config/LLM)
- `3`: security block (PrivacyGuard secret match)

## Hooks

`tools/hooks/pre_commit_local_review.sh` (manual opt-in):

```bash
export LOCAL_REVIEW_ENABLED=1
ln -s ../../tools/hooks/pre_commit_local_review.sh .git/hooks/pre-commit
```

Behavior: runs staged review with `--no-interactive --strict`; blocks on critical (and warnings in strict mode) or security block (exit 3).

## Reports & Telemetry

- Default reports: `g/reports/reviews/` (rotates, keep last 20)
- Telemetry: `g/telemetry/local_agent_review.jsonl` (one JSON line per run)
- Custom `--output` paths are never rotated.
