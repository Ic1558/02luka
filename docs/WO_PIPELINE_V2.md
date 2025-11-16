# WO Pipeline v2

The WO (Work Order) pipeline converts raw WO files dropped into `bridge/inbox/CLC/` into normalized state JSON under `followup/state/`. Those state files feed `tools/claude_tools/generate_followup_data.zsh`, which refreshes `apps/dashboard/data/followup.json` for the Follow-Up dashboard.

## Flow Overview

```
bridge/inbox/CLC/*.yaml|*.json
    │
    ├─ apply_patch_processor.zsh   # discovers files, seeds state JSON
    ├─ json_wo_processor.zsh       # parses YAML/JSON → normalized metadata
    ├─ wo_executor.zsh             # runs / routes orders, updates status
    ├─ followup_tracker.zsh        # computes derived metadata (age, stale)
    └─ generate_followup_data.zsh  # aggregates followup/state/*.json → dashboard
```

Each script is idempotent and safe to run manually. The guardrail script validates the end-to-end health and is wired into LaunchAgents for unattended mode.

## State JSON Schema

State files live under `followup/state/<WO-ID>.json` and conform to the schema below (fields omitted by WO data default to empty values):

| Field | Type | Description |
| --- | --- | --- |
| `id` | string | Normalized WO identifier |
| `title` / `summary` | string | Human-readable description |
| `description` | string | Long-form context from WO body |
| `owner` | string | Primary executor / assignee |
| `category` | string | Derived from WO fields such as `category`, `intent`, `phase` |
| `priority` | string | `High`, `Medium`, or `Low` |
| `status` | string | Pipeline status (`pending`, `running`, `done`, `failed`) |
| `created_at` / `updated_at` | ISO-8601 UTC | Timestamps managed by the pipeline |
| `due_date` | string | ISO-8601 date if supplied |
| `goal` | string | Aggregated objectives text |
| `progress` | integer | 0–100, set to 100 when executor succeeds |
| `notes` | string | Latest executor/tracker note |
| `last_error` | string | Populated when executor/guardrail detects issues |
| `tags` | array | Free-form tags (includes `Stale` when tracker marks items) |
| `source` | string | Always `work_order` for this pipeline |
| `meta` | object | Internal bookkeeping (inbox path, executor, age, etc.) |

`generate_followup_data.zsh` expects the above keys, so adjust `lib_wo_common.zsh::write_state_json()` if the dashboard schema evolves.

## Manual Operation

```
cd ~/02luka/g
./tools/wo_pipeline/apply_patch_processor.zsh
./tools/wo_pipeline/json_wo_processor.zsh
./tools/wo_pipeline/wo_executor.zsh
./tools/wo_pipeline/followup_tracker.zsh
~/02luka/tools/claude_tools/generate_followup_data.zsh
```

After the final step, `apps/dashboard/data/followup.json` contains the merged WO + agent task view that powers `apps/dashboard/followup.html`.

## End-to-End Test

```
cd ~/02luka/g
./tools/wo_pipeline/test_wo_pipeline_e2e.zsh
```

The test drops a synthetic WO into the inbox, runs the processors, executes it, and verifies the resulting state hits `status=done` and `progress=100`. Set `KEEP_TEST_STATE=1` to keep artifacts for debugging.

## LaunchAgent Installation

1. Create the log directory once: `mkdir -p ~/02luka/logs/wo_pipeline`.
2. Copy each plist in `g/launchd/` to `~/Library/LaunchAgents/`.
3. Load the agents:
   ```
   launchctl load ~/Library/LaunchAgents/com.02luka.apply_patch_processor.plist
   launchctl load ~/Library/LaunchAgents/com.02luka.json_wo_processor.plist
   launchctl load ~/Library/LaunchAgents/com.02luka.wo_executor.plist
   launchctl load ~/Library/LaunchAgents/com.02luka.followup_tracker.plist
   launchctl load ~/Library/LaunchAgents/com.02luka.wo_pipeline_guardrail.plist
   ```
4. Tail logs under `~/02luka/logs/wo_pipeline/` to confirm activity.

Unload/reload the `guardrail` plist after making script changes so health checks pick up the latest version.

## Troubleshooting

- **State files not created** → Run `apply_patch_processor` with `set -x` and confirm `bridge/inbox/CLC/` exists (guardrail will flag missing dirs).
- **json_wo_processor fails** → Ensure PyYAML is installed (`pip install PyYAML`) and that WO files are valid YAML/JSON.
- **Dashboard empty** → After producing state files, run `tools/claude_tools/generate_followup_data.zsh`; verify `apps/dashboard/data/followup.json` has non-empty `items`.
- **Guardrail errors** → Execute `tools/wo_pipeline/wo_pipeline_guardrail.zsh` manually to see which prerequisites are missing.
- **LaunchAgent noise** → Check `.err.log` for each agent. Agents are safe to re-run manually; they do not delete inbox files.
