# Assistant Platform Architecture Overview

```
+--------------------+        +-----------------------+        +---------------------+
|  Assistant UI      | <----> |  Assistant API Layer  | <----> |  Integration Adapters|
|  (apps/assistant-ui)|        |  (apps/assistant-api) |        |  (connectors/queue)  |
+----------+---------+        +-----------+-----------+        +----------+----------+
           |                              |                               |
           v                              v                               v
   +-------+-------+           +----------+----------+          +---------+---------+
   | Feedback Loop |           | Context Orchestration|          | External Services |
   |  (UI/Reports) |           | (packages/context)   |          | (Drive/Slack/etc.)|
   +-------+-------+           +----------+----------+          +---------+---------+
           |                              |                               |
           v                              v                               v
   +-------+-------+           +----------+----------+          +---------+---------+
   | Memory Services| <------> |  Retrieval Adapter  | <------> |  Data Stores       |
   | (packages/memory)|        |  (RAG pipeline)     |          |  (g/memory, docs)  |
   +---------------+           +--------------------+          +--------------------+
```

## Module Summary

### apps/assistant-api
- Express-based API exposing health, capability discovery, retrieval-augmented generation (RAG), and memory operations.
- Middleware stack includes structured logging, RBAC-ready auth stub, and in-memory rate limiting.
- Serves static assets for the chat UI and coordinates requests to context and memory packages.

### apps/assistant-ui
- Offline-friendly chat client with transparency panel and human-in-the-loop feedback controls.
- Provides traceable summaries of automated actions and collects user feedback for the improvement loop.
- Built with vanilla HTML/CSS/JS to remain deployable on static hosts.

### packages/context
- Context loader orchestrates adapters for local files, placeholder Drive sync, and CRM/email stubs.
- Relevance filter scores snippets based on semantic heuristics and decaying freshness.
- Token budgeter shapes responses per downstream model budget and escalation tier.

### packages/memory
- Facade over Phase 6.5 memory index supporting importance, recency, and decay aware storage.
- Adds scoring hooks and normalizes metadata for audit-ready persistence.
- Surfaces stats and recall operations for both API and scheduled maintenance jobs.

### docs and governance assets
- Architecture, role definitions, security governance, prompt standards, deployment, and reports ensure operational readiness.

## Data Flows
1. **User Interaction**: UI sends chat requests to `/rag/query` with conversation context and tool preferences.
2. **Context Assembly**: API delegates to `packages/context` which loads relevant snippets, applies filters, and returns prioritized context with token budgeting metadata.
3. **Memory Augmentation**: API optionally persists new insights via `/memory/remember` and surfaces historical context via `/memory/recall`.
4. **Automation Transparency**: UI renders returned `actions` with "what/why" reasoning and stores feedback in local session storage for later sync.
5. **Audit & Governance**: All API interactions emit structured logs for RBAC, audit trails, and improvement loops.

## Connectors & Dependencies
- **Local Files**: File adapter scans repository docs (no external network requirement).
- **Remote Placeholders**: Drive/Slack/CRM connectors expose TODO stubs guarded by RBAC to avoid accidental calls without credentials.
- **Memory Store**: Uses repository `g/memory/vector_index.json` via Phase 6.5 index.
- **Optional Ops Gate**: CI integrates with Ops Atomic when credentials provided.

## Trust Boundaries
- **Public UI**: Runs in browser; only communicates with API over TLS in production.
- **API Layer**: Authenticates requests (stubbed for now) and enforces rate limiting before entering business logic.
- **Context & Memory Services**: Operate on internal data; access governed by service account RBAC scopes.
- **External Integrations**: Gated connectors require human approval and audit logging before invocation.

## Offline & Local Capability
- UI and API run without external network access using local context data and mock RAG responses.
- Memory operations persist locally to repository ensuring reproducibility across environments.
- Scripts and CI paths avoid network reliance except optional Ops Atomic checks.
