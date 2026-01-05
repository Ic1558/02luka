#!/usr/bin/env zsh
set -euo pipefail

# ATG Invariants (P0) — Detect "execution chain" health
# SAFE by design: read-only checks + clear PASS/FAIL

REPO_ROOT="${HOME}/02luka"
NOW="$(date +%Y-%m-%dT%H:%M:%S%z)"
UID_NOW="$(id -u)"

# Known patterns from your process list (adjust if you rename tools)
PAT_ANTIGRAVITY_APP='/Applications/Antigravity\.app/Contents/MacOS/(Electron|Antigravity)'
PAT_CODEX_APPSERVER='codex app-server'
PAT_ATG_PROXY='antigravity-claude-proxy'
PAT_LSP_ANTIGRAVITY='language_server_macos_arm'
PAT_LSP_PYREFLY='pyrefly lsp'

# Ports (based on your ports_check output)
PROXY_PORT_DEFAULT="8080"

# ---------- helpers ----------
_log() { print -- "$*"; }
_ok()  { print -- "PASS: $*"; }
_warn(){ print -- "WARN: $*"; }
_fail(){ print -- "FAIL: $*"; return 1; }

_count_procs() {
  local pat="$1"
  pgrep -fl "$pat" 2>/dev/null | grep -v "grep" | grep -v "while read pid cmd" | wc -l | tr -d ' '
}

_list_procs() {
  local pat="$1"
  pgrep -fl "$pat" 2>/dev/null || true
}

_has_port_listener() {
  local port="$1"
  # lsof is best-effort; if missing, we treat as unknown (WARN)
  if ! command -v lsof >/dev/null 2>&1; then
    return 2
  fi
  lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

_section() {
  _log ""
  _log "== $* =="
}

# ---------- checks ----------
check_antigravity_running() {
  _section "Antigravity App"
  local n="$(_count_procs "$PAT_ANTIGRAVITY_APP")"
  if [[ "$n" -ge 1 ]]; then
    _ok "Antigravity running ($n)"
    return 0
  fi
  _warn "Antigravity app not detected (ok if you only want LAC/CLI; but IDE won't auto-respawn extensions)"
  return 0
}

check_codex_appserver() {
  _section "Codex app-server"
  local n="$(_count_procs "$PAT_CODEX_APPSERVER")"
  if [[ "$n" -eq 1 ]]; then
    _ok "codex app-server running"
    return 0
  elif [[ "$n" -gt 1 ]]; then
    _warn "codex app-server appears multiple times ($n) — possible stuck/duplicate"
    _list_procs "$PAT_CODEX_APPSERVER"
    return 1
  else
    _warn "codex app-server missing (may be demand-started). If commands still fail, trigger extension then re-run invariants."
    return 0
  fi
}

check_atg_proxy() {
  _section "Antigravity proxy"
  local n="$(_count_procs "$PAT_ATG_PROXY")"
  if [[ "$n" -eq 1 ]]; then
    _ok "proxy running"
  elif [[ "$n" -gt 1 ]]; then
    _warn "proxy appears multiple times ($n) — possible stuck/duplicate"
    _list_procs "$PAT_ATG_PROXY"
    return 1
  else
    _fail "proxy missing"
  fi

  # Port check (best-effort)
  if _has_port_listener "$PROXY_PORT_DEFAULT"; then
    _ok "proxy port listening :$PROXY_PORT_DEFAULT"
    return 0
  else
    local rc=$?
    if [[ "$rc" -eq 2 ]]; then
      _warn "lsof not available — cannot verify port :$PROXY_PORT_DEFAULT"
      return 0
    fi
    _warn "proxy port not listening on :$PROXY_PORT_DEFAULT (may be moved; verify ports_check output)"
    return 1
  fi
}

check_lsp_chain() {
  _section "LSP chain"
  local n1="$(_count_procs "$PAT_LSP_ANTIGRAVITY")"
  local n2="$(_count_procs "$PAT_LSP_PYREFLY")"

  if [[ "$n1" -ge 1 ]]; then
    _ok "antigravity language server running ($n1)"
  else
    _warn "antigravity language server not detected (may be idle/off)"
  fi

  if [[ "$n2" -ge 1 ]]; then
    _ok "pyrefly lsp running ($n2)"
  else
    _warn "pyrefly lsp not detected (may be idle/off)"
  fi

  # Not a hard fail because LSP can be lazily started
  return 0
}

check_recent_errors_hint() {
  _section "Hints (best-effort)"
  # If you later standardize logs, wire here.
  # For now: nothing destructive.
  _ok "no log-based invariant wired (P0)"
  return 0
}

main() {
  _log "ATG_INVARIANTS P0 — ${NOW}"
  _log "repo=${REPO_ROOT}"

  local failed=0

  check_antigravity_running || true
  check_codex_appserver || ((failed++))
  check_atg_proxy || ((failed++))
  check_lsp_chain || true
  check_recent_errors_hint || true

  _log ""
  if [[ "$failed" -eq 0 ]]; then
    _log "✅ All ATG invariants PASS"
    return 0
  else
    _log "❌ ATG invariants FAIL count=$failed"
    return 1
  fi
}

main "$@"
