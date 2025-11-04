#!/usr/bin/env zsh
set -euo pipefail

# --- constants
BASE="$HOME/02luka"
TOOLS="$BASE/tools"
CONFIG="$BASE/config"
LOGS="$BASE/logs"
LA="$HOME/Library/LaunchAgents"
mkdir -p "$TOOLS" "$CONFIG" "$LOGS" "$LA"

ME="WO-251105_GPT_ONLY_LANE_AND_KIM"
TS="$(date +%Y%m%d_%H%M%S)"
RUNLOG="$LOGS/${ME}_${TS}.log"
exec > >(tee -a "$RUNLOG") 2>&1
echo "== [$ME] starting at $TS =="

# --- sanity
for bin in redis-cli jq awk sed python3 pip3; do
  command -v "$bin" >/dev/null || { echo "ERROR: missing $bin"; exit 1; }
done
echo "NOTE: expecting Terminalhandler on Redis pubsub channel 'shell'."

# --- 1) whitelist intent map for bridge
MAP="$CONFIG/nlp_command_map.yaml"
cat > "$MAP" <<'YAML'
intents:
  backup.now:
    desc: "Run Google Drive 02luka backup once (fast, selective)"
    cmd:  "$HOME/02luka/tools/backup_to_gdrive.zsh --once"

  sync.expense:
    desc: "Push expense tracker to gd sync path"
    cmd:  "rsync -a --delete $HOME/02luka/g/expense/ $HOME/gd/02luka_sync/current/g/expense/"

  restart.health:
    desc: "Restart health_server service"
    cmd:  "launchctl kickstart -k gui/$(id -u)/com.02luka.health_server || true"

  deploy.dashboard:
    desc: "Deploy static dashboard"
    cmd:  "$HOME/02luka/tools/deploy_dashboard.zsh"

  restart.filebridge:
    desc: "Restart FileBridge"
    cmd:  "launchctl kickstart -k gui/$(id -u)/com.02luka.filebridge"

synonyms:
  "backup now": backup.now
  "สำรองข้อมูลตอนนี้": backup.now
  "expense sync": sync.expense
  "ซิงค์ค่าใช้จ่าย": sync.expense
  "restart health": restart.health
  "รีสตาร์ทเฮลธ์": restart.health
  "deploy dashboard": deploy.dashboard
  "รีลีสดาชบอร์ด": deploy.dashboard
  "restart filebridge": restart.filebridge
  "รีสตาร์ทไฟล์บริดจ์": restart.filebridge
YAML
echo "Wrote $MAP"

# --- 2) bridge: gg:nlp -> shell
BRIDGE="$TOOLS/gg_nlp_bridge.zsh"
cat > "$BRIDGE" <<'ZSH2'
#!/usr/bin/env zsh
set -euo pipefail
BASE="$HOME/02luka"
CONFIG="$BASE/config"
LOGS="$BASE/logs"
MAP="$CONFIG/nlp_command_map.yaml"
LOG="$LOGS/gg_nlp_bridge.$(date +%Y%m%d_%H%M%S).log"
CHANNEL_IN="gg:nlp"
CHANNEL_OUT="shell"
TASK_PREFIX="gg-nlp"
exec > >(tee -a "$LOG") 2>&1
echo "== [gg_nlp_bridge] PID $$ =="

intent_for() {
  local key="$1"
  local intent
  intent="$(awk -v k="$key" '
    /^synonyms:/ {in_syn=1; next}
    /^intents:/ {in_syn=0}
    in_syn && $0 ~ ":" {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if (match($0, /^"?([^"]+)"?[[:space:]]*:[[:space:]]*([a-zA-Z0-9_.-]+)$/, a)) {
        if (a[1]==k) { print a[2]; exit }
      }
    }
  ' "$MAP")"
  [[ -n "$intent" ]] && { echo "$intent"; return 0; }
  echo "$key"
}

cmd_for_intent() {
  local intent="$1"
  awk -v i="$intent" '
    /^intents:/ {in_int=1; next}
    in_int && /^[[:space:]]+[a-zA-Z0-9_.-]+:/ {
      if (match($0, /^[[:space:]]+([a-zA-Z0-9_.-]+):/, b)) { k=b[1] }
    }
    in_int && $0 ~ /^[[:space:]]+cmd:/ {
      if (k==i) {
        sub(/^[[:space:]]+cmd:[[:space:]]*/, "", $0)
        gsub(/^"|"$/, "", $0)
        print $0; exit
      }
    }
  ' "$MAP"
}

publish_shell_task() {
  local cmd="$1"
  local tid="gg-nlp:$(date +%s)-$RANDOM"
  local json
  json="$(jq -n --arg tid "$tid" --arg cmd "$cmd" \
    '{task_id:$tid, type:"shell", cmd:$cmd, timeout_sec:3600 }')"
  echo "Dispatch → shell: $json"
  redis-cli PUBLISH "$CHANNEL_OUT" "$json" >/dev/null
  echo "$tid"
}

echo "Subscribing to $CHANNEL_IN …"
redis-cli --raw SUBSCRIBE "$CHANNEL_IN" | while read -r line; do
  if [[ "$line" == "message" ]]; then
    read -r chan
    read -r payload
    echo "-- incoming on $chan: $payload"
    local key intent cmd tid
    key="$(echo "$payload" | jq -r '(.intent // .text // "")' 2>/dev/null || echo "")"
    [[ -z "$key" || "$key" == "null" ]] && { echo "WARN: no intent/text"; continue; }
    intent="$(intent_for "$key")"
    cmd="$(cmd_for_intent "$intent")"
    [[ -z "$cmd" ]] && { echo "WARN: intent '$intent' not whitelisted"; continue; }
    tid="$(publish_shell_task "$cmd")"
    echo "ACK: intent '$intent' → task_id=$tid"
  fi
done
ZSH2
chmod +x "$BRIDGE"

# --- 3) LaunchAgent for bridge
PL_BRIDGE="$LA/com.02luka.gg.nlp-bridge.plist"
cat > "$PL_BRIDGE" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.02luka.gg.nlp-bridge</string>
  <key>ProgramArguments</key><array><string>$BRIDGE</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$LOGS/gg_nlp_bridge.stdout.log</string>
  <key>StandardErrorPath</key><string>$LOGS/gg_nlp_bridge.stderr.log</string>
  <key>ProcessType</key><string>Interactive</string>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>LC_ALL</key><string>C</string>
  </dict>
</dict></plist>
PL
launchctl unload "$PL_BRIDGE" >/dev/null 2>&1 || true
launchctl load  "$PL_BRIDGE"
echo "LaunchAgent loaded: com.02luka.gg.nlp-bridge"

# --- 4) Kim bot (long-polling → gg:nlp)
KDIR="$BASE/agents/kim_bot"
VENV="$BASE/venv/kim_bot"
mkdir -p "$KDIR" "$(dirname "$VENV")"
python3 -m venv "$VENV"
source "$VENV/bin/activate"
python -m pip install --upgrade pip >/dev/null
pip install "python-telegram-bot==21.6" "redis==5.0.1" >/dev/null

ENVF="$CONFIG/kim.env"
cat > "$ENVF" <<'ENV'
TELEGRAM_BOT_TOKEN=REPLACE_ME
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=gggclukaic
REDIS_CHANNEL_IN=gg:nlp
ENV
# inject real token (from user)
sed -i '' 's|TELEGRAM_BOT_TOKEN=REPLACE_ME|TELEGRAM_BOT_TOKEN=8412723056:AAHWPvOauQ4QHoz3v0mUM1ZCI2hWJc4uGcU|' "$ENVF"

cat > "$KDIR/kim_telegram_bot.py" <<'PY'
import os, sys, json, logging
from redis import Redis
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

TOKEN = os.getenv("TELEGRAM_BOT_TOKEN","")
R = Redis(
    host=os.getenv("REDIS_HOST","127.0.0.1"),
    port=int(os.getenv("REDIS_PORT","6379")),
    password=os.getenv("REDIS_PASSWORD") or None,
    decode_responses=True,
)
CHAN = os.getenv("REDIS_CHANNEL_IN","gg:nlp")

if not TOKEN:
    print("ERROR: TELEGRAM_BOT_TOKEN missing", file=sys.stderr); sys.exit(1)

logging.basicConfig(format="%(asctime)s [kim-bot] %(levelname)s: %(message)s", level=logging.INFO)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("Kim online ✅  Send an intent (e.g., 'backup now').")

async def to_nlp(update: Update, context: ContextTypes.DEFAULT_TYPE):
    txt = (update.message.text or "").strip()
    if not txt: return
    payload = json.dumps({"text": txt})
    try:
        R.publish(CHAN, payload)
        logging.info("PUB → %s : %s", CHAN, payload)
        await update.message.reply_text(f"ACK → {CHAN}")
    except Exception:
        logging.exception("Redis publish failed")
        await update.message.reply_text("ERR: cannot reach NLP bridge")

def main():
    app = Application.builder().token(TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, to_nlp))
    app.run_polling(close_loop=False)

if __name__ == "__main__":
    main()
PY

cat > "$KDIR/run.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
BASE="$HOME/02luka"
source "$BASE/venv/kim_bot/bin/activate"
export $(grep -v '^\s*#' "$BASE/config/kim.env" | xargs -I{} echo {})
exec python "$BASE/agents/kim_bot/kim_telegram_bot.py"
SH
chmod +x "$KDIR/run.sh"

PL_KIM="$LA/com.02luka.kim.bot.plist"
cat > "$PL_KIM" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.02luka.kim.bot</string>
  <key>ProgramArguments</key><array><string>$KDIR/run.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$LOGS/kim_bot.stdout.log</string>
  <key>StandardErrorPath</key><string>$LOGS/kim_bot.stderr.log</string>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
</dict></plist>
PL

launchctl unload "$PL_KIM" >/dev/null 2>&1 || true
launchctl load  "$PL_KIM"
echo "LaunchAgent loaded: com.02luka.kim.bot"

# --- 5) self-test
echo "Publishing demo to gg:nlp …"
redis-cli PUBLISH gg:nlp '{"intent":"backup.now"}' >/dev/null || true
sleep 2
echo "Tail bridge logs:"
tail -n 30 "$LOGS"/gg_nlp_bridge.*.log || true

echo "== [$ME] complete =="
