#!/usr/bin/env zsh
set -euo pipefail

# ATG Remediation (P0)
# SAFE: restart only execution chain (codex app-server + proxy + LSP).
# HARD: optional (not default) — still avoids touching unrelated 02luka services.

REPO_ROOT="${HOME}/02luka"
MODE="${1:-SAFE}"   # SAFE | HARD
NOW="$(date +%Y-%m-%dT%H:%M:%S%z)"

PAT_CODEX_APPSERVER='codex'
PAT_ATG_PROXY='antigravity-claude-proxy'
PAT_LSP_ANTIGRAVITY='language_server_macos_arm'
PAT_LSP_PYREFLY='pyrefly lsp'
PAT_ATG_HELPER='Antigravity Helper'

LOG_DIR="/tmp"
PROXY_LOG_OUT="${LOG_DIR}/atg_proxy.stdout.log"
PROXY_LOG_ERR="${LOG_DIR}/atg_proxy.stderr.log"

_invariants="${REPO_ROOT}/g/governance/atg_invariants.zsh"

_log() { print -- "$*"; }
_step(){ print -- ""; print -- "== $* =="; }
_run() { _log "+ $*"; eval "$*"; }

_kill_pat() {
  local pat="$1"
  if pgrep -f "$pat" >/dev/null 2>&1; then
    _run "pkill -f ${(q)pat} || true"
  else
    _log "skip: no process match: $pat"
  fi
}

_start_proxy_if_available() {
  # Start only if command exists; otherwise rely on IDE to respawn.
  if command -v antigravity-claude-proxy >/dev/null 2>&1; then
    _step "Start proxy"
    # Ensure old is gone
    _kill_pat "$PAT_ATG_PROXY"
    # Start detached
    _run "nohup antigravity-claude-proxy start > ${(q)PROXY_LOG_OUT} 2> ${(q)PROXY_LOG_ERR} < /dev/null & disown || true"
    return 0
  fi
  _log "WARN: antigravity-claude-proxy binary not found in PATH — will not start; IDE may respawn it"
  return 0
}

_safe_restart_chain() {
  _step "SAFE: Restart execution chain only"

  # Kill likely-stuck pieces. IDE can respawn extensions; proxy we can restart if binary exists.
  _kill_pat "$PAT_CODEX_APPSERVER"
  _kill_pat "$PAT_LSP_PYREFLY"
  _kill_pat "$PAT_LSP_ANTIGRAVITY"

  # Proxy: restart if possible
  _start_proxy_if_available

  _step "Post-check: invariants"
  if [[ -x "$_invariants" ]]; then
    _run "${_invariants} || true"
  else
    _log "WARN: invariants script missing or not executable: $_invariants"
  fi
}

_hard_restart_helper_chain() {
  _step "HARD: Restart Antigravity helper chain (still not touching other 02luka services)"

  # This is still "scoped": only Antigravity's own helpers + extensions.
  _kill_pat "$PAT_CODEX_APPSERVER"
  _kill_pat "$PAT_LSP_PYREFLY"
  _kill_pat "$PAT_LSP_ANTIGRAVITY"
  _kill_pat "$PAT_ATG_HELPER"
  _kill_pat "$PAT_ATG_PROXY"

  # Proxy restart best-effort
  _start_proxy_if_available

  _step "Post-check: invariants"
  if [[ -x "$_invariants" ]]; then
    _run "${_invariants} || true"
  else
    _log "WARN: invariants script missing or not executable: $_invariants"
  fi
}

main() {
  _log "ATG_REMEDIATION P0 — ${NOW}"
  _log "mode=${MODE}"

  case "$MODE" in
    SAFE)
      _safe_restart_chain
      ;;
    HARD)
      _hard_restart_helper_chain
      ;;
    *)
      _log "Usage: atg_remediation.zsh [SAFE|HARD]"
      return 2
      ;;
  esac

  _log ""
  _log "Done."
}

main "$@"
