# ATG Snapshot

Timestamp (UTC): 2026-01-02T18:15:45Z
Timestamp (Local): 2026-01-03T01:15:45+0700
Repo: /Users/icmini/02luka
Branch: main
HEAD: 08e06be1a1fc0cec47b091e7d6c2c6cd809efe75

## 1) Git State
```
   M tools/atg_snap.zsh
  ?? magic_bridge/atg_snapshot.json
  ?? magic_bridge/atg_snapshot.json.summary.txt
  ?? magic_bridge/atg_snapshot.md
  ?? magic_bridge/atg_snapshot.md.summary.txt
  ?? magic_bridge/snapshot.md
  ?? magic_bridge/snapshot.md.summary.txt

--- Recent Log ---
  08e06be1 auto-save: 2026-01-03 01:00:23 +0700
  bf71a429 auto-save: 2026-01-03 00:30:23 +0700
  7b9deeb3 session save: CLS 2026-01-03

--- Diff Stat (HEAD~1) ---
   .../pr11_healthcheck/2026-01-03T00:30:44.json      |  16 ++
   gemini_bridge.py                                   |  35 +++-
   infra/launchd/com.02luka.fs_watcher.plist          |   4 +-
   tools/atg_snap.zsh                                 | 209 +++++++++++++++++++++
   tools/fs_watcher.py                                |   5 +
   tools/fs_watcher_launcher.sh                       |   5 +
   6 files changed, 271 insertions(+), 3 deletions(-)
```

## 2) Processes
```
  11067 /opt/homebrew/Cellar/python@3.14/3.14.0_1/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python api_server.py
  51709 /usr/libexec/networkserviceproxy
  62669 /opt/homebrew/Cellar/python@3.14/3.14.0_1/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python /Users/icmini/02luka/tools/fs_watcher.py
  67008 /usr/libexec/containermanagerd --runmode=agent --user-container-mode=current --bundle-container-mode=proxy --system-container-mode=none
  69848 /bin/zsh /Users/icmini/02luka/bridge.sh
  69876 /opt/homebrew/Cellar/python@3.14/3.14.0_1/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python -u gemini_bridge.py
  71535 /Applications/Antigravity.app/Contents/Resources/app/extensions/antigravity/bin/language_server_macos_arm --enable_lsp --extension_server_port 50400 --csrf_token 5d604a9c-3d6d-4235-94f7-f7d771262967 --random_port --workspace_id file_Users_icmini_02luka_02luka_antigravity_code_workspace --cloud_code_endpoint https://daily-cloudcode-pa.googleapis.com --app_data_dir antigravity --parent_pipe_path /var/folders/bm/8smk0tgn55q9zf1bh3l0n9zw0000gn/T/server_712e72b6cc45db6d
  71675 /Applications/Antigravity.app/Contents/Frameworks/Antigravity Helper (Plugin).app/Contents/MacOS/Antigravity Helper (Plugin) /Users/icmini/.antigravity/extensions/github.vscode-github-actions-0.28.2-universal/dist/server-node.js --node-ipc --clientProcessId=71409
  71736 /Users/icmini/.antigravity/extensions/openai.chatgpt-0.4.49/bin/macos-aarch64/codex app-server
  71865 /Users/icmini/.antigravity/extensions/meta.pyrefly-0.46.3-darwin-arm64/bin/pyrefly lsp
  86935 node /opt/homebrew/bin/antigravity-claude-proxy start
```

## 3) Ports
```
  PORT   SERVICE            POLICY     STATUS    PID             COMMAND
  ------------------------------------------------------------------------------------------
  8000   api_server         protected  safe      11067           /opt/homebrew/Cellar/python@3.14/3.14.0_... (+1 workers)
  8001   fastapi-dev        free       safe      -               (free)
  8080   claude_proxy       managed    safe      86935           node /opt/homebrew/bin/antigravity-claude-proxy start
  ------------------------------------------------------------------------------------------
```

## 4) Telemetry (Recent)
### fs_index.jsonl
```json
{"ts": "2026-01-02T17:38:47.959293+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 62669, "git_rev": "bf71a429"}
{"ts": "2026-01-02T17:38:47.960687+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures/.seen_runs", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 62669, "git_rev": "bf71a429"}
{"ts": "2026-01-02T18:00:24.089896+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "tools", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 62669, "git_rev": "bf71a429"}
{"ts": "2026-01-02T18:00:24.090944+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "tools/atg_snap.zsh", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 62669, "git_rev": "bf71a429"}
{"ts": "2026-01-02T18:00:31.481631+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 62669, "git_rev": "bf71a429"}
{"ts": "2026-01-02T18:00:38.850726+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 62669, "git_rev": "bf71a429"}
{"ts": "2026-01-02T18:11:42.946116+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "tools/atg_snap.zsh", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 62669, "git_rev": "bf71a429"}
{"ts": "2026-01-02T18:14:12.478563+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 62669, "git_rev": "bf71a429"}
{"ts": "2026-01-02T18:15:21.002958+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 62669, "git_rev": "bf71a429"}
{"ts": "2026-01-02T18:15:38.538514+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "tools/atg_snap.zsh", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 62669, "git_rev": "bf71a429"}
```

### atg_runner.jsonl
```json
{"ts": "2026-01-03T01:15:19.515693+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md"}
{"ts": "2026-01-03T01:15:25.382934+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md", "duration_ms": 5867.54, "output": "atg_snapshot.md.summary.txt"}
{"ts": "2026-01-03T01:15:25.405154+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md"}
{"ts": "2026-01-03T01:15:26.478399+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md"}
{"ts": "2026-01-03T01:15:32.169996+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md", "duration_ms": 5691.55, "output": "atg_snapshot.md.summary.txt"}
{"ts": "2026-01-03T01:15:32.193405+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.json"}
{"ts": "2026-01-03T01:15:33.267116+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.json"}
{"ts": "2026-01-03T01:15:40.579750+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.json", "duration_ms": 7312.5, "output": "atg_snapshot.json.summary.txt"}
{"ts": "2026-01-03T01:15:40.602699+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "snapshot.md"}
{"ts": "2026-01-03T01:15:41.675586+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "snapshot.md"}
```

### gateway_v3_router.jsonl
```json
{"wo_id": "WO-GV3P0-LOCAL", "source_inbox": "MAIN", "target_inbox": "CLC", "strict_target": null, "routing_hint": "dev_oss", "action": "route", "status": "ok", "ts": "2025-12-16T17:35:53.347872+00:00"}
{"wo_id": "WO-PR11-V5-PING", "source_inbox": "MAIN", "target_inbox": "CLC", "strict_target": null, "routing_hint": null, "action": "route", "status": "ok", "ts": "2025-12-16T18:29:09.539205+00:00"}
{"wo_id": "WO-GV3P0-LOCAL", "source_inbox": "MAIN", "target_inbox": "CLC", "strict_target": null, "routing_hint": "dev_oss", "action": "route", "status": "ok", "ts": "2025-12-17T08:47:35.033647+00:00"}
{"wo_id": "WO-GV3P0-LOCAL", "source_inbox": "MAIN", "target_inbox": "CLC", "strict_target": null, "routing_hint": "dev_oss", "action": "route", "status": "ok", "ts": "2025-12-17T08:51:51.026049+00:00"}
{"wo_id": "WO-GV3P0-LOCAL", "source_inbox": "MAIN", "target_inbox": "CLC", "strict_target": null, "routing_hint": "dev_oss", "action": "route", "status": "ok", "ts": "2025-12-17T09:30:11.374438+00:00"}
{"wo_id": "WO-GV3P0-LOCAL", "source_inbox": "MAIN", "target_inbox": "CLC", "strict_target": null, "routing_hint": "dev_oss", "action": "route", "status": "ok", "ts": "2025-12-17T09:38:57.208551+00:00"}
{"wo_id": "WO-GV3P0-LOCAL", "source_inbox": "MAIN", "target_inbox": "CLC", "strict_target": null, "routing_hint": "dev_oss", "action": "route", "status": "ok", "ts": "2025-12-17T09:39:12.798125+00:00"}
{"wo_id": "unknown", "source_inbox": "MAIN", "action": "process_v5", "status": "ok", "strict_ops": 0, "local_ops": 0, "rejected_ops": 0, "moved_to": "/Users/icmini/02luka/bridge/processed_local/main/WO-V5-SMOKE-20251217_232932.yaml", "ts": "2025-12-17T16:29:32.869333+00:00"}
{"wo_id": "unknown", "source_inbox": "MAIN", "action": "process_v5", "status": "ok", "strict_ops": 0, "local_ops": 0, "rejected_ops": 0, "moved_to": "/Users/icmini/02luka/bridge/processed_local/main/WO-V5-SMOKE-20251218_002540.yaml", "ts": "2025-12-17T17:25:40.647934+00:00"}
```

## 5) Logs (Recent Errors)
```
--- gemini_bridge.err.log ---
(missing: /tmp/gemini_bridge.err.log)

--- /tmp/antigravity.*.log ---
(no /tmp/antigravity.*.log files)

--- bridge.stderr ---
  warning_logs.show_deprecation_warning()
/Users/icmini/02luka/infra/gemini_env/lib/python3.14/site-packages/vertexai/generative_models/_generative_models.py:433: UserWarning: This feature is deprecated as of June 24, 2025 and will be removed on June 24, 2026. For details, see https://cloud.google.com/vertex-ai/generative-ai/docs/deprecations/genai-vertexai-sdk.
  warning_logs.show_deprecation_warning()
/Users/icmini/02luka/infra/gemini_env/lib/python3.14/site-packages/vertexai/generative_models/_generative_models.py:433: UserWarning: This feature is deprecated as of June 24, 2025 and will be removed on June 24, 2026. For details, see https://cloud.google.com/vertex-ai/generative-ai/docs/deprecations/genai-vertexai-sdk.
  warning_logs.show_deprecation_warning()

--- fs_watcher.stderr ---
```
