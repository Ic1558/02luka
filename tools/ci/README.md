# CI Tools

- `ci_watcher.sh` — finds failing PRs and triggers reruns (5m cadence via LaunchAgent).
- `ci_auto_decision.zsh` — sets auto-merge, auto-fix conflicts, auto-rerun.
- `ci_coordinator.cjs` — subscribes to Redis `ci:events` and orchestrates actions.
- `redis_pub.zsh` — tiny publisher for `ci:events`.

## Dispatch shortcuts
See `tools/dispatch_quick.zsh`:
- `ci:watch`, `ci:watch:on`, `ci:watch:off`
- `ci:rerun`, `ci:bus:rerun`
- `auto:merge`, `auto:quiet`, `auto:label`, `auto:fix-conflict`, `auto:decision`
