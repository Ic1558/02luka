# 02LUKA Vector Memory Context

This file provides access to the 02LUKA vector memory system for AI assistants in Cursor/Codex.

## How to Use This in Cursor

**Option 1: Direct File Reference**
When working in Cursor, you can reference memory by:
1. Reading `g/memory/vector_index.json` directly
2. Using the API endpoints (see below)

**Option 2: API Access**
```bash
# Recall memories (local)
curl http://127.0.0.1:4000/api/memory/recall?q=your+query

# Recall memories (remote - if deployed)
curl https://boss-api.ittipong-c.workers.dev/api/memory/recall?q=your+query

# Get memory stats
curl http://127.0.0.1:4000/api/memory/stats
```

**Option 3: CLI Access**
```bash
# Search for relevant memories
node memory/index.cjs --recall "your query here"

# Search by kind
node memory/index.cjs --recall-kind solution "your query"

# Get statistics
node memory/index.cjs --stats
```

## Memory Structure

The vector memory system stores:
- **Plans**: Successful task executions and workflows
- **Solutions**: Bug fixes and problem resolutions
- **Errors**: Error patterns and their solutions
- **Insights**: Learned patterns and optimizations
- **Config**: Configuration patterns that worked

## Integration with Your Workflow

**Before starting a task:**
1. Query relevant memories: `node memory/index.cjs --recall "task description"`
2. Review similar past solutions
3. Apply learned patterns

**After completing a task:**
1. Record the solution: `node memory/index.cjs --remember solution "what you learned"`
2. System auto-records successful OPS runs and smoke tests

## Example Queries

```bash
# Find Discord-related solutions
node memory/index.cjs --recall "Discord webhook integration"

# Find macOS-specific fixes
node memory/index.cjs --recall-kind solution "macOS compatibility"

# Find deployment patterns
node memory/index.cjs --recall-kind plan "deployment workflow"
```

## Current Memory Stats

Check live stats:
```bash
node memory/index.cjs --stats
```

This will show:
- Total memories stored
- Breakdown by kind
- Vocabulary size
- Index file location

## For AI Assistants in Cursor

When assisting with tasks in this repository:

1. **Check Memory First**: Before proposing solutions, query the memory system for similar past experiences
2. **Learn from History**: Use `recall()` to find relevant solutions from past work
3. **Record Success**: After successful implementations, suggest recording them with `remember()`
4. **Avoid Repetition**: Check if a problem has been solved before to avoid duplicate effort

## API Reference

See `docs/CONTEXT_ENGINEERING.md` section "Vector Memory System" for complete API documentation.

---

**Last Updated**: 2025-10-20
**Memory Index**: `g/memory/vector_index.json`
**Module**: `memory/index.cjs`
