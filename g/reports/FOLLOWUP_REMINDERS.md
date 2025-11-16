# Follow-Up & Reminder Tracking

**Classification:** Operational Tracking Document
**Maintained by:** GG Core / CLC
**Purpose:** Track delegated tasks, pending work, and reminder items requiring attention
**Last Updated:** 2025-11-06

## Active Items

| Priority | Tasks | Status | Handler | Date Added | Details |
|----------|-------|--------|---------|------------|---------|
| 1 | Dashboard API + MLS Data | ⚠️ Delegated | Complex, needs local agents | 2025-11-06 | See Priority 1 Details below |

---

## Priority 1 Details

**Status:** ⚠️ DELEGATED TO LOCAL AGENTS
**Complexity:** High - requires iterative debugging and local system access
**Related Report:** `~/02luka/g/reports/SYSTEM_STATUS_LIVE_VS_STALE_20251106.md`

### Task Breakdown

#### 1. Fix Dashboard API Port Conflict
**Issue:** Port 8770 persistently occupied (PID conflicts)
**Impact:** Dashboard showing stale/cached data instead of live metrics
**Actions Required:**
- Kill all processes on port 8770
- Restart dashboard API cleanly: `cd ~/02luka/g/apps/dashboard && python3 api_server.py`
- Verify API endpoints responding:
  - http://127.0.0.1:8770/api/wos
  - http://127.0.0.1:8770/api/services
  - http://127.0.0.1:8770/api/mls
- Estimated: 10-15 minutes

#### 2. Fix MLS JSONL Format
**Issue:** `mls_lessons.jsonl` contains multi-line pretty-printed JSON instead of proper JSONL
**Impact:** RAG federation cannot import MLS knowledge (0 inserted, 34 skipped)
**Actions Required:**
- Manual inspection of file structure at `~/02luka/g/knowledge/mls_lessons.jsonl`
- Convert to proper JSONL (one JSON object per line)
- Validate each line is parseable: `jq -c . mls_lessons.jsonl > mls_lessons.jsonl.fixed`
- Replace original file
- Estimated: 10-15 minutes

#### 3. Re-run RAG Federation
**Dependency:** Blocked on Task 2 (MLS format fix)
**Actions Required:**
- Execute: `~/02luka/tools/rag_index_federation.zsh`
- Verify MLS entries inserted: `sqlite3 ~/02luka/g/rag/store/fts.db "SELECT COUNT(*) FROM docs WHERE path LIKE 'mls://%'"`
- Expected result: 34+ entries (all MLS lessons imported)
- Estimated: 5 minutes

### Why Delegated to Local Agents

**CLC Limitations:**
- Cannot interactively debug port conflicts
- Cannot manually inspect/edit multi-line JSON structure
- Limited visibility into process management
- Each attempt costs tokens without guaranteed progress

**Local Agent Advantages:**
- Direct system access for process management
- Can inspect files visually
- Iterative debugging capability
- Zero token cost for exploration

### Success Criteria

- [ ] Dashboard API running on port 8770
- [ ] Dashboard showing live data (matches actual system state)
- [ ] MLS JSONL file validates as proper JSONL
- [ ] RAG database contains 34+ MLS entries
- [ ] Test query returns MLS results: `curl -X POST http://127.0.0.1:8765/rag_query -H "Content-Type: application/json" -d '{"query": "delegation", "top_k": 5}'`

---

## Completed Items

| Priority | Tasks | Status | Handler | Completed Date | Details |
|----------|-------|--------|---------|----------------|---------|
| 2 | Expense OCR Integration | ✅ Complete | CLC | 2025-11-06 | Report: `WO-251106-EXPENSE-OCR-COMPLETE.md` |
| - | Phase 14.1 RAG Federation | ✅ Complete | CLC | 2025-11-06 | Pushed to GitHub (commit 9554030) |

---

## Notes

- **Priority 1 blocking items:** RAG federation cannot complete until MLS format fixed
- **System health:** 85% operational (core infrastructure working)
- **Next phase:** Phase 14.2 (Unified SOT Telemetry Schema) ready to start once Priority 1 resolved

---

**Quick Check Commands:**

```bash
# Check dashboard API status
lsof -ti:8770

# Validate MLS JSONL format
head -1 ~/02luka/g/knowledge/mls_lessons.jsonl | jq . >/dev/null && echo "Valid JSON" || echo "Invalid"

# Check RAG federation status
sqlite3 ~/02luka/g/rag/store/fts.db "SELECT COUNT(*) as total, COUNT(CASE WHEN path LIKE 'mls://%' THEN 1 END) as mls_entries FROM docs"
```
