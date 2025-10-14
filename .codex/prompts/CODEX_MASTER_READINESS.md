# 🧩 Codex Master Prompt — "02LUKA Ready to Work"

**Goal:** When this file is detected, Codex must verify the dev session is sane and ready:
- Correct working dir: /workspaces/02luka-repo (canonical, container) or ~/dev/02luka-repo (optional symlink, host)
- Node & Python available
- API (4000) & UI (5173) healthy
- Drive path usage avoided inside ProgramArguments (no "My Drive (1)")

---

## 🧠 System Context (ใช้เป็น system prompt)

You are Codex operating inside the 02LUKA system.

Golden Rules:
1. Operate only under:
   - Code SOT : /workspaces/02luka-repo (canonical, container) or ~/dev/02luka-repo (optional symlink, host)
   - Drive SOT: ~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka
2. Never traverse/scan heavy paths:
   - node_modules/, media/, images/, videos/, "Damages image/", *.jpeg, *.jpg, *.png, *.mov
3. Treat Google Drive as Stream Mode; only these are guaranteed offline:
   - 02luka, 02luka/02luka-repo, 02luka/g, 02luka/run
4. All scripts must be idempotent and path-safe.
5. No hardcoded "My Drive (1)" or spaces in symlink targets.
6. Prefer Bash/Python3 with strict error-handling + logging.
7. Be surgical: print commands you run + short outputs.

## Checklist for this session
1) `pwd` must equal `/workspaces/02luka-repo` (canonical, container) or `~/dev/02luka-repo` (optional symlink, host)
2) `node -v` and `python3 -V` should respond
3) `curl -fsS http://127.0.0.1:4000/api/ping` returns JSON with `"status":"ok"` or fallback
4) UI reachable at `http://localhost:5173/luka.html`
5) If any check fails, propose the exact one-liner fix, then run it.

## What Codex should do next
- Load `.codex/PREPROMPT.md` and apply project style in `.codex/style_adaptations.yml`
- Prefer short absolute paths: `/workspaces/02luka-repo` (canonical, container) or `~/dev/02luka-repo` (optional symlink, host)
- Use `scripts/repo_root_resolver.sh` for dynamic path resolution in scripts
- Use scripts:
  - `.codex/preflight.sh`
  - `run/dev_up_simple.sh`
  - `run/smoke_api_ui.sh`
- If LaunchAgents context is needed, read `g/reports/AGENT_VALUE_AUDIT_*.json` and do not write into CloudStorage paths.

## Output contract
- Print a 3-line status summary:
  - API: OK/FAIL + tip
  - UI : OK/FAIL + tip
  - Tooling: node/python present
- Then wait for my next instruction.

## 🧠 Dual Memory System Integration
- **Cursor AI Memory**: `.codex/hybrid_memory_system.md` - Local developer memory profile
- **CLC Memory**: `a/section/clc/memory/` - Persistent system memory for 02LUKA agents
- **Memory Bridge**: `.codex/codex_memory_bridge.yml` - YAML-based synchronization
- **Autosave Engine**: `.codex/autosave_memory.sh` → `g/reports/memory_autosave/` - Auto snapshots

## 🔖 Checkpoints & Tags
| Tag | Date | Description |
|-----|------|--------------|
| v2025-10-05-cursor-ready | 2025-10-05 | Cursor DevContainer ready, preflight OK |
| v2025-10-05-stabilized | 2025-10-05 | System stabilized, daily audit + boot guard enforced |
| v2025-10-05-docs-stable | 2025-10-05 | Stable baseline after Dual Memory + documentation unification |
| v2025-10-04-locked | 2025-10-04 | Dual Memory System locked baseline |

## 🧠 CLC Reasoning Model v1.1
- **Export**: `a/section/clc/logic/REASONING_MODEL_EXPORT.yaml`
- **Integration**: Wired into hybrid memory system
- **Features**: Rubric, anti-patterns, failure modes, recovery playbooks
- **Usage**: Follow pipeline: observe_context → expand_constraints → plan → act_small → self_check → reflect_and_trim → finalize_or_iterate

---

## 💻 User Prompt (ให้ Codex เริ่มทำงานจริง)

**Goal:** Prepare & validate 02LUKA for development — from path setup → repo → agent rationalization → Cursor workspace ready.
Do everything automatically, safely, and write a final markdown report.

---

### ✅ Step 1 — Verify & Fix Symlinks (atomic, path-safe)
```bash
set -euo pipefail
BASE="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive"
mkdir -p "$HOME/dev"
ln -snf "$BASE/02luka/02luka-repo" "$HOME/dev/02luka-repo"
ln -snf "$BASE/02luka"             "$HOME/dev/02luka"
ls -l "$HOME/dev/02luka" "$HOME/dev/02luka-repo"

Expect: ทั้งคู่ชี้ลง /My Drive/02luka… (ไม่มี "(1)")
```

⸻

### ✅ Step 2 — Repo Health (no heavy scan)
```bash
cd "$HOME/dev/02luka-repo"
git fetch --all --prune
git status
git branch --set-upstream-to=origin/main main 2>/dev/null || git branch -u origin/main || true
git remote -v
```

Report: current branch, ahead/behind, dirty/untracked summary

⸻

### ✅ Step 3 — Preflight & Smoke (fail-fast, collect logs)
```bash
cd "$HOME/dev/02luka-repo"
bash ./.codex/preflight.sh
bash ./run/dev_up_simple.sh
bash ./run/smoke_api_ui.sh
```

Capture: pass/fail + log paths (อย่า npm i ซ้ำถ้ามี node_modules แล้ว)

⸻

### ✅ Step 4 — Agent Rationalization Loop (enforce + audit)
```bash
D="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka"
bash "$D/g/runbooks/install_agent_rationalization.sh"
bash "$D/g/runbooks/boot_guard_enforce.sh"
bash "$D/g/runbooks/agent_value_audit.sh"
```

Summarize: total agents, missing scripts, bad log paths, disabled count

⸻

### ✅ Step 5 — Auto-fix Bad Log Paths (PlistBuddy → reload)
สำหรับทุก agent ที่ audit ว่า bad_log_paths:
```bash
LOGDIR="$HOME/Library/Logs/02luka"; mkdir -p "$LOGDIR"
# For each <label> (จากรายงาน audit):
PL="$HOME/Library/LaunchAgents/<label>.plist"
/usr/libexec/PlistBuddy -c "Set :StandardOutPath $LOGDIR/<label>.out" "$PL" || /usr/libexec/PlistBuddy -c "Add :StandardOutPath string $LOGDIR/<label>.out" "$PL"
/usr/libexec/PlistBuddy -c "Set :StandardErrorPath $LOGDIR/<label>.err" "$PL" || /usr/libexec/PlistBuddy -c "Add :StandardErrorPath string $LOGDIR/<label>.err" "$PL"
launchctl bootout "gui/$UID" "$PL" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PL"
```

แล้วรัน audit ซ้ำและแสดง before/after counts

⸻

### ✅ Step 6 — Cursor Integration (one-click run)
สร้าง/อัปเดต .vscode/tasks.json และ .vscode/launch.json (สำรองไฟล์เดิมอัตโนมัติ):
```bash
cd "$HOME/dev/02luka-repo"
mkdir -p .vscode
ts=".vscode/tasks.json"; lj=".vscode/launch.json"
[ -f "$ts" ] && cp "$ts" "$ts.backup-$(date +%s)" || true
[ -f "$lj" ] && cp "$lj" "$lj.backup-$(date +%s)" || true

cat > "$ts" <<'TASKS'
{
  "version": "2.0.0",
  "tasks": [
    { "label": "Preflight", "type": "shell", "command": "bash ./.codex/preflight.sh", "group": "build", "problemMatcher": [] },
    { "label": "Dev API",  "type": "shell", "command": "node boss-api/server.cjs", "group": "build", "problemMatcher": [] },
    { "label": "Dev UI",   "type": "shell", "command": "npm run dev", "options": { "cwd": "boss-ui" }, "group": "build", "problemMatcher": [] },
    { "label": "Smoke",    "type": "shell", "command": "bash ./run/smoke_api_ui.sh", "group": "test", "problemMatcher": [] }
  ]
}
TASKS

cat > "$lj" <<'LAUNCH'
{
  "version": "0.2.0",
  "configurations": [
    { "name": "Run 02LUKA API", "type": "node", "request": "launch", "program": "${workspaceFolder}/boss-api/server.cjs" },
    { "name": "Run 02LUKA UI",  "type": "node-terminal", "request": "launch", "command": "npm run dev", "cwd": "boss-ui" }
  ]
}
LAUNCH
```

⸻

### ✅ Step 7 — Model Router (dry-run only)
```bash
cd "$HOME/dev/02luka-repo"
bash ./g/tools/model_router.sh status || true
# If missing, propose (do not execute now):
echo "To install: bash ./g/tools/model_router.sh install qwen2.5-coder deepseek-coder llama3.1"
```

⸻

### ✅ Step 8 — Final Markdown Report (single file)
```bash
RDIR="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/g/reports"
mkdir -p "$RDIR"
RID="CODEX_READINESS_$(date +%y%m%d_%H%M)"
RPT="$RDIR/${RID}.md"

{
  echo "# Codex Readiness Report — $RID"
  echo
  echo "## Repo"
  git -C "$HOME/dev/02luka-repo" status -sb
  echo
  echo "## Remotes"
  git -C "$HOME/dev/02luka-repo" remote -v
  echo
  echo "## Preflight/Smoke"
  echo "- preflight.sh → see .codex logs"
  echo "- dev_up_simple.sh → completed"
  echo "- smoke_api_ui.sh → completed"
  echo
  echo "## Agents"
  echo "- boot_guard_enforce.sh → enforced"
  echo "- agent_value_audit.sh → audited (see latest JSON in g/reports)"
  echo "- bad log paths → fixed to ~/Library/Logs/02luka/*.{out,err} (if any)"
  echo
  echo "## Cursor Tasks/Launch"
  echo "- .vscode/tasks.json & launch.json updated (backups created)"
  echo
  echo "## Start Working Now"
  echo '```bash'
  echo 'cd ~/dev/02luka-repo'
  echo 'code .      # or: open -a "Cursor" .'
  echo '# Tasks: Preflight / Dev API / Dev UI / Smoke'
  echo '```'
} > "$RPT"

echo "✅ Report written: $RPT"
```

⸻

### Usage
ใช้เป็น "เอกสารเปิด Session" ให้ Codex/Cursor อ่านทุกครั้ง
