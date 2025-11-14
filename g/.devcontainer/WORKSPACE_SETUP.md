# 🧩 02LUKA DevContainer Workspace Setup Guide

_Last updated: 2025-10-31_

---

## ⚙️ Overview

This development container provides a **self-starting hybrid environment** for the 02LUKA system.
It automatically:

1. Mounts the host directory `/Users/icmini/02luka` as `/host02luka`
2. Launches the local stub services (Boss API, Health Proxy, MCP Bridge)
3. Opens the combined workspace file `02luka.code-workspace`
   - `/workspaces/g` → active GitHub repo
   - `/host02luka` → live runtime mirror of the host system

---

## 🧱 Directory Structure Inside the Container

```
/workspaces/g               → Your repo (git-controlled)
├── .devcontainer/
├── tools/
├── run/
└── logs/

/host02luka                → Live host mount
├── CLS/
├── agents/
├── bridge/
└── …
```

Both appear in Cursor's sidebar automatically when the container starts.

---

## 🪄 Auto-Start Sequence

During container startup (`postStartCommand`):

| Step | Action | Log |
|------|---------|------|
| 1 | Validate `/host02luka` mount | `Host mount OK` |
| 2 | Launch stub services | `logs/devcontainer.log` |
| 3 | Auto-open workspace | `02luka.code-workspace` appears in Cursor |
| 4 | Log all events | `/workspaces/g/logs/devcontainer.log` |

Stub services run in the background:
- **Port 4000** – Boss API Stub
- **Port 3002** – Health Proxy Stub
- **Port 3003** – MCP Bridge Stub

---

## 🧪 Quick Verification

After rebuild:

```bash
# Check mount
test -d /host02luka && echo "✅ SOT mount OK"

# Check CLS agent link
test -f /host02luka/CLS/agents/CLS_agent_latest.md && echo "✅ CLS link OK"

# Check services
curl -s http://localhost:4000/health  && echo "✅ Boss API OK"
curl -s http://localhost:3002/status  && echo "✅ Health Proxy OK"
curl -s http://localhost:3003/health  && echo "✅ MCP Bridge OK"

# View logs
tail -n 20 logs/devcontainer.log
```

---

## 🧭 Rebuilding or Resetting

Rebuild anytime to re-initialize the workspace and services:

1. **Cmd + Shift + P** → Dev Containers: Rebuild and Reopen in Container
2. Wait until logs show "Devcontainer UP"
3. Confirm both folders appear in the Cursor sidebar

---

## 🧩 Notes for CLS Integration

- The symlink `CLS_agent_latest.md` now uses relative paths → works inside container.
- `/host02luka` provides CLS read/write access to all local memory zones and bridge paths.
- No absolute host paths are required anymore.

---

## 🧰 Troubleshooting

| Issue | Fix |
|-------|-----|
| Workspace not auto-opening | Run `code /workspaces/g/02luka.code-workspace` manually once; it will persist next run |
| Exit 127 errors | Already prevented (`command -v code` guard in postStartCommand) |
| Logs missing | Ensure `logs/` exists under `/workspaces/g` |
| Services not responding | `bash tools/ensure_stubs.sh` to restart manually |

---

## 🏁 Summary

✅ Auto-mount host
✅ Auto-start stubs
✅ Auto-open workspace
✅ CLS ready and mounted
✅ Logs stored in `/workspaces/g/logs/`

This file is safe to commit in `.devcontainer/WORKSPACE_SETUP.md` so all teammates get identical setup.

---

_Created automatically by GG + CLC hybrid deployment pipeline, Phase 12.4_
