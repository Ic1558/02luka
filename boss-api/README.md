# 02LUKA Boss API

## Overview
- Port: 4000 (configurable via PORT)
- Raw HTTP server (no Express)
- Endpoints:
  - POST /api/optimize
  - POST /api/chat-with-nlu-router

## Setup
1) cp boss-api/.env.sample boss-api/.env
2) bash ./run/dev_up_simple.sh

## Notes
- Keep server.cjs as canonical API entrypoint
- Avoid server.js (legacy)

## Incoming (merged)
# boss-api

A minimal Node.js HTTP server that exposes read-only access to Boss Workspace folders.

## Requirements

- Node.js 18+

## Setup

1. (Optional) Copy `.env.sample` to `.env` and adjust values.
2. Install dependencies (none required).

## Run

```bash
node server.js
```

The server listens on `PORT` (default `4000`).

## API

- `GET /api/list/:folder` – List files in an allowed folder.
- `GET /api/file/:folder/:name` – Retrieve file contents from an allowed folder.

Allowed folders: `inbox`, `sent`, `deliverables`, `dropbox`, `drafts`, `documents`.

All file paths are resolved via `g/tools/path_resolver.sh` using `human:<folder>` keys to respect the Single Source of Truth mapping.
