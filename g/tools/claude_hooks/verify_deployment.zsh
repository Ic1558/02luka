#!/usr/bin/env zsh
# Post-Deployment Verification Hook
# Purpose: Verify deployment success and capture lessons learned
# Usage: Called after deployment completion

set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")}"
ROLLBACK_SCRIPT=""

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

log "🔍 Verifying deployment: $DEPLOYMENT_NAME"

# Check 1: Rollback script presence
if [[ -d "$BASE/tools" ]]; then
  ROLLBACK_SCRIPT=$(find "$BASE/tools" -maxdepth 1 -name "rollback_*.zsh" -type f 2>/dev/null | head -1 || echo "")
  if [[ -n "$ROLLBACK_SCRIPT" ]]; then
    log "✅ Rollback script found: $(basename "$ROLLBACK_SCRIPT")"
  else
    log "⚠️  No rollback script found (recommended but not blocking)"
  fi
fi

# Check 2: Health check availability
if [[ -f "$BASE/tools/system_health_check.zsh" ]] && [[ -x "$BASE/tools/system_health_check.zsh" ]]; then
  log "✅ Health check script available"
  # Run health check (non-blocking)
  {
    set +e
    "$BASE/tools/system_health_check.zsh" >/dev/null 2>&1
    health_rc=$?
    set -e
  } || true
  
  if [[ $health_rc -eq 0 ]]; then
    log "✅ Health check passed"
  else
    log "⚠️  Health check returned non-zero (rc=$health_rc) - review manually"
  fi
else
  log "ℹ️  Health check script not found (optional)"
fi

# Check 3: Deployment artifacts
if [[ -d "$BASE/g/reports" ]]; then
  DEPLOYMENT_CERT=$(find "$BASE/g/reports" -maxdepth 2 -name "DEPLOYMENT_CERTIFICATE_*.md" -type f 2>/dev/null | head -1 || echo "")
  if [[ -n "$DEPLOYMENT_CERT" ]]; then
    log "✅ Deployment certificate found: $(basename "$DEPLOYMENT_CERT")"
  else
    log "ℹ️  No deployment certificate found (optional)"
  fi
fi

log "✅ Deployment verification complete"

# MLS Capture: Record deployment lesson
if [[ -f "$BASE/tools/mls_capture.zsh" ]] && [[ -x "$BASE/tools/mls_capture.zsh" ]]; then
  # Extract deployment summary
  if [[ -n "$ROLLBACK_SCRIPT" ]]; then
    SUMMARY="Deployment completed with rollback script available"
    CONTEXT="Deployment=$DEPLOYMENT_NAME, Rollback=available"
  else
    SUMMARY="Deployment completed (no rollback script)"
    CONTEXT="Deployment=$DEPLOYMENT_NAME, Rollback=none"
  fi
  
  # Capture lesson (wrapped in || true to prevent hook failure)
  "$BASE/tools/mls_capture.zsh" improvement "Deployment: $DEPLOYMENT_NAME" "$SUMMARY" "$CONTEXT" || {
    log "⚠️  MLS capture failed (non-blocking)"
  }
fi

exit 0
