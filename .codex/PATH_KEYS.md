# PATH KEYS (auto)

Use: `bash g/tools/path_resolver.sh human:<key>`

## Allowed keys (from mapping.json)
- version
- generated_at
- updated_at_utc
- namespaces
- namespaces:human
- namespaces:human:dropbox
- namespaces:human:outbox
- namespaces:human:inbox
- namespaces:human:sent
- namespaces:human:deliverables
- namespaces:bridge
- namespaces:bridge:inbox
- namespaces:bridge:outbox
- namespaces:bridge:processed
- namespaces:reports
- namespaces:reports:system
- namespaces:reports:runtime
- namespaces:status
- namespaces:status:system
- namespaces:status:tickets
- namespaces:codex
- namespaces:codex:templates
- namespaces:codex:prompts
- namespaces:codex:master_prompt
- namespaces:codex:golden_prompt
- namespaces:codex:memory_bridge
- namespaces:codex:autosave
- namespaces:codex:gate
- status_snapshot
- status_snapshot:mcp_health
- status_snapshot:config_errors
- status_snapshot:system_health_percent
- tiers
- tiers:hidden
- tiers:hidden:0
- tiers:hidden:1
- tiers:hidden:2

## Examples
```bash
bash g/tools/path_resolver.sh human:inbox
bash g/tools/path_resolver.sh human:sent
bash g/tools/path_resolver.sh human:deliverables
```
