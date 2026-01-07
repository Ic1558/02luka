# 02LUKA Port Ownership Policy

## Rules
| Port | Service | Owner Process | Policy |
| :--- | :--- | :--- | :--- |
| **8000** | **Core API** | `api_server.py` | **Exclusive**. Backend services only. |
| **8001** | **Reserved** | - | Spare for debugging or secondary tools. |
| **8080** | **Proxy** | `antigravity-claude-proxy` | **Managed**. Do not kill. |
| **N/A** | **Gemini Bridge** | `gemini_bridge.py` | **No Port**. Uses file-based `magic_bridge/`. |

## Registry
- Source of truth: `ports.registry.yml`

## Enforcement
- Use `tools/ports_check.zsh` to verify owners.
- If unknown process grabs 8000: **KILL**.
- If `api_server.py` grabs 8000: **KEEP**.
