import json
import logging
import os
import sys
from datetime import datetime

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


def build_payload(update: Update) -> dict:
    message = update.message
    chat = message.chat
    sender = message.from_user
    payload = {
        "type": "telegram_message",
        "text": (message.text or "").strip(),
        "message_id": message.message_id,
        "date": message.date.isoformat() if message.date else None,
        "chat": {
            "id": chat.id,
            "type": chat.type,
            "title": chat.title,
            "username": chat.username,
        },
        "from": {
            "id": sender.id if sender else None,
            "is_bot": sender.is_bot if sender else None,
            "username": sender.username if sender else None,
            "first_name": sender.first_name if sender else None,
            "last_name": sender.last_name if sender else None,
            "language_code": sender.language_code if sender else None,
        },
        "source": "telegram",
        "reply_to": f"kim:reply:telegram:{chat.id}",
        "published_at": datetime.utcnow().isoformat() + "Z",
    }
    if message.entities:
        payload["entities"] = [entity.to_dict() for entity in message.entities]
    return payload


def ack_text(text: str) -> str:
    stripped = text.strip()
    if stripped.startswith("/use"):
        parts = stripped.split(maxsplit=1)
        target = parts[1].strip() if len(parts) > 1 else "(missing)"
        return f"Requested profile switch → {target}"
    if stripped.startswith("/k2"):
        return "Dispatching question via Kim K2 profile (one-off)."
    return f"Dispatching message via Kim ({REDIS_CHANNEL})."


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if update.message:
        await update.message.reply_text(
            "Kim online ✅  Send /use <profile> or /k2 <question> to access K2."
        )


async def to_nlp(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.message:
        return
    text = (update.message.text or "").strip()
    if not text:
        return

    payload = build_payload(update)
    try:
        redis_client.publish(REDIS_CHANNEL, json.dumps(payload))
        logging.info("PUB → %s : %s", REDIS_CHANNEL, payload)
        await update.message.reply_text(ack_text(text))
    except Exception:  # pragma: no cover - defensive logging
        logging.exception("Redis publish failed")
        await update.message.reply_text("ERR: cannot reach NLP bridge")


def main() -> None:
    app = Application.builder().token(TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(MessageHandler(filters.TEXT, to_nlp))
    app.run_polling(close_loop=False)


if __name__ == "__main__":
    main()
