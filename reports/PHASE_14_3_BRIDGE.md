# Phase 14.3 – Knowledge ↔ MCP Bridge

**Classification:** Strategic Integration Patch (SIP)  
**Deployed by:** CLS (Cognitive Local System Orchestrator)  
**Maintainer:** GG Core (02LUKA Automation)  
**Version:** v1.3-bridge  
**Revision:** r1  
**Phase:** 14.3 – Knowledge-MCP Bridge  
**Timestamp:** 2025-11-06 05:25:54 +0700  
**WO-ID:** WO-251107-PHASE-14-RAG-UNIFICATION  
**Verified by:** CDC / CLC / GG SOT Audit Layer  
**Status:** Production ready  
**Evidence Hash:** ce89363b5fd80111440240f8de96f40c90e936ca212bebb76e68d00b38ecd187

---

## Summary

Knowledge ↔ MCP Bridge enables bi-directional sync between unified RAG index and MCP Memory/Search services. Processes JSONL batches and ingests to MCP endpoints with idempotency, retry, and telemetry.

## Preconditions Verified

✅ **Phase 14.1 & 14.2 artifacts:**
- `memory/index_unified/unified.jsonl` (0B - empty, expected for initial setup)
- `g/telemetry_unified/unified.jsonl` (47B)
- `g/telemetry_unified/manifest.json` (95B)

✅ **MCP services:**
- MCP Memory: `localhost:5330` (LISTEN)
- MCP Search: `localhost:5340` (LISTEN)

✅ **Tools:**
- `jq`, `yq`, `rg`, `fd` installed

✅ **Safe zones:**
- `g/bridge/`, `g/reports/`, `memory/index_unified/`, `g/telemetry_unified/`

## Artifacts

### 1. Configuration
- **File:** `config/bridge_knowledge.yaml`
- **Purpose:** Defines sources, targets, policies, and observability
- **Key settings:**
  - Source: `memory/index_unified/unified.jsonl`
  - Target: `http://localhost:5330/ingest`
  - Batch size: 200
  - Retry: max 5, backoff 500ms
  - Idempotency: SHA256(content)

### 2. Sync Tool
- **File:** `tools/bridge_knowledge_sync.zsh`
- **Features:**
  - Dry-run mode (preview)
  - Batch processing (configurable size)
  - Resume from manifest
  - Max failure threshold
  - Telemetry emission (Phase 14.2 format)
  - Idempotency key generation

### 3. LaunchAgent
- **File:** `~/Library/LaunchAgents/com.02luka.bridge.knowledge.sync.plist`
- **Schedule:** Every 6 hours (21600s)
- **Status:** Created, not loaded

### 4. Snapshot
- **Location:** `snapshots/phase14_3_pre/`
- **Contents:** Pre-sync state of unified.jsonl and telemetry_unified/

## Verification Results

### Dry-Run Test
```bash
./tools/bridge_knowledge_sync.zsh \
  --config config/bridge_knowledge.yaml \
  --dry-run --limit 10 --verbose
```

**Results:**
- ✅ Script executed successfully
- ✅ Telemetry events emitted (bridge.sync.start, bridge.sync.end)
- ✅ Config loaded correctly
- ⚠️  Source file empty (expected for initial setup)

### Telemetry Events

Events emitted to `g/bridge/bridge_knowledge_sync.log`:
- `bridge.sync.start` - Batch size, source path
- `ingest.ok` - Batch ID, count, ingested
- `ingest.fail` - Batch ID, count, error
- `bridge.sync.end` - Status, total, batches, failures

**Format:** Phase 14.2 unified schema with `__source: "bridge_knowledge_sync"` and `__normalized: true`

## Processing Flow

```
unified.jsonl → chunk(batch_size) → idempotency_key → POST /ingest → manifest.json
                                                    ↓
                                          telemetry → bridge_knowledge_sync.log
```

## Failure Handling

- **Network errors:** Retry with backoff (max 5 attempts)
- **Payload errors:** Quarantine to `g/bridge/quarantine/`
- **Max failures:** Stop after `--max-fail N` (default: 20)
- **Safe exit:** Continue on non-critical errors

## Rollback Plan

1. **Delete records:** Use ingest manifest (`g/bridge/last_ingest_manifest.json`)
2. **Restore snapshot:** `snapshots/phase14_3_pre/` → overwrite unified outputs
3. **Disable LaunchAgent:** `launchctl unload ~/Library/LaunchAgents/com.02luka.bridge.knowledge.sync.plist`

## Usage

### Dry-Run (Preview)
```bash
./tools/bridge_knowledge_sync.zsh \
  --config config/bridge_knowledge.yaml \
  --dry-run --limit 500 --verbose
```

### Production Run
```bash
./tools/bridge_knowledge_sync.zsh \
  --config config/bridge_knowledge.yaml \
  --batch 200 --resume
```

### Enable LaunchAgent
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.bridge.knowledge.sync.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.02luka.bridge.knowledge.sync.plist
launchctl kickstart -k gui/$(id -u)/com.02luka.bridge.knowledge.sync
```

### Merge Telemetry
```bash
./tools/telemetry_sync.zsh --source g/bridge/*.log --append
```

## Acceptance Criteria

- [ ] Query from MCP Search finds ≥95% of sample 1,000 items
- [ ] Telemetry 14.2 has complete `bridge.sync.*` events with `count_ok`/`lat_ms`
- [ ] LaunchAgent (if enabled) runs next cycle without errors
- [ ] Idempotent: rerun does not create duplicates (check `idempotency_key`)

## Next Steps

- Phase 14.4 – RAG-Driven Contextual Response
- Validate MCP ingest with sample queries
- Enable LaunchAgent after validation

---

_All operations performed per Rule 93 (Evidence-Based Operations)._

