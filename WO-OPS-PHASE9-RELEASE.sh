#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 02LUKA • Phase 9.0 Release Bundle
# One-shot: build, verify, tag, archive, publish summary
# Usage: ./WO-OPS-PHASE9-RELEASE.sh [--no-build] [--no-worker] [--no-kim]
# Environment (optional):
#   REDIS_URL=redis://localhost:6379
#   KIM_OUT_CH=kim:out
#   KIM_CHAT_ID=IC
#   BRIDGE_TOKEN=...  (normally in .env)
# ==============================================================================

ROOT="$(pwd)"
TS_UTC="$(date -u +%Y%m%dT%H%M%SZ)"
TAG="PHASE9_${TS_UTC}"
REL_DIR="$ROOT/g/releases"
REL_NAME="phase9_${TS_UTC}"
REL_PATH="$REL_DIR/${REL_NAME}.tgz"

NO_BUILD=0
NO_WORKER=0
NO_KIM=0

for a in "$@"; do
  case "$a" in
    --no-build)  NO_BUILD=1 ;;
    --no-worker) NO_WORKER=1 ;;
    --no-kim)    NO_KIM=1 ;;
    *) echo "Unknown arg: $a" >&2; exit 2 ;;
  esac
done

say() { printf '%s %s\n' ">>> " "$*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# Preflight
# ------------------------------------------------------------------------------
say "Preflight checks"
command -v docker >/dev/null || fail "docker not found"
command -v jq >/dev/null || fail "jq not found"
test -f .env || fail ".env not found. Run your bootstrap first."
source .env

REDIS_URL="${REDIS_URL:-redis://localhost:6379}"
KIM_OUT_CH="${KIM_OUT_CH:-kim:out}"
KIM_CHAT_ID="${KIM_CHAT_ID:-IC}"
OPS_DOMAIN="${OPS_DOMAIN:-ops.theedges.work}"

mkdir -p "$REL_DIR" g/logs g/reports g/state g/metrics

# Optional: ensure git working tree is clean (warn only)
if ! git diff --quiet || ! git diff --cached --quiet; then
  say "Git working tree not clean. Proceeding anyway (release will tag current state)."
fi

# ------------------------------------------------------------------------------
# Build & Up
# ------------------------------------------------------------------------------
if [[ "$NO_BUILD" -eq 0 ]]; then
  say "Bringing stack up (build + up -d)"
  docker compose up -d --build
else
  say "Skipping build (per --no-build). Ensuring services are up"
  docker compose up -d
fi

say "Waiting for bridge to come up (http://127.0.0.1:8788/ping)"
# 30s wait with token if present
BRIDGE_TOKEN_HEADER=""
if [[ -n "${BRIDGE_TOKEN:-}" ]]; then
  BRIDGE_TOKEN_HEADER="-H x-auth-token:${BRIDGE_TOKEN}"
fi

ATTEMPTS=30
until curl -sf $BRIDGE_TOKEN_HEADER http://127.0.0.1:8788/ping >/dev/null || [[ $ATTEMPTS -eq 0 ]]; do
  sleep 1; ATTEMPTS=$((ATTEMPTS-1))
done
[[ $ATTEMPTS -gt 0 ]] || fail "Bridge did not become healthy on port 8788"

# ------------------------------------------------------------------------------
# Verify (writes state + summary)
# ------------------------------------------------------------------------------
say "Running full ops verification"
if ! make verify-ops >/dev/null 2>&1; then
  say "Verifier returned non-zero. Capturing output for diagnosis."
  make verify-ops || true
fi

STATUS_JSON="g/state/ops_verify_status.json"
[[ -f "$STATUS_JSON" ]] || fail "Verifier status JSON not found at $STATUS_JSON"

PASS="$(jq -r '.pass // false' "$STATUS_JSON")"
SUMMARY="$(jq -r '.summary // "OPS VERIFY: no summary"' "$STATUS_JSON")"

say "Verification summary:"
echo "$SUMMARY"

# ------------------------------------------------------------------------------
# Tag Release
# ------------------------------------------------------------------------------
say "Tagging repository with ${TAG}"
# If tag exists, append _A, _B, ...
TAG_CAND="$TAG"; N=0
while git rev-parse "$TAG_CAND" >/dev/null 2>&1; do
  N=$((N+1))
  TAG_CAND="${TAG}_${N}"
done
TAG="$TAG_CAND"
git tag -a "$TAG" -m "02LUKA Phase 9.0 Release ${TS_UTC} • ${SUMMARY}" || say "Tagging failed (continuing)"
# Pushing tags is optional; uncomment if desired:
# git push --tags || say "Tag push failed (continuing)"

# ------------------------------------------------------------------------------
# Optional: deploy Worker
# ------------------------------------------------------------------------------
if [[ "$NO_WORKER" -eq 0 ]]; then
  if command -v wrangler >/dev/null && [[ -d "$HOME/ops-02luka-worker" ]]; then
    say "Deploying Cloudflare Worker (ops UI)"
    (cd "$HOME/ops-02luka-worker" && wrangler deploy) || say "Worker deploy failed (continuing)"
  else
    say "Wrangler or worker directory not found. Skipping Worker deploy."
  fi
else
  say "Skipping Worker deploy (--no-worker)."
fi

# ------------------------------------------------------------------------------
# Publish summary to Kim (optional)
# ------------------------------------------------------------------------------
if [[ "$NO_KIM" -eq 0 ]]; then
  if command -v redis-cli >/dev/null 2>&1; then
    say "Publishing verify summary to Kim on ${KIM_OUT_CH}"
    # Safe single-line text
    MSG="$SUMMARY"
    PAYLOAD="$(jq -nc --arg id "$KIM_CHAT_ID" --arg t "$MSG" '{chat_id:$id, text:$t}')"
    redis-cli -u "$REDIS_URL" PUBLISH "$KIM_OUT_CH" "$PAYLOAD" >/dev/null || say "Kim publish failed (continuing)"
  else
    say "redis-cli not found. Skipping Kim publish."
  fi
else
  say "Skipping Kim publish (--no-kim)."
fi

# ------------------------------------------------------------------------------
# Release Notes & Archive
# ------------------------------------------------------------------------------
say "Writing release notes"
REL_NOTES="$REL_DIR/${REL_NAME}_NOTES.md"
{
  echo "# 02LUKA • Phase 9.0 Release"
  echo "Timestamp (UTC): $TS_UTC"
  echo "Git Tag: $TAG"
  echo
  echo "## Verify Summary"
  echo "$SUMMARY"
  echo
  echo "## Flags"
  echo "- CFG_EDIT=${CFG_EDIT:-off}"
  echo "- ALLOW_SECRET_EDITS=${ALLOW_SECRET_EDITS:-off}"
  echo "- OPS_DIGEST=${OPS_DIGEST:-on}"
  echo "- OPS_CORRELATE_MODE=${OPS_CORRELATE_MODE:-shadow}"
  echo "- PREDICTIVE_MODE=${PREDICTIVE_MODE:-shadow}"
  echo "- FEDERATION_MODE=${FEDERATION_MODE:-readonly}"
  echo "- AUTO_MODE=${AUTO_MODE:-off}"
  echo
  echo "## Key Files"
  echo "- g/state/ops_verify_status.json"
  echo "- g/metrics/ops_health.json"
  echo "- g/logs/*"
  echo "- g/reports/*"
  echo
  echo "## Endpoints"
  echo "- Local Bridge: http://127.0.0.1:8788"
  echo "- Worker (if deployed): https://${OPS_DOMAIN}/"
  echo
  echo "## Rollback"
  echo "1) git checkout <previous-tag>"
  echo "2) docker compose up -d --build"
  echo "3) make verify-ops"
} > "$REL_NOTES"

say "Archiving logs/reports/state to $REL_PATH"
tar -czf "$REL_PATH" \
  g/state \
  g/logs \
  g/reports \
  g/metrics \
  "$REL_NOTES" || fail "Archive failed"

# ------------------------------------------------------------------------------
# Final Output
# ------------------------------------------------------------------------------
echo
echo "======================================================================="
echo "Release completed"
echo "- Tag:            $TAG"
echo "- Summary:        $SUMMARY"
echo "- Release notes:  $REL_NOTES"
echo "- Archive:        $REL_PATH"
echo
echo "Next steps:"
echo "1) Inspect: make show-verify"
echo "2) Optional: make auto-advice   (enable supervised autonomy)"
echo "3) Optional: make auto-auto     (enable autonomous intents)"
echo "4) Open UI:  https://${OPS_DOMAIN}/"
echo "======================================================================="
echo

# Non-zero exit on verify failure to be CI-friendly
if [[ "$PASS" != "true" ]]; then
  exit 1
fi
