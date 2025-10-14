# GUARDRAILS (auto)
- Resolver-only paths (no absolute paths, no symlinks)
- Do NOT write under a/, c/, o/, s/
- CORS required for API
- Server-only keys must remain on the server (never expose to UI/client)
- Path traversal guard required for file reads
- Mailboxes: Inbox → Outbox → Drafts → Sent → Deliverables; dropbox is an alias to Outbox (no new storage roots)

## Tests to run
```bash
bash .codex/preflight.sh
bash g/tools/mapping_drift_guard.sh --validate
bash g/tools/clc_gate.sh
# optional smoke (if port free)
HOST=127.0.0.1 PORT=4000 node boss-api/server.cjs
curl -s http://127.0.0.1:4000/api/list/inbox | jq .
```
