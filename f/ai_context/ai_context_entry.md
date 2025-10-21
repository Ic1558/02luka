# AI Context Entry
> **Generated:** 2025-10-22T03:02:00Z

## Quick Navigation
- Human Inbox → `human:inbox`
- Work Orders → `boss/work-orders/` (if present)
- Knowledge Search → `node knowledge/index.cjs --hybrid "query"`
- System Docs → `02luka.md` (Phase 7.6+ section)
- Codex Template System → `prompts/master_prompt.md`

## Knowledge System (NEW - Phase 7.6+)

**Hybrid Vector Database** - 100% documentation coverage with semantic search

### Quick Commands
```bash
# Semantic search (finds related concepts)
node knowledge/index.cjs --hybrid "token efficiency"
node knowledge/index.cjs --hybrid "phase 7 delegation"
node knowledge/index.cjs --hybrid "how to optimize performance"

# With timing breakdown
node knowledge/index.cjs --verify "query"

# Keyword search (exact matches)
node knowledge/index.cjs --search "keyword"
```

### Coverage
- ✅ **4,002 chunks** from 258 documents
- ✅ **100% of docs/** indexed (41/41 files)
- ✅ **100% of g/reports/** indexed (185+/185 files)
- ✅ **Zero "waste paper"** - all documentation searchable

### Performance
- **7-8ms** average query time (🚀 12x better than target)
- **Semantic understanding** - finds "token savings" when you search "cost reduction"
- **Special characters** - "phase 7.2", "v2.0", "boss-api" all work

### When to Use
- Finding documentation on any topic
- Discovering related concepts
- Understanding system architecture
- Learning from past implementations

**Docs:** `knowledge/README.md`, `g/reports/RAG_QUICK_REFERENCE.md`

## Today's Focus
1. **Use knowledge search** before asking questions - answers may already exist
2. Confirm `prompts/master_prompt.md` is the starting point for Codex tasks (`GOAL:` first, fill remainder before execution)
3. Ensure `luka.html` prompt library can load the master template via local HTTP server (serve repo root before use)
4. Promote `g/tools/install_master_prompt.sh` as the supported installation/refresh path; avoid manual edits in other directories

## Status Signals
- `f/ai_context/mapping.json` at v2.1 exposes `codex:*` routes
- Hidden tier list now includes `.codex` to keep template internals out of routine scans
- ✅ **Phase 7.6+ Complete** - Hybrid vector database operational (2025-10-22)

## Reminders
- **Search before asking:** Use `--hybrid` for questions about the system
- Run `verify_system.sh` before deployments to surface missing gateways or template drift
- Record any new prompt variants under `prompts/` so they enter the discovery pipeline
- Reindex knowledge after adding new docs: `node knowledge/index.cjs --reindex`

