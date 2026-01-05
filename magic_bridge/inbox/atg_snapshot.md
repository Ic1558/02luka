# 📸 Antigravity System Snapshot
**Timestamp (UTC):** 2026-01-05T07:19:40Z
**Timestamp (Local):** 2026-01-05T14:19:40+0700
**Repo Root:** /Users/icmini/02luka
**Branch:** main
**HEAD:** 6efce5d2

## 1. Git Context 🌳
### Command: `git -C '/Users/icmini/02luka' status --porcelain=v1`
```text
 M .claude/settings.local.json
 M bridge.sh
 M g/governance/atg_remediation.zsh
 M magic_bridge/inbox/atg_snapshot.md
?? g/reports/pr11_healthcheck/2026-01-05T12:30:46.json
```
**Exit Code:** 0

### Command: `git -C '/Users/icmini/02luka' log -1 --oneline`
```text
6efce5d2 governance(atg): P0 soft fixes (Electron detect + codex missing=>WARN)
```
**Exit Code:** 0

### Command: `git -C '/Users/icmini/02luka' diff --stat HEAD~1 2>/dev/null || echo '(Initial commit or no parent)'`
```text
 .claude/settings.local.json                        |   3 +-
 bridge.sh                                          |   7 +
 g/governance/atg_invariants.zsh                    |   7 +-
 g/governance/atg_remediation.zsh                   |   2 +-
 .../260105_atg_governance_p0_evidence.md           | 139 +++++++++++
 magic_bridge/inbox/atg_snapshot.md                 | 259 ---------------------
 6 files changed, 153 insertions(+), 264 deletions(-)
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
54224 node /opt/homebrew/bin/antigravity-claude-proxy start
54373 /Applications/Antigravity.app/Contents/Resources/app/extensions/antigravity/bin/language_server_macos_arm --enable_lsp --extension_server_port 53420 --csrf_token c8e5bcaf-acfc-4037-9c84-e8a8bc2e0dca --random_port --workspace_id file_Users_icmini_02luka_02luka_antigravity_code_workspace --cloud_code_endpoint https://daily-cloudcode-pa.googleapis.com --app_data_dir antigravity --parent_pipe_path /var/folders/bm/8smk0tgn55q9zf1bh3l0n9zw0000gn/T/server_f7ed8929eb1c3988
54539 /Applications/Antigravity.app/Contents/Frameworks/Antigravity Helper (Plugin).app/Contents/MacOS/Antigravity Helper (Plugin) /Users/icmini/.antigravity/extensions/github.vscode-github-actions-0.29.0-universal/dist/server-node.js --node-ipc --clientProcessId=54279
54649 /Users/icmini/.antigravity/extensions/openai.chatgpt-0.4.49/bin/macos-aarch64/codex app-server
55198 /Users/icmini/.antigravity/extensions/meta.pyrefly-0.46.3-darwin-arm64/bin/pyrefly lsp
55591 /Applications/Antigravity.app/Contents/Frameworks/Antigravity Helper (Plugin).app/Contents/MacOS/Antigravity Helper (Plugin) /Users/icmini/.antigravity/extensions/google.geminicodeassist-2.64.0-universal/agent/a2a-server.mjs
65633 /opt/homebrew/Cellar/python@3.14/3.14.0_1/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python -u /Users/icmini/02luka/gemini_bridge.py
```
**Exit Code:** 0

### Command: `/Users/icmini/02luka/tools/ports_check.zsh`
```text
PORT   SERVICE            POLICY     STATUS    PID             COMMAND
------------------------------------------------------------------------------------------
8000   api_server         protected  safe      11067           /opt/homebrew/Cellar/python@3.14/3.14.0_... (+1 workers)
8001   fastapi-dev        free       safe      -               (free)
8080   claude_proxy       managed    safe      54224           node /opt/homebrew/bin/antigravity-claude-proxy start
------------------------------------------------------------------------------------------
```
**Exit Code:** 0

## 3. Telemetry Pulse 📈
(Tailing last 50 lines - Checks for missing files)
### Command: `tail -n 50 '/Users/icmini/02luka/g/telemetry/atg_runner.jsonl' 2>/dev/null || echo '_File not found: atg_runner.jsonl_'`
```text
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
{"ts": "2026-01-05T01:59:53.572397+07:00", "event": "file_detected", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "dir": "inbox"}
{"ts": "2026-01-05T01:59:53.589435+07:00", "event": "processing_start", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md"}
{"ts": "2026-01-05T01:59:57.590854+07:00", "event": "processing_complete", "lane": "ATG_RUNNER", "actor": "gemini_bridge", "pid": 65633, "file": "atg_snapshot.md", "duration_ms": 4001.5549659729004, "output_file": "atg_snapshot.md.summary.txt", "output_dir": "outbox"}
```
**Exit Code:** 0

### Command: `tail -n 50 '/Users/icmini/02luka/g/telemetry/fs_index.jsonl' 2>/dev/null || echo '_File not found: fs_index.jsonl_'`
```text
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
{"ts": "2026-01-04T18:59:54.598988+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/ports_check_latest.txt", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T21:17:34.302218+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-04T21:17:34.304444+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/gh_failures/.seen_runs", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-05T01:00:02.196521+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-05T01:00:02.197972+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health/health_20260105.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-05T01:00:05.580044+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health/health_20260105.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-05T01:00:16.314021+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health/health_20260105.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-05T01:00:19.790327+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-05T01:00:19.803562+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/health/health_20260105.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-05T05:30:46.645105+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/pr11_healthcheck", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-05T05:30:46.646180+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/pr11_healthcheck/2026-01-05T12:30:46.json", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-05T07:12:24.239796+00:00", "event": "modified", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-05T07:12:24.240590+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/atg_incidents", "type": "dir", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
{"ts": "2026-01-05T07:12:24.241876+00:00", "event": "created", "lane": "FS_DAEMON", "actor": "unknown", "file": "g/reports/ops/atg_incidents/260105_atg_governance_p0_evidence.md", "type": "file", "host": "Ittipongs-Mac-mini.local", "pid": 47832, "git_rev": "cfd22d29"}
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
   🚀 Sending to Vertex AI (gemini-2.0-flash-001)...
   ✅ Saved response to: atg_snapshot.md.summary.txt (in outbox)
📝 Detected change in: atg_snapshot.md (inbox)
   ⏭️  Skipping (content unchanged): atg_snapshot.md
```
**Exit Code:** 0

## 5. Metadata
Snapshot Version: 2.1 (Strict Mode)
Mode: Rewrite
