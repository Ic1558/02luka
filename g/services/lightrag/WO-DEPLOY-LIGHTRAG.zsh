#!/usr/bin/env bash
set -euo pipefail
# NOTE: This script requires bash; run via `bash` not `zsh` to avoid container issues.


timestamp() {
  date +"%H:%M:%S"
}

say() {
  printf '\033[36m%s\033[0m  %s\n' "$(timestamp)" "$*"
}

ok() {
  printf '\033[32m✓\033[0m %s\n' "$*"
}

err() {
  printf '\033[31m✗\033[0m %s\n' "$*" >&2
}

# --- Settings ---
REPO_ROOT="${REPO_ROOT:-$HOME/02luka}"
AGENTS=(cls mary paula qs rooney sumo lisa kim)
BASE="$REPO_ROOT/g/services/lightrag"
LOGDIR="${LIGHTRAG_LOGDIR:-/tmp}"
PY="$BASE/.venv/bin/python3"
PIP="$BASE/.venv/bin/pip"
PORT_BASE=${LIGHTRAG_PORT_BASE:-7210}   # will map sequentially by index

# --- Ensure tree & venv ---
say "Prepare directories"
mkdir -p "$BASE"/{bin,conf}
python3 -m venv "$BASE/.venv"
# shellcheck disable=SC1090
source "$BASE/.venv/bin/activate"

say "Install python deps"
"$PIP" install --upgrade pip wheel >/dev/null
# Minimal REST + RAG skeleton (adjust if you pinned versions in repo)
"$PIP" install "fastapi>=0.115" "uvicorn[standard]>=0.30" pydantic requests pyyaml >/dev/null

# --- Write runner script (shared) ---
RUNNER="$BASE/bin/serve.py"
cat > "$RUNNER" <<'PY'
import argparse
import time
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional, List
import uvicorn

app = FastAPI()

class QueryIn(BaseModel):
    agent: str
    q: str
    top_k: Optional[int] = 5

class IngestIn(BaseModel):
    agent: str
    sources: Optional[List[str]] = None

BOOT_TS = time.time()

@app.get("/health")
def health():
    return {"status": "ok", "uptime_s": round(time.time() - BOOT_TS, 2)}

@app.post("/query")
def query(q: QueryIn):
    # placeholder that echoes; real Lightrag backends can be wired later
    return {"agent": q.agent, "answer": f"(stub) You asked: {q.q}", "top_k": q.top_k}

@app.post("/ingest")
def ingest(inp: IngestIn):
    return {"agent": inp.agent, "ingested": inp.sources or ["default"], "status": "ok"}

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--agent", required=True)
    ap.add_argument("--port", type=int, required=True)
    args = ap.parse_args()
    uvicorn.run("serve:app", host="127.0.0.1", port=args.port, reload=False)
PY

# --- Small shim so uvicorn can import it as "serve:app" ---
cat > "$BASE/bin/serve.pyproj" <<'PY'
from serve import app  # noqa
PY

# --- Per-agent launch sh ---
LAUNCH_SH="$BASE/bin/run_agent.zsh"
cat > "$LAUNCH_SH" <<'INNERZSH'
#!/usr/bin/env zsh
set -euo pipefail
AGENT="${1:?agent name}"
PORT="${2:?port}"
BASE="${REPO_ROOT:-$HOME/02luka}/g/services/lightrag"
LOG="${LIGHTRAG_LOGDIR:-/tmp}/lightrag_${AGENT}.out"
ERR="${LIGHTRAG_LOGDIR:-/tmp}/lightrag_${AGENT}.err"
exec "$BASE/.venv/bin/python3" "$BASE/bin/serve.py" --agent "$AGENT" --port "$PORT" >>"$LOG" 2>>"$ERR"
INNERZSH
chmod +x "$LAUNCH_SH"

# --- Per-agent configs & LaunchAgents ---
say "Create LaunchAgents"
agent_count=${#AGENTS[@]}
for ((idx = 0; idx < agent_count; idx++)); do
  agent="${AGENTS[$idx]}"
  port=$((PORT_BASE + idx))

  # Config (room to extend later)
  cat > "$BASE/conf/${agent}.yaml" <<YML
agent: ${agent}
port: ${port}
sources:
  - "\$HOME/02luka/memory/${agent}"
  - "\$HOME/02luka/g/reports"
YML

  # LaunchAgent
  PLIST="$HOME/Library/LaunchAgents/com.02luka.lightrag.${agent}.plist"
  cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.02luka.lightrag.${agent}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string><string>-lc</string>
    <string>$BASE/bin/run_agent.zsh ${agent} ${port}</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$BASE/.venv/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>REPO_ROOT</key><string>$REPO_ROOT</string>
    <key>LIGHTRAG_LOGDIR</key><string>$LOGDIR</string>
  </dict>
  <key>StandardOutPath</key><string>$LOGDIR/lightrag_${agent}.out</string>
  <key>StandardErrorPath</key><string>$LOGDIR/lightrag_${agent}.err</string>
</dict></plist>
PL

  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load "$PLIST"
done

# --- Health check ---
say "Health check"
sleep 1
FAIL=0
for ((idx = 0; idx < agent_count; idx++)); do
  agent="${AGENTS[$idx]}"
  port=$((PORT_BASE + idx))
  if curl -fsS "http://127.0.0.1:${port}/health" >/dev/null; then
    ok "${agent} : http://127.0.0.1:${port}  (healthy)"
  else
    err "${agent} on :${port} failed health"
    FAIL=1
  fi
done

echo
say "Examples (Kim)"
echo "  curl -s http://127.0.0.1:$((PORT_BASE + 7))/health | jq"
echo "  curl -s -X POST http://127.0.0.1:$((PORT_BASE + 7))/query -H 'content-type: application/json' -d '{\"agent\":\"kim\",\"q\":\"Where are Phase 12 reports?\"}' | jq"

if [[ "$FAIL" -eq 0 ]]; then
  ok "Lightrag deployed for agents: ${AGENTS[*]}"
else
  err "Some agents failed health (see ${LOGDIR}/lightrag_*.err)"
fi
