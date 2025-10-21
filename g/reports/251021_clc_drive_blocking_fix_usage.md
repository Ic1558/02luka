# 251021 – CLC Drive Blocking Fix Usage

## Switches
- `KNOW_EXPORT_MODE=drive` (default) → export to Google Drive path (now non-blocking via temp-then-move)
- `KNOW_EXPORT_MODE=local` + `KNOW_EXPORT_DIR=/path` → export into a local folder (no Drive)
- `KNOW_EXPORT_MODE=off` → skip exports

### Examples
```bash
# fastest dev loop (no exports)
KNOW_EXPORT_MODE=off node knowledge/sync.cjs

# export locally (fast) for later copy/sync
KNOW_EXPORT_MODE=local KNOW_EXPORT_DIR="$HOME/02luka/tmp_exports" node knowledge/sync.cjs

# normal mode (on Drive, but non-blocking)
KNOW_EXPORT_MODE=drive node knowledge/sync.cjs
```

### Notes
- All JSON artifacts are written via g/tools/helpers/writeArtifacts.js (tmp → atomic move).
- For heavy sessions, prefer KNOW_EXPORT_MODE=local and run a periodic rsync later.
