import json
import logging
import os
import sys

from redis import Redis
from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
REDIS_HOST = os.getenv("REDIS_HOST", "127.0.0.1")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD") or None
REDIS_CHANNEL = os.getenv("REDIS_CHANNEL_IN", "gg:nlp")

if not TOKEN:
    print("ERROR: TELEGRAM_BOT_TOKEN missing", file=sys.stderr)
    sys.exit(1)

logging.basicConfig(
    format="%(asctime)s [kim-bot] %(levelname)s: %(message)s",
    level=logging.INFO,
)

redis_client = Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    password=REDIS_PASSWORD,
    decode_responses=True,
)


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if update.message:
        await update.message.reply_text(
            "Kim online ✅  Send an intent (e.g., 'backup now')."
        )


async def to_nlp(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.message:
        return
    text = (update.message.text or "").strip()
    if not text:
        return

    payload = json.dumps({"text": text})
    try:
        redis_client.publish(REDIS_CHANNEL, payload)
        logging.info("PUB → %s : %s", REDIS_CHANNEL, payload)
        await update.message.reply_text(f"ACK → {REDIS_CHANNEL}")
    except Exception:  # pragma: no cover - defensive logging
        logging.exception("Redis publish failed")
        await update.message.reply_text("ERR: cannot reach NLP bridge")


def main() -> None:
    app = Application.builder().token(TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, to_nlp))
    app.run_polling(close_loop=False)


if __name__ == "__main__":
    main()
