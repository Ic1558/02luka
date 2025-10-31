#!/usr/bin/env zsh
set -euo pipefail

# -------- Config (override ได้ด้วย env) --------
: ${LOG_DIR:="$HOME/02luka/logs/agent"}
: ${LOG_FILE:="$LOG_DIR/deploy_dashboard.log"}
: ${DRY_RUN:="1"}            # 1=dry-run, 0=apply
: ${DASHBOARD_PLIST:="$HOME/Library/LaunchAgents/com.02luka.dashboard.plist"}
: ${DASHBOARD_DIR:="$HOME/02luka/web/dashboard"}               # ถ้ามี Next/Node
: ${DASHBOARD_STACK:="$HOME/02luka/docker/dashboard"}          # ถ้ามี docker-compose
# ลำดับตรวจสุขภาพหลายเป้า เลือกอันที่ตอบได้อันแรก
: ${HEALTH_CANDIDATES:="http://127.0.0.1:4100/health http://127.0.0.1:4100 http://127.0.0.1:4000/health http://127.0.0.1:4000 http://127.0.0.1:3000/health http://127.0.0.1:3000 http://127.0.0.1:5173/health http://127.0.0.1:5173 http://127.0.0.1:4173/health http://127.0.0.1:4173 http://127.0.0.1:8080/health http://127.0.0.1:8080"}

mkdir -p "$LOG_DIR"

ts() { /usr/bin/python3 -c 'import time;print(int(time.time()*1000))'; }
log() { print -r -- "$(date -u '+%Y-%m-%dT%H:%M:%S').$(ts)# $*" | tee -a "$LOG_FILE" >/dev/null; }
run() { log "RUN: $*"; if [[ "$DRY_RUN" == "1" ]]; then return 0; fi; eval "$@"; }

ok()  { log "OK: $*"; }
err() { log "ERR: $*"; return 1; }

# -------- Step A: LaunchAgent route --------
restart_launchagent() {
  if [[ -f "$DASHBOARD_PLIST" ]]; then
    run "launchctl unload '$DASHBOARD_PLIST' || true"
    run "launchctl load  '$DASHBOARD_PLIST'"
    ok "LaunchAgent reloaded: $DASHBOARD_PLIST"
    return 0
  fi
  return 1
}

# -------- Step B: Docker route --------
docker_up() {
  local yml=""
  if [[ -f "$DASHBOARD_STACK/docker-compose.yml" ]]; then
    yml="$DASHBOARD_STACK/docker-compose.yml"
  elif [[ -f "$DASHBOARD_STACK/compose.yml" ]]; then
    yml="$DASHBOARD_STACK/compose.yml"
  else
    return 1
  fi
  # พยายามเจาะจง service "dashboard" ถ้ามี ไม่งั้น up ทั้ง stack
  if grep -qiE '^\s*dashboard:' "$yml"; then
    run "docker compose -f '$yml' pull dashboard || true"
    run "docker compose -f '$yml' up -d dashboard"
  else
    run "docker compose -f '$yml' pull || true"
    run "docker compose -f '$yml' up -d"
  fi
  ok "Docker up done ($yml)"
  return 0
}

# -------- Step C: Node build/serve route --------
node_build() {
  if [[ -f "$DASHBOARD_DIR/package.json" ]]; then
    local npm_bin="npm"
    command -v pnpm >/dev/null 2>&1 && npm_bin="pnpm"
    command -v bun  >/dev/null 2>&1 && npm_bin="bun"

    case "$npm_bin" in
      npm)  run "cd '$DASHBOARD_DIR' && npm ci && npm run build" ;;
      pnpm) run "cd '$DASHBOARD_DIR' && pnpm i --frozen-lockfile && pnpm build" ;;
      bun)  run "cd '$DASHBOARD_DIR' && bun i && bun run build" ;;
    esac
    ok "Node build via $npm_bin completed at $DASHBOARD_DIR"
    return 0
  fi
  return 1
}

# -------- Health check --------
health_check() {
  emulate -L zsh
  local url
  for url in ${(z)HEALTH_CANDIDATES}; do
    if out="$(curl -fsS --max-time 2 "$url" 2>/dev/null)"; then
      ok "Health OK at $url :: $(print -r -- $out)"
      return 0
    fi
  done
  err "No health endpoint responded (${HEALTH_CANDIDATES})"
}

# -------- Main flow (A -> B -> C) --------
log "===== deploy_dashboard start (DRY_RUN=$DRY_RUN) ====="
did=0
restart_launchagent && did=1 || true
(( did == 0 )) && docker_up   && did=1 || true
(( did == 0 )) && node_build  && did=1 || true
(( did == 0 )) && err "No deployment route matched (no plist, no compose, no Node project)."

# Health check เสมอ (ถ้า dry-run ก็แค่ลองยิง)
health_check || true
log "===== deploy_dashboard done (DRY_RUN=$DRY_RUN) ====="
$LUKA_HOME/tools/smoke_dashboard.zsh || echo "WARN: health check failed"
