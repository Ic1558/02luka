# LaunchAgent Registry (02LUKA)

**Version:** 1.0.1

**Last-Updated:** 2025-11-17

**Status:** Active Registry

**Auto-generated:** No (manual)

This registry tracks LaunchAgents used inside the `~/02luka` workspace.

> **Source of truth**
>
> - This table is intended to be **auto-generated** by `g/tools/launchagent_audit.zsh` (Markdown mode).
>
> - Manual editsควรจำกัดเฉพาะส่วน *Notes / Planned* เท่านั้น
>
> - ถ้ามีความต่างระหว่างไฟล์นี้กับผลรัน `launchagent_audit.zsh` ให้ถือผลจากสคริปต์เป็น SOT ก่อน แล้วค่อย sync กลับมาแก้ไฟล์นี้

---

## 1. Active LaunchAgents

| Name                         | Label                             | Script                                      | Critical | Role                                                                 | Notes |
|------------------------------|------------------------------------|---------------------------------------------|----------|----------------------------------------------------------------------|-------|
| **MCP Bridge**               | `com.02luka.gg.mcp-bridge`        | `g/tools/gg_mcp_bridge.zsh`                 | YES      | Master Control Program bridge. Routes incoming tasks from external sources to GG. | |
| **Mary Dispatcher**          | `com.02luka.mary.dispatcher`      | `g/tools/mary_dispatcher.zsh`               | YES      | Routes internal work orders to the correct agent (CLC, Gemini, etc.) based on protocol. | |
| **WO Pipeline: LPE Worker**  | `com.02luka.lpe.worker`           | `g/tools/lpe_worker.zsh`                    | YES      | Local Patch Engine worker. Applies patches from LPE work orders.    | ⚠️ Missing locked-zone validation — requires safety guard in next PR |
| **WO Pipeline: JSON WO**     | `com.02luka.json_wo_processor`    | `g/tools/wo_pipeline/json_wo_processor.zsh` | YES      | Parses WO files and enriches state with normalized metadata.        | |
| **WO Pipeline: Executor**    | `com.02luka.wo_executor`          | `g/tools/wo_pipeline/wo_executor.zsh`       | YES      | Runs or routes work orders, updating their status.                  | |
| **WO Pipeline: Tracker**     | `com.02luka.followup_tracker`     | `g/tools/wo_pipeline/followup_tracker.zsh`  | YES      | Computes derived metadata like age and staleness for WOs.           | |
| **WO Pipeline: Guardrail**   | `com.02luka.wo_pipeline_guardrail`| `g/tools/wo_pipeline/wo_pipeline_guardrail.zsh` | YES  | Validates the end-to-end health of the WO pipeline.                 | |
| **MLS Cursor Watcher**       | `com.02luka.mls.cursor.watcher`   | `tools/mls_cursor_watcher.zsh`              | YES      | Monitors Cursor IDE for prompts and records them to MLS.            | |
| **Hub Auto-Index**           | `com.02luka.hub-autoindex`        | `tools/hub_index_now.zsh`                   | NO       | Periodically runs the hub auto-index and memory sync.               | |
| **Phase15 Health Check**     | `com.02luka.phase15.quickhealth`  | `tools/phase15_quick_health.zsh`            | NO       | Runs a quick health check for Phase 15 components.                  | |

---

## 2. Planned / Watchdog LaunchAgents

> หมายเหตุ: บล็อกนี้เป็น **design / reserved labels**
>
> ถ้ายังไม่มี plist จริงใน `~/Library/LaunchAgents` ให้ถือว่าอยู่ในสถานะ PLANNED

| Name                       | Planned Label                          | Planned Script / Source                      | Status   | Notes                                                          |
|----------------------------|----------------------------------------|----------------------------------------------|----------|----------------------------------------------------------------|
| **Gemini Bridge Worker**   | `com.02luka.gemini.bridge`            | `g/tools/gemini_bridge_worker.zsh`           | PLANNED  | Runs Gemini work-order handler and keeps Gemini bridge alive.  |
| **LaunchAgent Watchdog**   | `com.02luka.launchagent.watchdog`     | `g/tools/launchagent_watchdog.zsh`           | PLANNED  | Periodically checks all critical LaunchAgents and restarts or alerts via Mary/Telegram. |
| **Delegation Watchdog**    | `com.02luka.delegation.watchdog`      | `g/tools/delegation_watchdog.zsh`           | PLANNED  | Monitors delegation queue health (WO-20251101-TEST-STUCK stays untouched; watchdog focuses on status only). |

---

## 3. Generation & Checks

- **Generator (target):**
  - `g/tools/launchagent_audit.zsh --mode registry-md`
  - สคริปต์จะ:
    - scan `~/Library/LaunchAgents/com.02luka.*.plist`
    - map → script path / critical flag / role
    - generate Markdown table (section 1) อัตโนมัติ

- **Manual fields:**
  - Section 2 (Planned / Watchdog) สามารถแก้มือได้
  - ถ้า agent ใดสร้างจริงแล้ว:
    - ย้ายจาก Section 2 → Section 1
    - update Critical / Role ให้ตรงกับของจริง

---

End of Registry
