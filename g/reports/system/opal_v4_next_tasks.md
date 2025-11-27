# Opal V4 Next Steps (Detailed)

## 1. Opal UI: Health JSON Dashboard
**Status:** ✳️ Pending (UI stage)
**Goal:**
- Frontend (Vite/Next) must fetch `g/telemetry/health_check_latest.json`.
- Parse JSON and render as Dashboard card in `/v4-pipeline`.
- Status indicators: Green/Yellow/Red based on overall status.
- Auto-refresh every 3-5 seconds.
**Note:** No backend required; use static file read via Opal API proxy route `/api/telemetry/health`.

## 2. Opal → GG/Chat Lane Integration
**Status:** ✳️ Pending (Pipeline)
**Goal:** Connect GG lane fully.
- `/api/chat` POST -> publish to `gg:chat:incoming`.
- GG response -> publish to `gg:chat:response:<task_id>`.
- UI displays real-time results (console-style or bubble).
- Support for Kim Agent in future.
**MVP:** GG echoes response ("received: xxx").
**Phase 3:** GG process -> CLC -> Mary fallback -> return JSON reply.

## 3. LaunchAgent for Health v2
**Status:** ✳️ Pending (Ops)
**Goal:**
- Create LaunchAgent: `com.02luka.opal-healthv2`.
- Run `g/tools/opal_health_check_v2.zsh` every X minutes (recommended: 2 mins).
- Append to `g/telemetry/health_check.log`.
- Maintain rolling snapshots (optional).
- Result: Silent background health timeline.
**Enhancement:** Auto-restart agent on critical failure; alert via Kim (Slack/Telegram).

## Summary Stack
```yaml
opal_v4_next_tasks:
  - id: OPAL-UI-HEALTH-DASH
    title: "Bind Opal UI to health_check_latest.json"
    status: pending
    desc: "Render health JSON on /v4-pipeline as dashboard cards"

  - id: OPAL-GG-LANE-CONNECT
    title: "Integrate Opal → GG/Chat lane"
    status: pending
    desc: "Chat POST → Redis → GG → response → UI display"

  - id: OPAL-HEALTHV2-AGENT
    title: "Create LaunchAgent to run health v2"
    status: pending
    desc: "Run health_check_v2 every X minutes and log timeline"
```
