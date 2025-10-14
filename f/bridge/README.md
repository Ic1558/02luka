# Bridge Workspaces

The bridge namespace is the hand-off point between the Codex sandbox and external operators.

- `inbox/` — drop assets from the outside world that the sandbox can consume.
- `outbox/` — Codex writes files here for humans to pull out of the sandbox.
- `processed/` — archive location for items that have been acknowledged.

These directories are intentionally committed to make the "universal bridge" tangible: point the
folders at shared volumes, sync services, or tunnels on the host machine so that real artifacts can
flow in both directions.
