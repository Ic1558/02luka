# MLS Agent Integration — Read Path v1

**Date:** 2025-11-15  
**Scope:** Read-only integration for agents (Mary / CLC / CLS / Codex)

## Goals

- Provide a **single, stable CLI** for agents to query MLS lessons.
- Keep the change **read-only and low-risk** (no writers, no workflows changed).
- Align with the existing dashboard `/api/mls` parsing logic.

## New CLI

```bash
tools/mls_query.zsh summary
tools/mls_query.zsh recent --limit 20 --type failure --format json
tools/mls_query.zsh search --query "codex sandbox" --format table
```

### Commands

- `summary`
  - Prints JSON with:
    - `total`
    - `verified`
    - `by_type` map

- `recent`
  - Options:
    - `--limit` (default 20)
    - `--type <type>` (optional)
    - `--source <source>` (optional)
    - `--format json|table` (default json)

- `search`
  - Options:
    - `--query <substring>` (required; searches title+description+context)
    - `--limit` (default 50)
    - `--format json|table`

## How agents should use this

### Mary / GG / GC (planning agents)

- To get a quick picture of recent failures:

  ```bash
  tools/mls_query.zsh recent --limit 20 --type failure --format json
  ```

### CLC / Codex (code agents)

- Before proposing a fix for a repeated error:

  ```bash
  tools/mls_query.zsh search --query "path traversal" --limit 10 --format json
  ```

## Non-goals in this PR

- No write path changes to MLS.
- No CI or workflow modifications.
- No server/API changes (dashboard keeps using its own `/api/mls` handler).
