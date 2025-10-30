#!/usr/bin/env zsh
set -euo pipefail

say(){ print -P "%F{cyan}%D{%H:%M:%S}%f $1"; }
ok(){  print -P "%F{green}✓%f $1"; }
err(){ print -P "%F{red}✗%f $1" >&2; }

SCRIPT_DIR=$(cd "${0:h}" && pwd)
BASE="$HOME/02luka/g/services/lightrag"
APP="$BASE/app"
CFG="$BASE/config"
IDX="$BASE/indexes"
LOG="$BASE/logs"
SCRIPTS="$BASE/scripts"
PY="$BASE/.venv/bin/python"
PIP="$BASE/.venv/bin/pip"
REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6379/0}"

mkdir -p "$APP" "$CFG" "$IDX" "$LOG" "$SCRIPTS"

# 1) Python venv + deps
if [[ ! -d "$BASE/.venv" ]]; then
  say "Creating venv…"
  /usr/bin/python3 -m venv "$BASE/.venv"
fi
say "Installing deps…"
"$PIP" install --upgrade pip >/dev/null
"$PIP" install lightrag fastapi uvicorn pydantic python-dotenv pyyaml redis requests >/dev/null || {
  err "pip install failed"; exit 1; }
ok "Deps installed"

# 2) Sync service + configs from repo template
say "Syncing service files…"
cp "$SCRIPT_DIR/app/service.py" "$APP/service.py"
if [[ ! -f "$CFG/agents.yaml" ]]; then
  cp "$SCRIPT_DIR/config/agents.yaml" "$CFG/agents.yaml"
  ok "Default agents.yaml installed"
else
  cp "$SCRIPT_DIR/config/agents.yaml" "$CFG/agents.yaml.dist"
  say "Existing agents.yaml preserved (updated template at agents.yaml.dist)"
fi
cp "$SCRIPT_DIR/ingest_all.zsh" "$BASE/ingest_all.zsh"
cp "$SCRIPT_DIR/run_agent.zsh" "$BASE/run_agent.zsh"
cp "$SCRIPT_DIR/kim_rag.sh" "$BASE/kim_rag.sh"
cp "$SCRIPT_DIR/scripts/install_nightly_launchagent.zsh" "$SCRIPTS/install_nightly_launchagent.zsh"
chmod +x "$BASE/ingest_all.zsh" "$BASE/run_agent.zsh" "$BASE/kim_rag.sh" "$SCRIPTS/install_nightly_launchagent.zsh"
ok "Service assets synced"

# 3) LaunchAgents per agent
mk_plist(){
  local agent="$1" label="com.02luka.lightrag.${agent}"
  local plist="$HOME/Library/LaunchAgents/${label}.plist"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>${label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>~/02luka/g/services/lightrag/run_agent.zsh ${agent}</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>LT_REDIS_URL</key><string>${REDIS_URL:-redis://127.0.0.1:6379/0}</string>
  </dict>
  <key>StandardOutPath</key><string>/tmp/lightrag_${agent}.out</string>
  <key>StandardErrorPath</key><string>/tmp/lightrag_${agent}.err</string>
</dict></plist>
PLIST
  launchctl unload "$plist" 2>/dev/null || true
  launchctl load  "$plist"
}

for a in cls mary paula qs rooney sumo lisa kim; do
  mk_plist "$a"
done
ok "LaunchAgents refreshed"

say "Install complete. Key commands:"
print "  # Manually run an agent"
print "  ~/02luka/g/services/lightrag/run_agent.zsh cls"
print "  # Reload config via HTTP"
print "  curl -X POST http://127.0.0.1:7210/reload-config"
print "  # Nightly re-ingest LaunchAgent"
print "  ~/02luka/g/services/lightrag/scripts/install_nightly_launchagent.zsh"
print "  # Kim quick query"
print "  ~/02luka/g/services/lightrag/kim_rag.sh \"What is Phase 12 status?\""

ok "Lightrag service installed"
