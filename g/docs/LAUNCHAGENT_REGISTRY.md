# LaunchAgent Registry

This registry tracks LaunchAgents used inside the `~/02luka` workspace.

| Name | Label | Script | Critical | Role |
| --- | --- | --- | --- | --- |
| **MCP Bridge** | com.02luka.gg.mcp-bridge | `g/tools/gg_mcp_bridge.zsh` | YES | Master Control Program bridge. Routes incoming tasks from external sources to GG. |
| **Mary Dispatcher** | com.02luka.mary.dispatcher | `g/tools/mary_dispatcher.zsh` | YES | Routes internal work orders to the correct agent (CLC, Gemini, etc.) based on protocol. |
| **WO Pipeline: LPE Worker** | com.02luka.lpe.worker | `g/tools/lpe_worker.zsh` | YES | Local Patch Engine worker. Applies patches from LPE work orders. |
| **WO Pipeline: JSON WO** | com.02luka.json_wo_processor | `g/tools/wo_pipeline/json_wo_processor.zsh` | YES | Parses WO files and enriches state with normalized metadata. |
| **WO Pipeline: Executor** | com.02luka.wo_executor | `g/tools/wo_pipeline/wo_executor.zsh` | YES | Runs or routes work orders, updating their status. |
| **WO Pipeline: Tracker** | com.02luka.followup_tracker | `g/tools/wo_pipeline/followup_tracker.zsh` | YES | Computes derived metadata like age and staleness for WOs. |
| **WO Pipeline: Guardrail** | com.02luka.wo_pipeline_guardrail | `g/tools/wo_pipeline/wo_pipeline_guardrail.zsh` | YES | Validates the end-to-end health of the WO pipeline. |
| **MLS Cursor Watcher** | com.02luka.mls.cursor.watcher | `tools/mls_cursor_watcher.zsh` | YES | Monitors Cursor IDE for prompts and records them to MLS. |
| **Hub Auto-Index** | com.02luka.hub-autoindex | `tools/hub_index_now.zsh` | NO | Periodically runs the hub auto-index and memory sync. |
| **Phase15 Health Check** | com.02luka.phase15.quickhealth | `tools/phase15_quick_health.zsh` | NO | Runs a quick health check for Phase 15 components. |
