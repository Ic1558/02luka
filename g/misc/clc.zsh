#!/usr/bin/env zsh
# clc.zsh — Local CLC Controller (tmux-based)
# Version-controlled unified CLI for starting, stopping, and monitoring CLC locally
set -euo pipefail

# --- Configuration (override via env vars) ---
SESSION="${CLC_SESSION:-CLC}"
REPO="${CLC_REPO:-$HOME/LocalProjects/02luka_local_g/g}"
LOG="${CLC_LOG:-$HOME/02luka/logs/clc_local.log}"
CMD_DEFAULT="${CLC_CMD:-happy start-session}"
HEALTH_URL="${CLC_HEALTH_URL:-http://localhost:4000/ping}"

# --- Helpers ---
err(){ print -u2 "[ERR] $*"; }
ok(){ print "[OK]  $*"; }
info(){ print "[..] $*"; }

need() {
  command -v "$1" >/dev/null 2>&1 || {
    err "$1 not found - install it first"
    exit 127
  }
}

ensure_tmux(){
  need tmux
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    ok "creating tmux session: $SESSION"
    tmux new-session -d -s "$SESSION" -c "$REPO" "echo '[CLC] session created at $(date)'; zsh -i"
  fi
}

start(){
  ensure_tmux
  local CMD="${1:-$CMD_DEFAULT}"
  ok "starting CLC with: $CMD"
  tmux send-keys -t "$SESSION" C-c "cd '$REPO' && { $CMD } 2>&1 | tee -a '$LOG'" Enter
  sleep 0.3
  status
}

stop(){
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    ok "stopping CLC (Ctrl-C)"
    tmux send-keys -t "$SESSION" C-c
  else
    info "tmux session not found: $SESSION"
  fi
}

restart(){
  stop
  sleep 0.5
  start "$@"
}

attach(){
  ensure_tmux
  exec tmux attach -t "$SESSION"
}

logs(){
  touch "$LOG"
  exec tail -n 200 -f "$LOG"
}

_health(){
  if command -v curl >/dev/null 2>&1; then
    if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
      ok "health_server OK: $HEALTH_URL"
    else
      err "health_server down: $HEALTH_URL"
    fi
  else
    info "curl not installed; skipping health check"
  fi
}

status(){
  print "=== CLC Local Status ==="
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    ok "tmux session: $SESSION (running)"
  else
    err "tmux session: $SESSION (not running)"
  fi
  _health
  if command -v docker >/dev/null 2>&1; then
    print "\nContainers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tail -n +2 || print "  (none running)"
  fi
  print "\nLog: $LOG"
  print "Repo: $REPO"
}

usage(){
  cat <<'USAGE'
clc.zsh — Local CLC Controller (tmux-based)

Usage:
  clc start [command]   # start with optional custom command
  clc stop              # send Ctrl-C to tmux session
  clc restart [command] # stop + start
  clc status            # show session, health, containers
  clc attach            # attach to tmux session (Ctrl-B D to detach)
  clc logs              # tail -f the CLC log

Environment Variables (optional overrides):
  CLC_SESSION    tmux session name (default: CLC)
  CLC_REPO       repository path (default: ~/LocalProjects/02luka_local_g/g)
  CLC_LOG        log file path (default: ~/02luka/logs/clc_local.log)
  CLC_CMD        start command (default: happy start-session)
  CLC_HEALTH_URL health check URL (default: http://localhost:4000/ping)

Examples:
  clc start                              # start with default (happy start-session)
  clc start "claude start-session"       # start with custom command
  CLC_CMD="node server.js" clc start     # override default command via env
  clc attach                             # attach to session (interactive)
  clc logs                               # watch logs in real-time

Mobile Control (via Tailscale + SSH):
  ssh mac-mini "~/bin/clc.zsh status"
  ssh mac-mini "~/bin/clc.zsh restart"
USAGE
}

# --- Main ---
cmd="${1:-usage}"; shift || true
case "$cmd" in
  start)   start "$@" ;;
  stop)    stop ;;
  restart) restart "$@" ;;
  status)  status ;;
  attach)  attach ;;
  logs)    logs ;;
  *)       usage; exit 2 ;;
esac
