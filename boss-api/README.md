# Boss API

The Boss API exposes a minimal interface for listing and reading files referenced by logical human namespace keys. Paths are resolved through `g/tools/path_resolver.sh`, ensuring all access occurs via the repository mapping configuration.

## Endpoints

- `GET /api/list/:folder` — returns `{ files: [{ name }] }` for files in the specified folder.
- `GET /api/file/:folder/:name` — returns `{ name, content }` for a single file.

Only the following folders are available: `inbox`, `sent`, `deliverables`, `dropbox`, `drafts`, and `documents`.

Errors use a consistent JSON structure: `{ "message": string, "code": string }`.

## Running locally

```bash
cd boss-api
cp .env.sample .env # optional
npm install
npm run start
```

Set `SOT_PATH` in `.env` if the API is executed outside the repository; otherwise it defaults to the repo root.

The server listens on port `4000` by default.

