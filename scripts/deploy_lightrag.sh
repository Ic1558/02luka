#!/usr/bin/env bash
set -euo pipefail

say() {
  printf '\033[1m[%s]\033[0m %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    die "Environment variable $name is required."
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="${LIGHTRAG_HOME:-$HOME/02luka/services/lightrag}"
REPO_URL="${LIGHTRAG_REPO_URL:-https://github.com/HKUDS/LightRAG.git}"
PORT="${LIGHTRAG_PORT:-9621}"
STORAGE_DIR="${LIGHTRAG_STORAGE_DIR:-$TARGET_DIR/data/rag_storage}"
INPUT_DIR="${LIGHTRAG_INPUT_DIR:-$TARGET_DIR/data/inputs}"
CONFIG_PATH="$TARGET_DIR/config.ini"
ENV_FILE="$TARGET_DIR/.env"

say "Checking prerequisites"
command -v git >/dev/null 2>&1 || die "git is required"
command -v docker >/dev/null 2>&1 || die "docker is required"

COMPOSE_BIN=()
if docker compose version >/dev/null 2>&1; then
  COMPOSE_BIN=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_BIN=(docker-compose)
else
  die "docker compose plugin or docker-compose binary is required"
fi

mkdir -p "$TARGET_DIR"

if [ ! -d "$TARGET_DIR/.git" ]; then
  say "Cloning LightRAG into $TARGET_DIR"
  git clone --depth=1 "$REPO_URL" "$TARGET_DIR"
else
  say "Updating LightRAG repository"
  git -C "$TARGET_DIR" fetch --tags --prune
  git -C "$TARGET_DIR" pull --ff-only
fi

if [ -n "${LIGHTRAG_REF:-}" ]; then
  say "Checking out $LIGHTRAG_REF"
  git -C "$TARGET_DIR" checkout "$LIGHTRAG_REF"
fi

mkdir -p "$STORAGE_DIR" "$INPUT_DIR" "$TARGET_DIR/data"

if [ ! -f "$CONFIG_PATH" ]; then
  say "Creating default config.ini"
  cp "$TARGET_DIR/config.ini.example" "$CONFIG_PATH"
fi

if [ -f "$ENV_FILE" ] && [ "${LIGHTRAG_FORCE_ENV:-0}" != "1" ]; then
  say "Preserving existing .env (set LIGHTRAG_FORCE_ENV=1 to overwrite)"
else
  say "Writing LightRAG .env"
  require_env LIGHTRAG_LLM_HOST
  require_env LIGHTRAG_LLM_API_KEY

  local_llm_binding="${LIGHTRAG_LLM_BINDING:-openai}"
  local_llm_model="${LIGHTRAG_LLM_MODEL:-gpt-4o}"
  local_embedding_binding="${LIGHTRAG_EMBEDDING_BINDING:-$local_llm_binding}"
  local_embedding_model="${LIGHTRAG_EMBEDDING_MODEL:-text-embedding-3-large}"
  local_embedding_host="${LIGHTRAG_EMBEDDING_HOST:-$LIGHTRAG_LLM_HOST}"
  local_embedding_key="${LIGHTRAG_EMBEDDING_API_KEY:-$LIGHTRAG_LLM_API_KEY}"

  cat >"$ENV_FILE" <<EOF
HOST=0.0.0.0
PORT=$PORT
WORKING_DIR=$STORAGE_DIR
INPUT_DIR=$INPUT_DIR
LLM_BINDING=$local_llm_binding
LLM_MODEL=$local_llm_model
LLM_BINDING_HOST=$LIGHTRAG_LLM_HOST
LLM_BINDING_API_KEY=$LIGHTRAG_LLM_API_KEY
EMBEDDING_BINDING=$local_embedding_binding
EMBEDDING_MODEL=$local_embedding_model
EMBEDDING_BINDING_HOST=$local_embedding_host
EMBEDDING_BINDING_API_KEY=$local_embedding_key
ENABLE_LLM_CACHE=${LIGHTRAG_ENABLE_LLM_CACHE:-true}
MAX_ASYNC=${LIGHTRAG_MAX_ASYNC:-4}
MAX_PARALLEL_INSERT=${LIGHTRAG_MAX_PARALLEL_INSERT:-2}
OLLAMA_EMULATING_MODEL_TAG=${LIGHTRAG_OLLAMA_TAG:-latest}
WHITELIST_PATHS=${LIGHTRAG_WHITELIST_PATHS:-/health,/api/*}
EOF

  if [ -n "${LIGHTRAG_AUTH_ACCOUNTS:-}" ]; then
    printf 'AUTH_ACCOUNTS=%s\n' "$LIGHTRAG_AUTH_ACCOUNTS" >>"$ENV_FILE"
  fi

  if [ -n "${LIGHTRAG_API_KEY:-}" ]; then
    printf 'LIGHTRAG_API_KEY=%s\n' "$LIGHTRAG_API_KEY" >>"$ENV_FILE"
  fi

  if [ -n "${LIGHTRAG_TOKEN_SECRET:-}" ]; then
    printf 'TOKEN_SECRET=%s\n' "$LIGHTRAG_TOKEN_SECRET" >>"$ENV_FILE"
  fi

  chmod 600 "$ENV_FILE"
fi

say "Starting LightRAG via docker compose"
(
  cd "$TARGET_DIR"
  "${COMPOSE_BIN[@]}" pull || true
  "${COMPOSE_BIN[@]}" up -d --remove-orphans
)

say "Waiting for LightRAG health endpoint"
HEALTH_OK=0
for attempt in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    HEALTH_OK=1
    break
  fi
  sleep 2
done

if [ "$HEALTH_OK" -eq 1 ]; then
  say "LightRAG is healthy"
else
  say "LightRAG health check failed"
fi

CONTAINER_STATUS="$(docker ps --filter "name=lightrag" --format "{{.ID}} {{.Status}}" | head -n1)"

REPORT_DIR="$REPO_ROOT/g/reports/deploy"
mkdir -p "$REPORT_DIR"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/lightrag_${TIMESTAMP}.md"

cat >"$REPORT_FILE" <<EOF
# LightRAG Deployment Report

**Timestamp:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Target Directory:** $TARGET_DIR
**Port:** $PORT
**Compose Command:** ${COMPOSE_BIN[*]}
**Health Check:** http://127.0.0.1:${PORT}/health
**Health Status:** $([ "$HEALTH_OK" -eq 1 ] && echo "✅ PASS" || echo "⚠️ CHECK")
**Container:** ${CONTAINER_STATUS:-not-found}

## Next Steps
- Update any upstream clients to use the LightRAG endpoint.
- Review $TARGET_DIR/.env for accuracy and rotate credentials regularly.
- Monitor container logs: docker logs -f lightrag

EOF

say "Report written to $REPORT_FILE"

if [ "$HEALTH_OK" -ne 1 ]; then
  exit 2
fi

