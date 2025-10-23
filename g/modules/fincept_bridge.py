# 2025-02-14
"""Fincept Bridge integration between Fincept data and Paula via HD2 and Redis."""
from __future__ import annotations

import argparse
import json
import logging
import os
import signal
import sys
import threading
import time
from dataclasses import dataclass
from datetime import datetime
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Iterable, Optional

try:
    import redis  # type: ignore
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "The 'redis' package is required to run fincept_bridge.py. "
        "Install it with 'pip install redis'."
    ) from exc


HD2_PRIMARY = Path("/Volumes/HD2")
HD2_SECONDARY = Path.home() / "HD2"
LOG_DIR = Path.home() / "Library" / "Logs" / "02luka"
LOG_FILE = LOG_DIR / "fincept_bridge.log"

SUBSCRIBE_TOPIC = "fincept:query"
PUBLISH_TOPIC = "paula:signal"
HEARTBEAT_TOPIC = "fincept:bridge:health"
HEARTBEAT_INTERVAL = 60
MAX_RETRIES = 3
BACKOFF_BASE_SECONDS = 3


@dataclass
class BridgeConfig:
    hd2_root: Path
    subscribe_topic: str = SUBSCRIBE_TOPIC
    publish_topic: str = PUBLISH_TOPIC
    heartbeat_topic: str = HEARTBEAT_TOPIC


class FinceptBridge:
    """Bidirectional bridge between Fincept storage and Paula notifications."""

    def __init__(self, config: BridgeConfig) -> None:
        self.config = config
        self.logger = logging.getLogger("fincept_bridge")
        self._redis: Optional[redis.Redis] = None
        self._stop_event = threading.Event()
        self._pubsub: Optional[redis.client.PubSub] = None

    # ------------------------------------------------------------------
    # Setup helpers
    # ------------------------------------------------------------------
    def setup_logging(self) -> None:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        handler = RotatingFileHandler(LOG_FILE, maxBytes=10 * 1024 * 1024, backupCount=5)
        formatter = logging.Formatter(
            fmt="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        handler.setFormatter(formatter)
        self.logger.addHandler(handler)
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(formatter)
        self.logger.addHandler(console_handler)
        self.logger.setLevel(logging.INFO)
        self.logger.debug("Logging configured. Log file located at %s", LOG_FILE)

    def ensure_storage_ready(self) -> None:
        required_dirs: Iterable[Path] = [
            self.config.hd2_root / "trading" / "fincept" / category / "raw"
            for category in ("stocks", "forex", "crypto", "commodities")
        ]
        required_dirs = list(required_dirs) + [
            self.config.hd2_root / "trading" / "fincept" / "exports" / "signals",
            self.config.hd2_root / "trading" / "fincept" / "exports" / "backtests",
            self.config.hd2_root / "trading" / "paula" / "signals",
            self.config.hd2_root / "trading" / "paula" / "positions",
            self.config.hd2_root / "trading" / "paula" / "reports",
            self.config.hd2_root / "trading" / "paula" / "logs",
        ]
        for directory in required_dirs:
            directory.mkdir(parents=True, exist_ok=True)
        self.logger.debug("Storage directories ensured under %s", self.config.hd2_root)

    def connect_redis(self) -> redis.Redis:
        if self._redis is not None:
            return self._redis

        redis_url = os.getenv("REDIS_URL")
        if redis_url:
            client = redis.from_url(redis_url, decode_responses=True)
        else:
            client = redis.Redis(host="localhost", port=6379, decode_responses=True)
        self._redis = client
        self.logger.debug("Redis connection established: %s", redis_url or "localhost:6379")
        return client

    # ------------------------------------------------------------------
    # Runtime helpers
    # ------------------------------------------------------------------
    def publish_health(self) -> None:
        payload = json.dumps(
            {
                "timestamp": datetime.utcnow().isoformat(),
                "status": "ok",
                "location": str(self.config.hd2_root),
            }
        )
        try:
            self.connect_redis().publish(self.config.heartbeat_topic, payload)
            self.logger.debug("Heartbeat published: %s", payload)
        except redis.RedisError as exc:
            self.logger.warning("Failed to publish heartbeat: %s", exc)

    def publish_signal(self, message: dict) -> None:
        try:
            self.connect_redis().publish(self.config.publish_topic, json.dumps(message))
            self.logger.info("Signal published to %s", self.config.publish_topic)
        except redis.RedisError as exc:
            self.logger.error("Unable to publish signal: %s", exc)

    def _handle_payload(self, payload: str) -> None:
        try:
            data = json.loads(payload)
        except json.JSONDecodeError:
            self.logger.warning("Received non-JSON payload: %s", payload)
            return

        action = data.get("action", "unknown")
        reference = data.get("reference")
        self.logger.info("Processing action=%s reference=%s", action, reference)

        response = {
            "action": action,
            "reference": reference,
            "status": "acknowledged",
            "handled_at": datetime.utcnow().isoformat(),
        }
        self.publish_signal(response)

    def _process_stream(self, once: bool = False) -> None:
        client = self.connect_redis()
        self._pubsub = client.pubsub(ignore_subscribe_messages=True)
        self._pubsub.subscribe(self.config.subscribe_topic)
        last_heartbeat = 0.0

        try:
            while not self._stop_event.is_set():
                message = self._pubsub.get_message(timeout=1.0)
                current_time = time.time()

                if message and message.get("type") == "message":
                    data = message.get("data")
                    if isinstance(data, str):
                        self._handle_payload(data)
                    else:
                        self.logger.debug("Ignoring non-text message: %s", message)
                    if once:
                        break

                if current_time - last_heartbeat >= HEARTBEAT_INTERVAL:
                    self.publish_health()
                    last_heartbeat = current_time

                if once and message is None:
                    # No message received; break after heartbeat for once mode.
                    if current_time - last_heartbeat < HEARTBEAT_INTERVAL:
                        break
        finally:
            if self._pubsub is not None:
                self._pubsub.close()
                self._pubsub = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def run(self, once: bool = False) -> None:
        retries = 0
        while retries < MAX_RETRIES and not self._stop_event.is_set():
            try:
                self.ensure_storage_ready()
                self.connect_redis().ping()
                break
            except (redis.RedisError, OSError) as exc:
                wait_time = BACKOFF_BASE_SECONDS * (2 ** retries)
                self.logger.warning(
                    "Initialisation failed (%s). Retry %d/%d after %ds.",
                    exc,
                    retries + 1,
                    MAX_RETRIES,
                    wait_time,
                )
                retries += 1
                time.sleep(wait_time)
        else:
            self.logger.error("Exceeded maximum retries during startup. Exiting safely.")
            return

        if once:
            self.logger.info("Running in one-shot mode")
            self._process_stream(once=True)
            return

        self.logger.info("Starting daemon listener mode")
        backoff = BACKOFF_BASE_SECONDS
        while not self._stop_event.is_set():
            try:
                self._process_stream(once=False)
            except redis.RedisError as exc:
                self.logger.error("Redis error: %s", exc)
            except Exception as exc:  # pragma: no cover
                self.logger.exception("Unhandled error: %s", exc)

            if self._stop_event.is_set():
                break

            self.logger.info("Reconnecting after disruption (backoff %ds)", backoff)
            time.sleep(backoff)
            backoff = min(backoff * 2, 60)

    def stop(self) -> None:
        self._stop_event.set()
        if self._pubsub is not None:
            self._pubsub.close()
        self.logger.info("Fincept Bridge stopping")


def detect_hd2_root() -> Path:
    if HD2_PRIMARY.exists():
        return HD2_PRIMARY
    return HD2_SECONDARY


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Fincept ↔ Paula bridge controller")
    parser.add_argument("--once", action="store_true", help="Run a single processing cycle")
    parser.add_argument("--daemon", action="store_true", help="Run as a long-lived listener")
    return parser


def main(argv: Optional[Iterable[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)

    if args.once and args.daemon:
        parser.error("--once and --daemon cannot be used together")

    hd2_root = detect_hd2_root()
    config = BridgeConfig(hd2_root=hd2_root)
    bridge = FinceptBridge(config)
    bridge.setup_logging()
    bridge.logger.info("HD2 root resolved to %s", hd2_root)

    def _handle_signal(signum: int, _: Optional[object]) -> None:
        bridge.logger.info("Received signal %s. Initiating shutdown.", signum)
        bridge.stop()

    signal.signal(signal.SIGINT, _handle_signal)
    signal.signal(signal.SIGTERM, _handle_signal)

    if args.once:
        bridge.run(once=True)
    else:
        bridge.run(once=args.once)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
