<file name=CLC_GMX_ORCHESTRATOR_SPEC_v1.md path=/Users/icmini/LocalProjects/02luka_local_g/g/docs>## 6. Implementation Status (v1.1 – Sensing Mode)

The GMX CLC Orchestrator is now running in **"sensing" mode** rather than a pure non-functional skeleton.

**Current capabilities (v1.1):**
- The LaunchAgent `com.02luka.gmx-clc-orchestrator` is installed under `~/Library/LaunchAgents/` and runs the orchestrator script on a fixed interval.
- The orchestrator script `g/tools/gmx_clc_orchestrator.zsh`:
  - Normalizes its working directory to the project root (`/Users/icmini/02luka`).
  - Reads current system/OPS context, including:
    - OPAL Health JSON: `g/telemetry/health_check_latest.json` (if present)
    - CLC/LIAM ACK directory metadata: `bridge/outbox/LIAM` (count, latest files)
    - Session state directory presence: `state/clc_sessions`
  - Builds a **structured context JSON** on disk (under `tmp/`) as input to GMX.
  - Calls the **GMX (Gemini CLI) profile** dedicated to the orchestrator (e.g. `clc-orchestrator`) and captures its response as a "plan".
  - Parses the GMX response and logs a summary line showing `GMX_Call_Status`, `WOs_Created`, and `WO_IDs`.
- The orchestrator currently runs in **read-only / no-side-effect mode**:
  - It does **not** create any new Work Orders in `bridge/inbox/CLC/`.
  - It only logs what it observes and what GMX suggests (if anything), so the rest of the system remains stable.

**Key limitations of v1.1:**
- **No WO generation yet:**
  - The code path that would transform a GMX plan into one or more `WO-*.yaml` files for CLC is intentionally disabled.
  - This prevents accidental writes to the bridge inbox while GMX prompts and safety policies are still being refined.
- **Session / ACK enrichment still WIP:**
  - ACK summarization and detailed session-state snapshots are intentionally minimized; future versions will safely enrich the context with recent changes and CLC activity.
- **Error handling for external tools is minimal:**
  - If GMX or dependencies such as `jq`/`yq` are missing, the orchestrator currently treats this as a sensing failure and logs the error, but does not attempt automatic repair.

The primary purpose of v1.1 is to have a **live, low-risk sensing loop**: GMX is wired in, context is built, and logs show how the system would behave, without yet allowing the orchestrator to mutate CLC state.

## 7. Verification Plan (v1.1 – Sensing Mode)

This plan verifies the health of the **sensing-mode** orchestrator without requiring it to create any Work Orders.

### Manual Verification Steps

1. **Ensure LaunchAgent is installed and loaded**

   ```bash
   cp LaunchAgents/com.02luka.gmx-clc-orchestrator.plist ~/Library/LaunchAgents/
   launchctl unload ~/Library/LaunchAgents/com.02luka.gmx-clc-orchestrator.plist 2>/dev/null || true
   launchctl load ~/Library/LaunchAgents/com.02luka.gmx-clc-orchestrator.plist
   ```

   - **Expected:** `launchctl list | grep gmx-clc-orchestrator` returns a line with a non-`-` PID and `LastExitStatus = 0`.

2. **Trigger the orchestrator manually**

   ```bash
   cd /Users/icmini/02luka
   zsh g/tools/gmx_clc_orchestrator.zsh
   ```

   - **Expected:** The command exits with code `0` and does not print error stack traces.

3. **Inspect the orchestrator log**

   ```bash
   tail -n 20 logs/gmx_clc_orchestrator.log
   ```

   - **Expected log patterns:**
     - `--- Orchestrator loop started ---`
     - `INFO: Gathering context...`
     - `INFO: Skipping ACK summary (WIP).` (or equivalent WIP messages)
     - `INFO: Plan is empty. No new Work Orders to create. System is idle.` (or a summary of a non-empty GMX plan)
     - `SUMMARY: Timestamp=..., GMX_Call_Status=OK, WOs_Created=0, WO_IDs=[]`

4. **Confirm that no Work Orders are created**

   ```bash
   ls -la bridge/inbox/CLC
   ```

   - **Expected:** Only static files such as `.DS_Store` and `templates/` exist. No new `WO-*.yaml` files should appear as a result of the orchestrator run.

5. **Validate behavior when GMX or dependencies are unavailable (optional)**

   - Temporarily move `gmx` out of `PATH` or run with a profile that is not configured.
   - Re-run the orchestrator:

     ```bash
     cd /Users/icmini/02luka
     zsh g/tools/gmx_clc_orchestrator.zsh
     tail -n 20 logs/gmx_clc_orchestrator.log
     ```

   - **Expected:** The script logs an error about the missing tool / failed GMX call, sets `GMX_Call_Status` accordingly in the summary, and still exits cleanly without creating any Work Orders.

This verification plan ensures that v1.1 provides a **stable sensing loop** with well-understood logs and no unintended writes to CLC or bridge state.
