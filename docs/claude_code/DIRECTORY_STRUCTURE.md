# Claude Code Directory Structure

**Status:** ✅ Phase 1.5 - Correctly Implemented (2025-11-12)

## Answer: "Why Can't We Use Both?"

**We DO use both!** They serve different purposes:

```
~/02luka/
├── .claude/              ← Cross-editor (any Claude Code implementation)
│   ├── settings.json           Team config, plan mode, hooks
│   └── context-map.json        Namespace resolution
│
└── .cursor/              ← Cursor-specific (only Cursor reads this)
    ├── commands/               Slash commands (/feature-dev, etc.)
    └── templates/              Cursor templates
```

## Why This Separation?

### `.claude/` - Universal Settings
- **Purpose:** Configuration that works across ALL Claude Code implementations
- **Used by:** Standalone Claude Code CLI, Cursor, any future editors
- **Contains:**
  - `settings.json` - Team settings (plan mode, hooks, metrics)
  - `context-map.json` - Logical namespace mappings
  - Future: `workflows/`, `policies/`

### `.cursor/` - Cursor Extensions
- **Purpose:** Features specific to Cursor editor integration
- **Used by:** Cursor only
- **Contains:**
  - `commands/*.md` - Slash commands (Cursor's command palette)
  - `templates/*.md` - Template expansion (Cursor feature)
  - `mcp.json` - MCP server configuration (Cursor's MCP client)

## Why It Matters

### Wrong: Commands in `.claude/commands/`
```
.claude/
└── commands/
    └── feature-dev.md  ← Cursor doesn't look here!
```
**Result:** "Unknown slash command: feature-dev" ❌

### Correct: Commands in `.cursor/commands/`
```
.cursor/
└── commands/
    └── feature-dev.md  ← Cursor finds it here!
```
**Result:** `/feature-dev` works ✅

## Implementation

### Phase 1.5 Files Created

**Cross-editor (`.claude/`):**
```json
// .claude/settings.json
{
  "team": "02LUKA",
  "plan_mode": true,
  "stop_hooks": ["quality_gate", "verify_deployment"],
  "subagent_budget_limit": 5,
  "metrics_enabled": true
}

// .claude/context-map.json
{
  "project:root": "~/02luka",
  "cursor:commands": "~/02luka/.cursor/commands"  ← Bridge between them
}
```

**Cursor-specific (`.cursor/`):**
```
.cursor/
├── commands/
│   ├── feature-dev.md    (/feature-dev - plan-first development)
│   ├── code-review.md    (/code-review - multi-agent review)
│   └── deploy.md         (/deploy - checklist deployment)
└── templates/
    └── deployment.md     (Deployment checklist template)
```

## Usage After Restart

1. **Restart Cursor** to pick up new commands
2. **Type `/` in chat** to see available commands:
   - `/feature-dev` - Plan and spec a feature
   - `/code-review` - Multi-agent code review
   - `/deploy` - Checklist-driven deployment
3. **Reference guide:** `docs/claude_code/SLASH_COMMANDS_GUIDE.md` (617 lines, bilingual)

## Future: Standalone CLI

When using standalone Claude Code CLI (not Cursor):
- ✅ `.claude/settings.json` - Works
- ✅ `.claude/context-map.json` - Works
- ❌ `.cursor/commands/` - CLI doesn't read this
- 💡 CLI would use: `.claude/commands/` (different from Cursor)

This is why separation matters - different implementations, different locations.

## Key Insight

**Question:** "Why can't we add this feature both?"
**Answer:** **We did!** Both directories exist and work together:
- `.claude/` = Universal config (works everywhere)
- `.cursor/` = Cursor features (works in Cursor)

The fix wasn't "move files" - it was **"put files where each tool expects them"**.

## Related Documentation

- **Usage Guide:** `docs/claude_code/SLASH_COMMANDS_GUIDE.md` (when/how to use commands)
- **Context Engineering:** See `.claude/context-map.json` for namespace system
- **Metrics:** Run `tools/claude_tools/metrics_collector.zsh` for usage stats
- **Hooks:** See `tools/claude_hooks/` for quality gates

---
**Deployed:** WO-CLAUDE-PHASE1.5-FIXED.zsh (2025-11-12)
**MLS:** mls/ledger/2025-11-12.jsonl (solution captured)
