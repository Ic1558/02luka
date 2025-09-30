# PATH KEYS (auto)

Use: `bash g/tools/path_resolver.sh human:<key>`

## Allowed keys (from mapping.json)
- version
- generated_at
- namespaces
- namespaces:human
- namespaces:human:dropbox
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

## Examples
```bash
bash g/tools/path_resolver.sh human:inbox
bash g/tools/path_resolver.sh human:sent
bash g/tools/path_resolver.sh human:deliverables
```
