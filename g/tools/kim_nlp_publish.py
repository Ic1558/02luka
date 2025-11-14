#!/usr/bin/env python3
"""Publish Kim NLP payloads directly to Redis."""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime
from typing import Any, Dict

from redis import Redis


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Publish NLP payloads to Kim dispatcher")
    parser.add_argument("message", help="Text to send to the dispatcher")
    parser.add_argument("--channel", default=os.getenv("REDIS_CHANNEL_IN", "gg:nlp"), help="Redis channel")
    parser.add_argument("--chat-id", default=os.getenv("KIM_TEST_CHAT_ID", "cli:test"), help="Chat identifier")
    parser.add_argument("--username", default=os.getenv("USER", "cli"), help="Sender username")
    parser.add_argument("--profile", default=None, help="Force profile id (overrides stored profile)")
    parser.add_argument("--host", default=os.getenv("REDIS_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.getenv("REDIS_PORT", "6379")))
    parser.add_argument("--password", default=os.getenv("REDIS_PASSWORD"))
    return parser.parse_args(argv)


def build_payload(args: argparse.Namespace) -> Dict[str, Any]:
    message_text = args.message.strip()
    chat_id = args.chat_id
    payload = {
        "type": "cli_message",
        "text": message_text,
        "chat_id": chat_id,
        "source": "cli",
        "from": {"username": args.username, "id": f"cli:{args.username}"},
        "message_id": f"cli-{datetime.utcnow().timestamp():.0f}",
        "published_at": datetime.utcnow().isoformat() + "Z",
        "reply_to": f"kim:reply:cli:{chat_id}",
    }
    if args.profile:
        payload["force_profile"] = args.profile
    return payload


def publish(payload: Dict[str, Any], args: argparse.Namespace) -> None:
    client = Redis(
        host=args.host,
        port=args.port,
        password=args.password or None,
        decode_responses=True,
    )
    client.publish(args.channel, json.dumps(payload))


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    payload = build_payload(args)
    publish(payload, args)
    print(f"Published to {args.channel}: {json.dumps(payload)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
