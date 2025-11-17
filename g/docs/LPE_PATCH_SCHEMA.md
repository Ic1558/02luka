# LPE Patch Schema (v1)

LPE (Local Patch Engine) applies Safe Idempotent Patch (SIP) operations to the local checkout.
Provide patches as YAML documents that include metadata and a list of operations.

## Document shape

```yaml
meta:
  id: "LPE-YYYYMMDD-XXX"   # unique identifier for traceability
  source: "GG"             # origin of the patch (GG, Codex, GC, etc.)
  reason: "Short reason"
ops:
  - path: "g/tmp/example.txt"
    mode: "append"
    content: |
      hello world
```

### Fields
- `meta` (object): optional metadata for logging.
- `ops` (array, required): ordered list of patch operations.

### Supported modes
- `append` (default): append `content` to the file, ensuring a trailing newline; skipped if content already exists verbatim.
- `replace_block`: replace the first occurrence of `match` with `content`.
- `insert_before`: insert `content` immediately before the first occurrence of `match`.
- `insert_after`: insert `content` immediately after the first occurrence of `match`.

### Common keys per op
- `path` (string, required): repository-relative path. Must stay inside allowed roots (g, core, LaunchAgents, tools, etc.). Absolute paths or `..` are rejected.
- `mode` (string, optional): one of the supported modes; defaults to `append`.
- `content` (string, optional): text to write.
- `match` (string, required for insert/replace modes): anchor text used for insertion or replacement.

## Examples

### Append text to a scratch file
```yaml
meta:
  id: "LPE-20251117-001"
  source: "GG"
  reason: "Append test payload"
ops:
  - path: "g/tmp/lpe_test.txt"
    mode: "append"
    content: |
      Added by LPE
```

### Replace a block inside a plist
```yaml
ops:
  - path: "LaunchAgents/com.02luka.mcp.search.plist"
    mode: "replace_block"
    match: "ProgramArguments"
    content: |
      ProgramArguments
      <array>
        <string>/usr/local/bin/node</string>
        <string>server/index.js</string>
      </array>
```

### Insert before a sentinel comment
```yaml
ops:
  - path: "core/context/router.py"
    mode: "insert_before"
    match: "# CONTEXT_ROUTING_SENTINEL"
    content: "ROUTER_PREFLIGHT = True\n"
```
