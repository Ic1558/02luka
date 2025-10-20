# Phase 7.5: Local Knowledge Consolidation

**Status:** Day 1 - IN PROGRESS (better-sqlite3 installation BLOCKED)
**Date:** 2025-10-20
**Dependencies:** Phase 6 + 6.5-A + 6.5-B + 7.1

---

## Overview

Offline-first SQLite knowledge base for unified access to:
- Vector memories (`g/memory/vector_index.json`)
- Telemetry logs (`g/telemetry/*.log`)
- Generated reports (`g/reports/*.md`)
- Agent memories (GG, CLC, Codex, etc.)
- Self-review insights

**Key Features:**
- Full-text search with FTS5
- TF-IDF semantic recall
- Incremental sync (watermarks)
- Hash-based deduplication
- Fail-safe auto-hooks
- Date-based exports for Git

---

## Installation Status

### ⚠️  BLOCKER: better-sqlite3 Installation Issue

**Problem:** Node.js native module compilation fails on macOS 15 (Sequoia) due to node-gyp Xcode detection bug.

**Error:**
```
AttributeError: 'NoneType' object has no attribute 'groupdict'
gyp ERR! configure error
```

**Root Cause:** node-gyp cannot parse Xcode Command Line Tools version on macOS 15.

### Solutions

**Option 1: Install Full Xcode (RECOMMENDED)**
```bash
# Install Xcode from App Store (~15GB)
# Then:
sudo xcode-select --switch /Applications/Xcode.app
cd knowledge
npm install better-sqlite3
```

**Option 2: Reinstall Command Line Tools**
```bash
sudo rm -rf /Library/Developer/CommandLineTools
xcode-select --install
# Wait for installation
cd knowledge && npm install better-sqlite3
```

**Option 3: Use Helper Script**
```bash
bash scripts/fix_xcode_for_node_gyp.sh
```

**Option 4: Wait for Fix**
- Track issue: https://github.com/nodejs/node-gyp/issues
- node-gyp team is working on macOS 15 compatibility

---

## Files Created (Day 1)

- ✅ `schema.sql` - Database schema with all tables, indices, FTS5, triggers
- ✅ `package.json` - Package configuration with better-sqlite3 dependency
- ✅ `init.cjs` - Database initialization script (ready to use once better-sqlite3 is installed)
- ⏳ `node_modules/` - BLOCKED on better-sqlite3 installation

---

## Database Schema

### Tables

1. **memories** - Vector memories from Phase 6
   - Stable UUIDs, TF-IDF vectors, importance scores
   - Tracks queryCount, lastAccess (Phase 6.5-B)
   - Source path + hash for dedupe

2. **telemetry** - NDJSON telemetry logs
   - Hash-based deduplication (ts+task+duration+results)
   - Source lineage for incremental sync

3. **reports** - Generated markdown reports
   - Filename uniqueness (prevents re-import)
   - Full-text searchable via FTS5

4. **agent_memories** - Agent-specific memories
   - GG, CLC, Codex, Mary, Paula, Boss
   - Categories: session, note, plan, etc.

5. **insights** - Cached insights from self-review
   - Confidence scores, actionable flags
   - Optional link to source memory (foreign key)

### FTS5 Virtual Tables

- `memories_fts` - Full-text search on memory text
- `reports_fts` - Full-text search on report content

### Indices

12 indices for performance on:
- kind, agent, importance, queryCount, lastAccess, timestamp
- task, type, confidence, generated dates

### Triggers

6 triggers to keep FTS indices in sync:
- Insert/update/delete on memories → memories_fts
- Insert/update/delete on reports → reports_fts

---

## Usage (Once Installed)

### Initialize Database

```bash
cd knowledge
node init.cjs
```

Output:
```
=== Phase 7.5: Knowledge Database Initialization ===

📄 Reading schema from: schema.sql
🔨 Creating database: 02luka.db
📊 Executing schema...
✅ Schema applied successfully

🔍 Verifying tables...

Tables created:
  ✓ memories             (0 rows)
  ✓ telemetry            (0 rows)
  ✓ reports              (0 rows)
  ✓ agent_memories       (0 rows)
  ✓ insights             (0 rows)

FTS5 virtual tables:
  ✓ memories_fts
  ✓ reports_fts

Indices created: 12
Triggers created: 6

=== Initialization Complete ✅ ===
```

### Force Recreate

```bash
node init.cjs --force
```

---

## Next Steps (Day 1)

1. ✅ Schema design complete
2. ✅ package.json created
3. ✅ init.cjs ready
4. ⏳ **BLOCKER:** Install better-sqlite3
5. ⏳ Test database creation

**Once unblocked:**
- Run `node init.cjs`
- Verify all tables/indices/triggers
- Move to Day 2: Build sync.cjs

---

## Implementation Plan

### Day 1 ✅ (Mostly Complete)
- ✅ Create schema.sql with 6 user deltas
- ✅ Create package.json
- ✅ Create init.cjs
- ⏳ Install better-sqlite3 (BLOCKED)
- ⏳ Test database initialization

### Day 2 (Next)
- Build sync.cjs (incremental sync engine)
- Implement watermarks (.sync_state.json)
- Hash-based dedupe for telemetry
- Filename dedupe for reports
- Source lineage tracking

### Day 3
- Build query interface (search, recall, stats)
- Port TF-IDF similarity from memory/index.cjs
- FTS5 full-text search
- CLI wrappers

### Day 4
- Export functionality (--export flag)
- Date-based export folders
- JSON + Markdown output
- CLI tools

### Day 5
- Auto-sync hooks (fail-safe, non-blocking)
- Documentation (PHASE7_5_KNOWLEDGE_DB.md)
- Integration tests
- Acceptance criteria verification

---

## Architecture Notes

### Source of Record Pattern

**Existing files remain authoritative:**
- `g/memory/vector_index.json` - Memory source of truth
- `g/telemetry/*.log` - Telemetry source of truth
- `g/reports/*.md` - Reports source of truth

**SQLite is a derived/cached view:**
- Sync engine reads files → imports to DB
- Incremental updates based on mtime watermarks
- Never writes back to source files
- DB can be dropped and rebuilt at any time

### Fail-Safe Hooks

Auto-sync hooks are designed to never break existing workflows:
- Silent failure if DB is unavailable
- No blocking operations
- Async/background sync
- Log errors but continue execution

### Deduplication Strategy

**Telemetry:** Hash-based (content hash)
```
source_hash = SHA256(ts + task + duration + pass + warn + fail)
UNIQUE constraint prevents duplicates
```

**Reports:** Filename-based
```
filename UNIQUE constraint
Same filename = same report (idempotent import)
```

**Memories:** Stable UUIDs
```
id from existing vector_index.json
Updates merge with existing entries
```

---

## Related Documentation

- **Phase 7 Overview:** `docs/PHASE7_COGNITIVE_LAYER.md`
- **Memory System:** `docs/CONTEXT_ENGINEERING.md`
- **Telemetry:** `boss-api/telemetry.cjs`
- **Self-Review:** `agents/reflection/self_review.cjs`

---

**Last Updated:** 2025-10-20
**Maintained By:** CLC (Implementation)
**Status:** Day 1 BLOCKED on better-sqlite3 installation
**Next Action:** Install better-sqlite3 per instructions above
