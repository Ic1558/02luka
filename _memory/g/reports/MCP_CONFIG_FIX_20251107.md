---
title: "MCP Configuration Crisis Resolution"
date: 2025-11-07
type: solution
category: infrastructure
severity: critical
status: resolved
tags: [mcp, cursor, configuration, troubleshooting]
---

# MCP Configuration Crisis Resolution

## Executive Summary

**Problem**: Cursor displayed critical MCP configuration errors:
- "mcpServers must be an object" format error
- "Exceeding total tools limit" (149 tools vs 80 limit)
- MCP_DOCKER duplication across multiple config files

**Solution**: Fixed configuration format, reduced server count, eliminated duplicates

**Result**: System fully operational with 55 total tools (63% reduction), optimal architecture

## Timeline

### Initial State (Before Fix)
```
Global (~/.cursor/mcp.json):
  ❌ Wrong format: {"mcpServers": {...}}
  ❌ MCP_DOCKER with 9 servers (149 tools)

Project (LocalProjects/02luka/.cursor/mcp.json):
  ❌ MCP_DOCKER duplicate
  ✅ local_02luka (14 tools)

Project (02luka/.cursor/mcp.json):
  ❌ MCP_DOCKER duplicate
  ✅ local_02luka (14 tools)

Total Tools: 149+ (exceeds 80 limit)
Errors: Multiple configuration format and duplication errors
```

### Final State (After Fix)
```
Global (~/.cursor/mcp.json):
  ✅ Correct format with version field
  ✅ MCP_DOCKER with 2 servers: github-official, fetch (41 tools, 3 prompts)

Project (LocalProjects/02luka/.cursor/mcp.json):
  ✅ local_02luka only (14 tools)

Project (02luka/.cursor/mcp.json):
  ✅ local_02luka only (14 tools)

Memory Repo (LocalProjects/02luka-memory/.cursor/mcp.json):
  ✅ Empty (inherits Global only)

Total Tools: 55 (within limit)
Errors: None
Status: 100% operational
```

## Root Causes

### 1. Configuration Format Error
**Problem**: Used wrong JSON schema
```json
// ❌ Wrong
{"mcpServers": {"MCP_DOCKER": {...}}}

// ✅ Correct
{"version": 1, "servers": {"MCP_DOCKER": {...}}}
```

**Why It Happened**: Legacy format from older MCP versions

**Fix**: Updated to new schema with version field

### 2. Tool Limit Exceeded
**Problem**: MCP_DOCKER loaded 9 servers totaling 149 tools

**Why It Happened**: Docker gateway was configured with default server set instead of minimal needed servers

**Fix**: Reduced from 9 servers to 2 servers (github-official, fetch)
```bash
# Before
"args": ["mcp", "gateway", "run"]  # Loads all 9 default servers

# After
"args": ["mcp", "gateway", "run", "--servers", "github-official,fetch"]
```

### 3. Configuration Duplication
**Problem**: MCP_DOCKER declared in 3 locations (Global + 2 Projects)

**Why It Happened**: Manual config edits without checking inheritance chain

**Fix**: Removed from Project configs, kept in Global only

## Technical Details

### Configuration Hierarchy
```
Cursor MCP Config Loading Order:
1. Global: ~/.cursor/mcp.json (applies to all workspaces)
2. Project: <workspace>/.cursor/mcp.json (workspace-specific)
3. Merge: Global + Project (but duplicates cause errors)
```

### Correct Architecture Pattern
```
Global Config:
  Purpose: Universal tools used in all workspaces
  Example: MCP_DOCKER (GitHub, web fetch)

Project Config:
  Purpose: Project-specific tools
  Example: local_02luka (filesystem access to specific paths)

DO NOT: Duplicate same server in multiple configs
DO: Keep related servers together (separation of concerns)
```

### Tool Count Breakdown
| Server | Tools | Prompts | Location | Purpose |
|--------|-------|---------|----------|---------|
| MCP_DOCKER | 41 | 3 | Global | GitHub, web fetch |
| local_02luka | 14 | 0 | Project | Filesystem access |
| **Total** | **55** | **3** | - | - |

**Target**: <80 tools (LLM performance threshold)
**Achievement**: 55 tools (31% below limit)
**Reduction**: 63% decrease from original 149 tools

## Files Modified

### Configuration Files
```
~/.cursor/mcp.json
  - Fixed format (added version field)
  - Reduced servers from 9 to 2
  - Status: ✅ Valid

~/LocalProjects/02luka/.cursor/mcp.json
  - Removed MCP_DOCKER duplicate
  - Kept local_02luka
  - Status: ✅ Valid

~/02luka/.cursor/mcp.json
  - Removed MCP_DOCKER duplicate
  - Kept local_02luka
  - Status: ✅ Valid

~/LocalProjects/02luka-memory/.cursor/mcp.json
  - No changes needed (was already empty)
  - Inherits Global config only
  - Status: ✅ Valid
```

### Scripts Created
```bash
~/mcp_prune_project_docker.zsh
  Purpose: Remove MCP_DOCKER from project configs
  Backups: Timestamped .bak files
  Validation: jq-based JSON key checking

/tmp/lock_mcp_configs.zsh
  Purpose: Create read-only locked snapshots
  Protection: Prevent Cursor auto-merge
  Restore: cp FILE.locked FILE
```

### Backups Created
```
~/.cursor/mcp.json.bak.20251108_042627
~/LocalProjects/02luka/.cursor/mcp.json.bak.20251107T214918Z
~/02luka/.cursor/mcp.json.bak.20251107T214918Z

Locked Snapshots:
~/.cursor/mcp.json.locked (read-only)
~/LocalProjects/02luka/.cursor/mcp.json.locked (read-only)
~/02luka/.cursor/mcp.json.locked (read-only)
```

## Fix Process

### Step 1: Format Correction
```bash
# Fix Global config format
cat ~/.cursor/mcp.json
# Changed from: {"mcpServers": {...}}
# Changed to: {"version": 1, "servers": {...}}

# Backed up original
cp ~/.cursor/mcp.json ~/.cursor/mcp.json.bak.20251108_042627
```

### Step 2: Reduce Server Count
```bash
# Update MCP_DOCKER args to load only needed servers
"args": ["mcp", "gateway", "run", "--servers", "github-official,fetch"]

# Result: 149 tools → 41 tools (72% reduction)
```

### Step 3: Clean Dead Configs
```bash
# Remove unused MCP entries from other config files
~/claude_desktop_mcp_config.json → empty
~/.config/claude/mcp_servers.json → empty
```

### Step 4: Remove Duplicates
```bash
# Run duplicate removal script
chmod +x ~/mcp_prune_project_docker.zsh
~/mcp_prune_project_docker.zsh

# Results:
# - Removed MCP_DOCKER from LocalProjects/02luka/.cursor/mcp.json
# - Removed MCP_DOCKER from 02luka/.cursor/mcp.json
# - Kept local_02luka in both Project configs
# - Verified Global still has MCP_DOCKER
```

### Step 5: Restart & Verify
```bash
# Restart Cursor
pkill -TERM -x "Cursor"
/Applications/Cursor.app/Contents/MacOS/Cursor ~/LocalProjects/02luka_hub.code-workspace

# Verification:
# ✅ MCP_DOCKER: 41 tools, 3 prompts
# ✅ local_02luka: 14 tools
# ✅ Browser Automation: Ready
# ✅ No errors, no duplicates
```

### Step 6: Lock Configs
```bash
# Create read-only locked snapshots
/tmp/lock_mcp_configs.zsh

# Results:
# - 3 locked files created with 444 permissions
# - Warning headers added
# - Restore instructions included
```

## Validation

### Configuration Validity
```bash
# Test Global config
jq -e '.version == 1 and (.servers | has("MCP_DOCKER"))' ~/.cursor/mcp.json
# Output: true ✅

# Test Project configs (should NOT have MCP_DOCKER)
jq -e '.mcpServers | has("MCP_DOCKER") | not' ~/LocalProjects/02luka/.cursor/mcp.json
# Output: true ✅

jq -e '.mcpServers | has("MCP_DOCKER") | not' ~/02luka/.cursor/mcp.json
# Output: true ✅
```

### Tool Count Check
```bash
# Total tools loaded in Cursor
MCP_DOCKER: 41 tools (github-official, fetch)
local_02luka: 14 tools (filesystem)
Total: 55 tools ✅ (below 80 limit)
```

### Functional Testing
```
Browser Automation: ✅ Ready (Chrome detected)
GitHub Operations: ✅ Functional (github-official tools)
Web Fetch: ✅ Functional (fetch tools)
Filesystem Access: ✅ Functional (local_02luka tools)
```

## Lessons Learned

### 1. Configuration Format Evolution
- **Lesson**: MCP config format changed from legacy `{"mcpServers": {...}}` to new `{"version": 1, "servers": {...}}`
- **Action**: Always check official docs for current schema
- **Prevention**: Validate JSON against schema on every config change

### 2. Tool Limit Awareness
- **Lesson**: Loading too many tools (149) exceeds LLM performance threshold (80)
- **Action**: Be selective about which servers to load
- **Prevention**: Regularly audit tool count: `jq '.servers | to_entries | map({key, tools: .value.tools | length})' ~/.cursor/mcp.json`

### 3. Configuration Inheritance
- **Lesson**: Cursor merges Global + Project configs, but duplicates cause errors
- **Action**: Use Global for universal tools, Project for specific tools
- **Prevention**: Document which servers belong in which config level

### 4. Backup Everything
- **Lesson**: Multiple fix iterations required, backups saved significant time
- **Action**: Always create timestamped backups before config changes
- **Prevention**: Script all config changes with automatic backup creation

### 5. Locked Snapshots
- **Lesson**: Cursor can auto-merge configs, potentially breaking careful fixes
- **Action**: Create read-only locked snapshots of working configs
- **Prevention**: Reference locked files when restoring after Cursor updates

## Future Prevention

### Configuration Management
```bash
# Add to system health check
if ! jq -e '.version == 1' ~/.cursor/mcp.json >/dev/null 2>&1; then
  echo "⚠️  MCP config format error"
fi

# Tool count monitoring
TOOL_COUNT=$(jq '[.servers[].tools // [] | length] | add' ~/.cursor/mcp.json)
if [ "$TOOL_COUNT" -gt 80 ]; then
  echo "⚠️  Tool count exceeds limit: $TOOL_COUNT/80"
fi
```

### Documentation
- Keep this report updated with any MCP config changes
- Document server selection rationale
- Maintain list of available servers and their tool counts

### Restoration Procedure
```bash
# If Cursor breaks config again:
1. Check locked snapshots exist
   ls -la ~/.cursor/mcp.json.locked

2. Restore from locked snapshot
   cp ~/.cursor/mcp.json.locked ~/.cursor/mcp.json
   chmod 644 ~/.cursor/mcp.json

3. Restart Cursor
   pkill -TERM -x "Cursor"
   cursor

4. Verify tool count
   # Check Cursor UI: Tools section
   # Should show: MCP_DOCKER (41), local_02luka (14)
```

## Related Documentation

- Multi-root workspace setup: `02luka-memory` repo creation
- Cursor launcher: `~/bin/cursor-02luka` with graceful shutdown
- Repository cleanup: Phase 1 (2GB moved to `_trash/`)
- CLS configuration: `config/cls.env`, `.luka-role` metadata

## Contact & Support

**Primary Maintainer**: CLC (Claude Code)
**Owner**: Boss (icmini)
**Report Location**: `02luka-memory/g/reports/MCP_CONFIG_FIX_20251107.md`
**Last Updated**: 2025-11-07 21:59 UTC

---

**Status**: ✅ RESOLVED
**System Health**: 100% Operational
**Next Review**: When Cursor version updates
