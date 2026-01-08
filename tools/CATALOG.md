# 02luka Tool Catalog

**Location**: `tools/CATALOG.md`
**Policy**: [PRP-TOOLING-v1]

## Core Principle
1.  **Canonical Tools** live in `tools/` (or `g/tools/`). They are versioned, documented, and safe.
2.  **Temp Runners** live in `tools/_tmp/` or `~/`. They are ignored by git and ephemeral.
3.  **Promotion**: A tool moves from `_tmp` to `Canonical` only if it meets the **Promotion Criteria**.

## Canonical Tools (Ops)

| Tool Name | Path | Description | Usage |
| :--- | :--- | :--- | :--- |
| **Bridge Self-Check** | `tools/bridge_selfcheck.zsh` | Verifies inbox/outbox health | `zsh tools/bridge_selfcheck.zsh` |
| **Build Core History** | `tools/build_core_history.zsh` | Generates deterministic Core History artifacts |`zsh tools/build_core_history.zsh` |
| **Verify Core State** | `tools/verify_core_state.zsh` | Audits repo cleanliness and artifact validity | `zsh tools/verify_core_state.zsh` |
| **Save Session** | `tools/save.sh` | Commits state, harvests memory, and logs telemetry | `zsh tools/save.sh` |
| **Run Tool** | `tools/run_tool.zsh` | Single entry point for all operations | `zsh tools/run_tool.zsh <alias>` |

*(Add new canonical tools here after promotion)*

## Promotion Criteria
To promote a script from `_tmp` to `tools/`:
1.  **Idempotent**: Can run multiple times without side effects (or handles them safely).
2.  **Documented**: Has a header explaining what it does.
3.  **Error Handling**: Uses `set -euo pipefail`.
4.  **No Hardcodes**: Uses relative paths or `$HOME/02luka` env var. (No `Users/icmini` if possible, unless standard).

## Maintenance
-   **Archive**: Old tools go to `g/archive/tools/`.
-   **Clean**: `tools/_tmp/` can be emptied comfortably at any time.
