# 📸 Antigravity System Snapshot
**Timestamp (UTC):** 2026-01-04T18:59:52Z
**Timestamp (Local):** 2026-01-05T01:59:52+0700
**Repo Root:** /Users/icmini/02luka
**Branch:** main
**HEAD:** 82926687

## 1. Git Context 🌳
### Command: `git -C '/Users/icmini/02luka' status --porcelain=v1`
```text
 M .claude/settings.local.json
 M magic_bridge/inbox/atg_snapshot.md
 M magic_bridge/outbox/atg_snapshot.json
 M magic_bridge/outbox/atg_snapshot.md.summary.txt
 M tools/raycast_atg_snapshot.zsh
```
**Exit Code:** 0

### Command: `git -C '/Users/icmini/02luka' log -1 --oneline`
```text
82926687 auto-save: 2026-01-05 01:31:11 +0700
```
**Exit Code:** 0

### Command: `git -C '/Users/icmini/02luka' diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)'`
```text
 .claude/settings.local.json                        |   3 +-
 .../pr11_healthcheck/2026-01-05T00:30:45.json      |  16 ++
 magic_bridge/inbox/atg_snapshot.md                 | 207 ---------------------
 magic_bridge/outbox/atg_snapshot.json              |   4 +-
 magic_bridge/outbox/atg_snapshot.md.summary.txt    |  22 +--
 tools/raycast_atg_snapshot.zsh                     |   7 +
 6 files changed, 37 insertions(+), 222 deletions(-)
```
**Exit Code:** 0

## 2. Runtime Context ⚙️
### Command: `pgrep -fl 'gemini_bridge|bridge\.sh|api_server|antigravity|fs_watcher|python' | grep -v atg_snap`
```text
2241 /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python /Users/icmini/02luka/agents/memory_hub/memory_hub.py /Users/icmini/LocalProjects/02luka_local_g/.venv/bin/python3 ~/02luka/agents/memory_hub/memory_hub.py
9772 /opt/homebrew/Cellar/python@3.14/3.14.0_1/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python -m http.server 8088
11067 /opt/homebrew/Cellar/python@3.14/3.14.0_1/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python api_server.py
11097 /opt/homebrew/Cellar/python@3.14/3.14.0_1/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python -c from multiprocessing.resource_tracker import main;main(4)
18280 /opt/homebrew/Cellar/python@3.14/3.14.0_1/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python -c from multiprocessing.spawn import spawn_main; spawn_main(tracker_fd=5, pipe_handle=7) --multiprocessing-fork
47832 /opt/homebrew/Cellar/python@3.14/3.14.0_1/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python /Users/icmini/02luka/tools/fs_watcher.py
65633 /opt/homebrew/Cellar/python@3.14/3.14.0_1/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python -u /Users/icmini/02luka/gemini_bridge.py
71535 /Applications/Antigravity.app/Contents/Resources/app/extensions/antigravity/bin/language_server_macos_arm --enable_lsp --extension_server_port 50400 --csrf_token 5d604a9c-3d6d-4235-94f7-f7d771262967 --random_port --workspace_id file_Users_icmini_02luka_02luka_antigravity_code_workspace --cloud_code_endpoint https://daily-cloudcode-pa.googleapis.com --app_data_dir antigravity --parent_pipe_path /var/folders/bm/8smk0tgn55q9zf1bh3l0n9zw0000gn/T/server_712e72b6cc45db6d
71675 /Applications/Antigravity.app/Contents/Frameworks/Antigravity Helper (Plugin).app/Contents/MacOS/Antigravity Helper (Plugin) /Users/icmini/.antigravity/extensions/github.vscode-github-actions-0.28.2-universal/dist/server-node.js --node-ipc --clientProcessId=71409
71736 /Users/icmini/.antigravity/extensions/openai.chatgpt-0.4.49/bin/macos-aarch64/codex app-server
71865 /Users/icmini/.antigravity/extensions/meta.pyrefly-0.46.3-darwin-arm64/bin/pyrefly lsp
86935 node /opt/homebrew/bin/antigravity-claude-proxy start
```
**Exit Code:** 0

### Command: `/Users/icmini/02luka/tools/ports_check.zsh`
```text
PORT   SERVICE            POLICY     STATUS    PID             COMMAND
------------------------------------------------------------------------------------------
8000   api_server         protected  safe      11067           /opt/homebrew/Cellar/python@3.14/3.14.0_... (+1 workers)
8001   fastapi-dev        free       safe      -               (free)
8080   claude_proxy       managed    safe      86935           node /opt/homebrew/bin/antigravity-claude-proxy start
------------------------------------------------------------------------------------------
```
**Exit Code:** 0

## 3. Telemetry Pulse 📈
(Tailing last 50 lines - Checks for missing files)
### Command: `tail -n 50 '/Users/icmini/02luka/g/telemetry/atg_runner.jsonl' 2>/dev/null || echo '_File not found: atg_runner.jsonl_'`
```text
{"ts": "2026-01-03T02:34:53.735457+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-03T02:34:53.736049+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md"}
{"ts": "2026-01-03T02:36:04.838574+07:00", "event": "startup", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "watch_dir": "/Users/icmini/02luka/magic_bridge/inbox", "model": "gemini-2.0-flash-001"}
{"ts": "2026-01-03T02:36:06.825233+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-03T02:36:06.885310+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md"}
{"ts": "2026-01-03T02:36:13.350939+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md", "duration_ms": 6465.382099151611, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-03T02:37:37.298980+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-03T02:37:37.301365+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md"}
{"ts": "2026-01-03T02:37:40.968111+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md", "duration_ms": 3666.944980621338, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-03T02:39:52.705206+07:00", "event": "startup", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "watch_dir": "/Users/icmini/02luka/magic_bridge/inbox", "model": "gemini-2.0-flash-001"}
{"ts": "2026-01-03T02:41:23.248581+07:00", "event": "startup", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "watch_dir": "/Users/icmini/02luka/magic_bridge/inbox", "model": "gemini-2.0-flash-001"}
{"ts": "2026-01-03T02:42:26.787240+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-03T02:42:26.788322+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md"}
{"ts": "2026-01-03T02:42:31.590731+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "file": "atg_snapshot.md", "duration_ms": 4802.063941955566, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-03T03:18:15.526416+07:00", "event": "startup", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 22176, "watch_dir": "/Users/icmini/02luka/magic_bridge/inbox", "model": "gemini-2.0-flash-001"}
{"ts": "2026-01-03T03:23:06.422805+07:00", "event": "startup", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 28224, "watch_dir": "/Users/icmini/02luka/magic_bridge/inbox", "model": "gemini-2.0-flash-001"}
{"ts": "2026-01-03T03:23:17.687163+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 28224, "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-03T03:23:17.687583+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 28224, "file": "atg_snapshot.md"}
{"ts": "2026-01-03T03:23:22.093952+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 28224, "file": "atg_snapshot.md", "duration_ms": 4406.364917755127, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-05T01:08:34.368248+07:00", "event": "startup", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "watch_dir": "/Users/icmini/02luka/magic_bridge/inbox", "model": "gemini-2.0-flash-001"}
{"ts": "2026-01-05T01:09:13.755360+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-05T01:09:13.756401+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md"}
{"ts": "2026-01-05T01:09:18.749604+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "duration_ms": 4993.046998977661, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-05T01:09:25.021570+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-05T01:09:25.022295+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md"}
{"ts": "2026-01-05T01:09:28.103570+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "duration_ms": 3080.735921859741, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-05T01:17:26.240023+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-05T01:17:26.298996+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md"}
{"ts": "2026-01-05T01:17:30.737750+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "duration_ms": 4439.324140548706, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-05T01:22:33.079680+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-05T01:22:33.232431+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md"}
{"ts": "2026-01-05T01:22:39.801707+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "duration_ms": 6592.031240463257, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-05T01:27:48.885049+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-05T01:27:48.900948+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md"}
{"ts": "2026-01-05T01:27:52.674227+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "duration_ms": 3778.29909324646, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-05T01:30:24.942955+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-05T01:30:24.955717+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md"}
{"ts": "2026-01-05T01:30:28.530986+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "duration_ms": 3575.327157974243, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-05T01:38:21.907950+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-05T01:38:21.911616+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md"}
{"ts": "2026-01-05T01:38:26.181813+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "duration_ms": 4270.701885223389, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-05T01:52:11.964893+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-05T01:52:11.989318+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md"}
{"ts": "2026-01-05T01:52:15.547204+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "duration_ms": 3557.9731464385986, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-05T01:52:22.032571+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-05T01:52:22.035946+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md"}
{"ts": "2026-01-05T01:52:24.800482+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "duration_ms": 2765.4600143432617, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
{"ts": "2026-01-05T01:52:35.397724+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-05T01:52:35.398432+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md"}
{"ts": "2026-01-05T01:52:38.280168+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "duration_ms": 2881.743907928467, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
```
**Exit Code:** 0

### Command: `tail -n 50 '/Users/icmini/02luka/g/telemetry/fs_index.jsonl' 2>/dev/null || echo '_File not found: fs_index.jsonl_'`
```text
{"ts": "2026-01-02T19:50:11.307252+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-02T19:53:57.089915+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-02T20:17:44.142445+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-02T20:21:18.550351+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-02T20:26:02.711707+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "tools", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-02T20:26:02.713421+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "tools/atg_bridge_restart.zsh", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-02T20:26:06.479840+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "tools/atg_stop_loop_now.zsh", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-02T20:36:50.265280+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/docs/LAUNCHAGENT_REGISTRY.md", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-02T21:15:28.963488+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-02T21:15:28.966162+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures/.seen_runs", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T01:00:02.266466+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T01:00:02.268987+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health/health_20260103.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T01:00:05.916389+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T01:00:05.916647+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health/health_20260103.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T05:30:48.110294+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/pr11_healthcheck", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T05:30:48.111161+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/pr11_healthcheck/2026-01-03T12:30:45.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T17:10:55.074981+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T17:10:55.077101+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures/.seen_runs", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T17:30:46.719624+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/pr11_healthcheck", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T17:30:46.720590+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/pr11_healthcheck/2026-01-04T00:30:45.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T17:41:56.374028+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T17:41:56.435759+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures/.seen_runs", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T21:17:25.629580+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-03T21:17:25.630742+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures/.seen_runs", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T01:00:01.635767+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T01:00:01.698660+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health/health_20260104.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T01:00:01.698808+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/system", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T01:00:01.698883+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/system/system_governance_WEEKLY_20260104.md", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T01:00:12.590356+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T01:00:12.667673+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health/health_20260104.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T05:30:46.840423+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/pr11_healthcheck", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T05:30:46.841480+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/pr11_healthcheck/2026-01-04T12:30:45.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T17:11:22.804139+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T17:11:22.806350+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures/.seen_runs", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T17:30:48.361814+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/pr11_healthcheck", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T17:30:48.363104+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/pr11_healthcheck/2026-01-05T00:30:45.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T17:41:37.953548+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T17:41:37.955862+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures/.seen_runs", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T18:09:15.592335+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T18:09:26.634075+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T18:17:28.491861+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T18:22:35.455817+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T18:27:50.910612+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T18:30:27.138923+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T18:38:23.402592+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T18:52:15.405379+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T18:52:23.266668+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T18:52:35.671196+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T18:59:50.219944+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "tools", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T18:59:50.220957+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "tools/raycast_atg_snapshot.zsh", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
```
**Exit Code:** 0

## 4. System Logs (Errors) 🚨
(Tailing last 50 lines)
### Command: `tail -n 50 '/tmp/com.02luka.fs_watcher.stderr.log'`
```text
(no output)
```
**Exit Code:** 0

### Command: `tail -n 50 '/tmp/com.02luka.fs_watcher.stdout.log'`
```text
Starting fs_watcher launcher at Sat Jan  3 00:34:58 +07 2026
Starting fs_watcher launcher at Sat Jan  3 02:13:14 +07 2026
```
**Exit Code:** 0

### Command: `tail -n 50 '/tmp/com.antigravity.bridge.stderr.log'`
```text
/Users/icmini/02luka/infra/gemini_env/lib/python3.14/site-packages/vertexai/generative_models/_generative_models.py:433: UserWarning: This feature is deprecated as of June 24, 2025 and will be removed on June 24, 2026. For details, see https://cloud.google.com/vertex-ai/generative-ai/docs/deprecations/genai-vertexai-sdk.
  warning_logs.show_deprecation_warning()
/Users/icmini/02luka/infra/gemini_env/lib/python3.14/site-packages/vertexai/generative_models/_generative_models.py:433: UserWarning: This feature is deprecated as of June 24, 2025 and will be removed on June 24, 2026. For details, see https://cloud.google.com/vertex-ai/generative-ai/docs/deprecations/genai-vertexai-sdk.
  warning_logs.show_deprecation_warning()
```
**Exit Code:** 0

### Command: `tail -n 50 '/tmp/com.antigravity.bridge.stdout.log'`
```text
📝 Detected change in: atg_snapshot.md (inbox)
   🚀 Sending to Vertex AI (gemini-2.0-flash-001)...
   ✅ Saved response to: atg_snapshot.md.summary.txt (in outbox)
📝 Detected change in: atg_snapshot.md (inbox)
   🚀 Sending to Vertex AI (gemini-2.0-flash-001)...
   ✅ Saved response to: atg_snapshot.md.summary.txt (in outbox)
📝 Detected change in: atg_snapshot.md (inbox)
   ⏭️  Skipping (content unchanged): atg_snapshot.md
📝 Detected change in: atg_snapshot.md (inbox)
   🚀 Sending to Vertex AI (gemini-2.0-flash-001)...
   ✅ Saved response to: atg_snapshot.md.summary.txt (in outbox)
📝 Detected change in: atg_snapshot.md (inbox)
   ⏭️  Skipping (content unchanged): atg_snapshot.md
📝 Detected change in: atg_snapshot.md (inbox)
   🚀 Sending to Vertex AI (gemini-2.0-flash-001)...
   ✅ Saved response to: atg_snapshot.md.summary.txt (in outbox)
📝 Detected change in: atg_snapshot.md (inbox)
   ⏭️  Skipping (content unchanged): atg_snapshot.md
📝 Detected change in: atg_snapshot.md (inbox)
   🚀 Sending to Vertex AI (gemini-2.0-flash-001)...
   ✅ Saved response to: atg_snapshot.md.summary.txt (in outbox)
📝 Detected change in: atg_snapshot.md (inbox)
   ⏭️  Skipping (content unchanged): atg_snapshot.md
📝 Detected change in: atg_snapshot.md (inbox)
   🚀 Sending to Vertex AI (gemini-2.0-flash-001)...
   ✅ Saved response to: atg_snapshot.md.summary.txt (in outbox)
📝 Detected change in: atg_snapshot.md (inbox)
   ⏭️  Skipping (content unchanged): atg_snapshot.md
📝 Detected change in: atg_snapshot.md (inbox)
📝 Detected change in: atg_snapshot.md (inbox)
   🚀 Sending to Vertex AI (gemini-2.0-flash-001)...
   ✅ Saved response to: atg_snapshot.md.summary.txt (in outbox)
📝 Detected change in: atg_snapshot.md (inbox)
   ⏭️  Skipping (content unchanged): atg_snapshot.md
📝 Detected change in: atg_snapshot.md (inbox)
   🚀 Sending to Vertex AI (gemini-2.0-flash-001)...
   ✅ Saved response to: atg_snapshot.md.summary.txt (in outbox)
📝 Detected change in: atg_snapshot.md (inbox)
   ⏭️  Skipping (content unchanged): atg_snapshot.md
📝 Detected change in: atg_snapshot.md (inbox)
   🚀 Sending to Vertex AI (gemini-2.0-flash-001)...
   ✅ Saved response to: atg_snapshot.md.summary.txt (in outbox)
📝 Detected change in: atg_snapshot.md (inbox)
   ⏭️  Skipping (content unchanged): atg_snapshot.md
📝 Detected change in: atg_snapshot.md (inbox)
   🚀 Sending to Vertex AI (gemini-2.0-flash-001)...
   ✅ Saved response to: atg_snapshot.md.summary.txt (in outbox)
📝 Detected change in: atg_snapshot.md (inbox)
   ⏭️  Skipping (content unchanged): atg_snapshot.md
📝 Detected change in: atg_snapshot.md (inbox)
```
**Exit Code:** 0

## 5. Metadata
Snapshot Version: 2.1 (Strict Mode)
Mode: Rewrite
