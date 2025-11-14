#!/usr/bin/env zsh
set -euo pipefail

ROOT="${HOME}/02luka"
cd "$ROOT"

stamp() { date +"%Y-%m-%d %H:%M:%S"; }
log() { printf '[%s] %s\n' "$(stamp)" "$*"; }

log "Phase 2.5–2.6 installer starting"

# --- directories -----------------------------------------------------------
mkdir -p bridge/inbox/{ENTRY,CLC,shell} bridge/outbox/{ENTRY,CLC,shell}
mkdir -p logs/wo_drop_history tools/watchers LaunchAgents

# --- WO Router guard -------------------------------------------------------
if ! grep -q 'wo_make_yaml' tools/cls/cls_slash.zsh 2>/dev/null; then
  log "Existing CLS router missing wo_make_yaml stub; installing fallback"
  cat <<'ZSH' > tools/cls/cls_slash.zsh
#!/usr/bin/env zsh
set -euo pipefail
ROOT="$HOME/02luka"
CMD="${1:-}"; shift || true
BRIEF="${*:-}"
[[ -n "$CMD" ]] || { echo "usage: cls /do|/clc|/local|/mary [brief]" >&2; exit 1; }

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

wo_make_yaml() {
  local intent="$1" summary="$2" candidates="$3" strict="$4" artifact_type="$5" artifact_path="$6"
  local id="WO-$(date +%y%m%d-%H%M%S)-auto"
  cat <<YAML
id: ${id}
intent: ${intent}
summary: ${summary}
priority: normal
target_candidates: ${candidates}
strict_target: ${strict}
route_hints: [clc, shell]
notify:
  telegram: true
  level: normal
return_channel: shell:response:shell
artifacts:
  - type: ${artifact_type}
    path: ${artifact_path}
YAML
}

wo_atomic_drop() {
  local inbox="$1"; shift
  local hist="$ROOT/logs/wo_drop_history"
  mkdir -p "$inbox" "$hist"
  local tmp="$(mktemp -t WO_XXXX).yaml"
  cat > "$tmp"
  local dst="$inbox/$(grep '^id:' "$tmp" | awk '{print $2}').yaml"
  mv "$tmp" "$dst"
  cp "$dst" "$hist/" 2>/dev/null || true
  echo "dropped: $dst"
}

case "$CMD" in
  /do)
    wo_make_yaml "plan" "${BRIEF:-Task}" "[clc, shell]" "false" "plan_md" "g/wo/plan.md" | \
      wo_atomic_drop "$ROOT/bridge/inbox/ENTRY"
    ;;
  /clc)
    wo_make_yaml "apply_sip_patch" "${BRIEF:-CLC Task}" "[clc]" "true" "sip_patch" "g/wo/patch.md" | \
      wo_atomic_drop "$ROOT/bridge/inbox/CLC"
    ;;
  /local)
    wo_make_yaml "run_shell" "${BRIEF:-Shell}" "[shell]" "true" "shell_script" "g/wo/run.zsh" | \
      wo_atomic_drop "$ROOT/bridge/inbox/shell"
    ;;
  /mary)
    wo_make_yaml "plan" "${BRIEF:-Mary Dispatch}" "[clc, shell]" "false" "plan_md" "g/wo/plan.md" | \
      wo_atomic_drop "$ROOT/bridge/inbox/ENTRY"
    ;;
  *) echo "unknown command: $CMD" >&2; exit 1 ;;
esac
ZSH
  chmod +x tools/cls/cls_slash.zsh
else
  log "Existing CLS router already defines wo_make_yaml — leaving intact"
fi

# --- Mary dispatcher -------------------------------------------------------
cat <<'ZSH' > tools/watchers/mary_dispatcher.zsh
#!/usr/bin/env zsh
set -euo pipefail
setopt null_glob

ROOT="${HOME}/02luka"
INBOX="$ROOT/bridge/inbox/ENTRY"
OUTBOX="$ROOT/bridge/outbox/ENTRY"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/mary_dispatcher.log"

mkdir -p "$INBOX" "$OUTBOX" "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE"
}

log "start mary_dispatcher"

for file in "$INBOX"/*.yaml; do
  [[ -f "$file" ]] || continue
  id="${${file:t}%.*}"

  dest="CLC"
  if grep -q '^strict_target: *true' "$file" 2>/dev/null; then
    if grep -q 'target_candidates: *\[ *shell *\]' "$file" 2>/dev/null; then
      dest="shell"
    else
      dest="CLC"
    fi
  fi

  mkdir -p "$ROOT/bridge/inbox/$dest" "$ROOT/bridge/outbox/$dest"
  tmp="$ROOT/bridge/inbox/$dest/.mary_${id}.$$"
  cp "$file" "$tmp"
  mv "$tmp" "$ROOT/bridge/inbox/$dest/${id}.yaml"
  mv "$file" "$OUTBOX/${id}.yaml"
  log "$id -> $dest"
done
ZSH
chmod +x tools/watchers/mary_dispatcher.zsh

# --- Shell watcher ---------------------------------------------------------
cat <<'ZSH' > tools/watchers/shell_watcher.zsh
#!/usr/bin/env zsh
set -euo pipefail
setopt null_glob

ROOT="${HOME}/02luka"
INBOX="$ROOT/bridge/inbox/shell"
OUTBOX="$ROOT/bridge/outbox/shell"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/shell_watcher.log"

mkdir -p "$INBOX" "$OUTBOX" "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE"
}

redis_publish() {
  local payload="$1"
  if ! command -v redis-cli >/dev/null 2>&1; then
    return 127
  fi
  local host="${REDIS_HOST:-127.0.0.1}"
  local port="${REDIS_PORT:-6379}"
  local password="${REDIS_PASS:-}"
  if [[ -n "$password" ]]; then
    redis-cli -h "$host" -p "$port" -a "$password" PUBLISH shell "$payload" >/dev/null
  else
    redis-cli -h "$host" -p "$port" PUBLISH shell "$payload" >/dev/null
  fi
}

log "start shell_watcher"

for file in "$INBOX"/*.yaml; do
  [[ -f "$file" ]] || continue
  id="${${file:t}%.*}"
  body=$(base64 "$file" | tr -d '\n')
  message="{\"task_id\":\"$id\",\"agent\":\"shell\",\"kind\":\"yaml\",\"body_base64\":\"$body\"}"

  if redis_publish "$message"; then
    log "published $id to redis channel shell"
  else
    log "WARN redis publish failed for $id; using file queue"
  fi

  mv "$file" "$OUTBOX/${id}.yaml"
done
ZSH
chmod +x tools/watchers/shell_watcher.zsh

# --- CLC bridge ------------------------------------------------------------
cat <<'ZSH' > tools/watchers/clc_bridge.zsh
#!/usr/bin/env zsh
set -euo pipefail
setopt null_glob

ROOT="${HOME}/02luka"
INBOX="$ROOT/bridge/inbox/CLC"
OUTBOX="$ROOT/bridge/outbox/CLC"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/clc_bridge.log"

mkdir -p "$INBOX" "$OUTBOX" "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE"
}

log "start clc_bridge"

for file in "$INBOX"/*.yaml; do
  [[ -f "$file" ]] || continue
  id="${${file:t}%.*}"
  norm="$INBOX/${id}.yaml"
  if [[ "$file" != "$norm" ]]; then
    mv "$file" "$norm"
    log "normalized $id"
  else
    log "already normalized $id"
  fi
  cp "$norm" "$OUTBOX/${id}.yaml"
done
ZSH
chmod +x tools/watchers/clc_bridge.zsh

# --- LaunchAgents ----------------------------------------------------------
cat <<'PLIST' > LaunchAgents/com.02luka.mary-dispatch.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.02luka.mary-dispatch</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/zsh</string>
      <string>-lc</string>
      <string>${HOME}/02luka/tools/watchers/mary_dispatcher.zsh</string>
    </array>
    <key>StartInterval</key>
    <integer>20</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/mary-dispatch.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/mary-dispatch.err</string>
  </dict>
</plist>
PLIST

cat <<'PLIST' > LaunchAgents/com.02luka.shell-watcher.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.02luka.shell-watcher</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/zsh</string>
      <string>-lc</string>
      <string>${HOME}/02luka/tools/watchers/shell_watcher.zsh</string>
    </array>
    <key>StartInterval</key>
    <integer>20</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/shell-watcher.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/shell-watcher.err</string>
  </dict>
</plist>
PLIST

cat <<'PLIST' > LaunchAgents/com.02luka.clc-bridge.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.02luka.clc-bridge</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/zsh</string>
      <string>-lc</string>
      <string>${HOME}/02luka/tools/watchers/clc_bridge.zsh</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/clc-bridge.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/clc-bridge.err</string>
  </dict>
</plist>
PLIST

# --- README block ----------------------------------------------------------
if [[ -f README.md ]]; then
  if grep -q '<!-- router:start -->' README.md; then
    perl -0pi -e 's/<!-- router:start -->.*?<!-- router:end -->/<!-- router:start -->\n## WO Router + Dispatch (Phase 2.5–2.6)\n- `\/do` → ENTRY → Mary dispatcher → CLC (fallback shell)\n- `\/clc` → CLC inbox (ready for SIP patches)\n- `\/local` → shell inbox (Redis `shell` channel)\n- Logs: `logs\/wo_drop_history\/history.log`\n<!-- router:end -->/s' README.md
  else
    cat <<'MD' >> README.md

<!-- router:start -->
## WO Router + Dispatch (Phase 2.5–2.6)
- `/do` → ENTRY → Mary dispatcher → CLC (fallback shell)
- `/clc` → CLC inbox (ready for SIP patches)
- `/local` → shell inbox (Redis `shell` channel)
- Logs: `logs/wo_drop_history/history.log`
<!-- router:end -->
MD
  fi
fi

# --- Launchctl reload (if available) --------------------------------------
if command -v launchctl >/dev/null 2>&1; then
  log "Reloading LaunchAgents"
  launchctl unload "$HOME/Library/LaunchAgents/com.02luka.mary-dispatch.plist" 2>/dev/null || true
  launchctl unload "$HOME/Library/LaunchAgents/com.02luka.shell-watcher.plist" 2>/dev/null || true
  launchctl unload "$HOME/Library/LaunchAgents/com.02luka.clc-bridge.plist" 2>/dev/null || true
  mkdir -p "$HOME/Library/LaunchAgents"
  cp LaunchAgents/com.02luka.mary-dispatch.plist "$HOME/Library/LaunchAgents/"
  cp LaunchAgents/com.02luka.shell-watcher.plist "$HOME/Library/LaunchAgents/"
  cp LaunchAgents/com.02luka.clc-bridge.plist "$HOME/Library/LaunchAgents/"
  launchctl load "$HOME/Library/LaunchAgents/com.02luka.mary-dispatch.plist"
  launchctl load "$HOME/Library/LaunchAgents/com.02luka.shell-watcher.plist"
  launchctl load "$HOME/Library/LaunchAgents/com.02luka.clc-bridge.plist"
else
  log "launchctl not detected; skipped agent reload"
fi

# --- git snapshot ----------------------------------------------------------
git add README.md tools/cls/cls_slash.zsh tools/watchers/*.zsh LaunchAgents/com.02luka.*.plist bridge logs/wo_drop_history 2>/dev/null || true
if git diff --cached --quiet; then
  log "No staged changes for commit"
else
  git commit -m "feat(phase2.6): install WO router dispatch pack" || true
fi

log "Installer complete"
log "Examples:"
log "  tools/cls/cls_slash.zsh /do 'Ping end-to-end'"
log "  tools/cls/cls_slash.zsh /clc 'Apply SIP patch'"
log "  tools/cls/cls_slash.zsh /local 'uname -a'"

log "Rollback:"
log "  rm -f tools/watchers/{mary_dispatcher,shell_watcher,clc_bridge}.zsh"
log "  git restore README.md LaunchAgents tools/watchers"
