"""Fincept–Paula–HD2 bridge module.

This module synchronises Fincept Terminal queries with Paula Agent using
HD2-backed storage as the source of truth and Redis pub/sub for signalling.
"""
from __future__ import annotations

import json
import logging
import os
import plistlib
import signal
import sys
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable, Optional

try:  # pragma: no cover - optional dependency at runtime
    import redis
    from redis import Redis
    from redis.exceptions import AuthenticationError, ConnectionError, RedisError
except Exception:  # pragma: no cover - logged at runtime if redis missing
    redis = None
    Redis = Any  # type: ignore
    AuthenticationError = ConnectionError = RedisError = Exception  # type: ignore


class FinceptBridge:
    """Bridge Fincept queries into Paula signals through HD2."""

    RETRY_ATTEMPTS = 3
    QUERY_TOPIC = "fincept:query"
    SIGNAL_TOPIC = "paula:signal"
    HEALTH_TOPIC = "fincept:bridge:health"
    HEALTH_INTERVAL = 60.0

    def __init__(self) -> None:
        self.user_home = self._discover_user_home()
        self.hd2_candidates = [Path("/Volumes/HD2"), self.user_home / "HD2"]
        self.hd2_root = self.hd2_candidates[0]
        if not self.hd2_root.exists():
            self.hd2_root = self.hd2_candidates[-1]

        self.log_dir = self.user_home / "Library" / "Logs" / "02luka"
        self.log_file = self.log_dir / "fincept_bridge.log"
        self.launchagent_path = (
            self.user_home / "Library" / "LaunchAgents" / "com.02luka.fincept.bridge.plist"
        )
        self.report_dir = self.user_home / "02luka" / "boss" / "inbox"

        self.logger = self._setup_logger()
        self.redis_client: Optional[Redis] = None
        self.stop_event = threading.Event()
        self._last_health = 0.0

    # ------------------------------------------------------------------
    # Setup helpers
    # ------------------------------------------------------------------
    @staticmethod
    def _discover_user_home() -> Path:
        preferred = Path("/Users/icmini")
        if preferred.exists():
            return preferred
        return Path.home()

    def _setup_logger(self) -> logging.Logger:
        self.log_dir.mkdir(parents=True, exist_ok=True)
        logger = logging.getLogger("fincept_bridge")
        logger.setLevel(logging.INFO)

        formatter = logging.Formatter(
            fmt="%(asctime)s | %(levelname)s | %(message)s",
            datefmt="%Y-%m-%dT%H:%M:%S",
        )

        if not any(isinstance(handler, logging.FileHandler) and handler.baseFilename == str(self.log_file)
                   for handler in logger.handlers):
            file_handler = logging.FileHandler(self.log_file)
            file_handler.setFormatter(formatter)
            logger.addHandler(file_handler)

        if not any(isinstance(handler, logging.StreamHandler) and handler.stream is sys.stdout
                   for handler in logger.handlers):
            stream_handler = logging.StreamHandler(sys.stdout)
            stream_handler.setFormatter(formatter)
            logger.addHandler(stream_handler)

        return logger

    # ------------------------------------------------------------------
    # Filesystem handling
    # ------------------------------------------------------------------
    def trading_root(self) -> Path:
        return self.hd2_root / "trading"

    def ensure_dirs(self) -> None:
        required_paths = [
            self.trading_root(),
            self.trading_root() / "fincept",
            self.trading_root() / "fincept" / "stocks" / "raw",
            self.trading_root() / "fincept" / "forex" / "raw",
            self.trading_root() / "fincept" / "crypto" / "raw",
            self.trading_root() / "fincept" / "commodities" / "raw",
            self.trading_root() / "fincept" / "exports" / "signals",
            self.trading_root() / "fincept" / "exports" / "backtests",
            self.trading_root() / "paula",
            self.trading_root() / "paula" / "signals",
            self.trading_root() / "paula" / "positions",
            self.trading_root() / "paula" / "reports",
            self.trading_root() / "paula" / "logs",
        ]

        for path in required_paths:
            path.mkdir(parents=True, exist_ok=True)
            if not self._validate_rw(path):
                raise PermissionError(f"Insufficient permissions for {path}")

    def _validate_rw(self, path: Path) -> bool:
        try:
            test_file = path / ".fincept_bridge.tmp"
            test_file.write_text("ok", encoding="utf-8")
            test_file.unlink(missing_ok=True)
            return os.access(path, os.R_OK | os.W_OK)
        except Exception as exc:  # pragma: no cover - relies on environment
            self.logger.error("Permission validation failed for %s: %s", path, exc)
            return False

    # ------------------------------------------------------------------
    # Redis handling
    # ------------------------------------------------------------------
    def _discover_redis_url(self) -> str:
        env_url = os.environ.get("REDIS_URL")
        if env_url:
            return env_url

        password = os.environ.get("REDIS_PASSWORD") or self._read_password_file()
        if password:
            return f"redis://:{password}@localhost:6379/0"
        return "redis://localhost:6379/0"

    @staticmethod
    def _read_password_file() -> Optional[str]:
        candidates = [
            Path.home() / ".redis_pass",
            Path.home() / "Library" / "Application Support" / "02luka" / "redis.pass",
        ]
        for candidate in candidates:
            if candidate.exists():
                try:
                    content = candidate.read_text(encoding="utf-8").strip()
                    if content:
                        return content.splitlines()[0].strip()
                except Exception:
                    continue
        return None

    def _connect_redis(self) -> bool:
        if redis is None:
            self.logger.error("redis package not available; bridge cannot start")
            return False

        url = self._discover_redis_url()

        for attempt in range(1, self.RETRY_ATTEMPTS + 1):
            try:
                client = redis.from_url(url, decode_responses=True)
                client.ping()
                self.redis_client = client
                self.logger.info("Connected to redis at %s", url)
                return True
            except AuthenticationError as auth_error:
                self.logger.warning("Redis authentication failed: %s", auth_error)
                password = self._read_password_file()
                if password:
                    url = f"redis://:{password}@localhost:6379/0"
                    continue
            except (ConnectionError, RedisError) as conn_error:
                self.logger.warning(
                    "Redis connection attempt %s/%s failed: %s",
                    attempt,
                    self.RETRY_ATTEMPTS,
                    conn_error,
                )
                time.sleep(min(2 ** attempt, 8))

        self.logger.error("Unable to establish Redis connection after %s attempts", self.RETRY_ATTEMPTS)
        return False

    # ------------------------------------------------------------------
    # LaunchAgent provisioning
    # ------------------------------------------------------------------
    def ensure_launchagent(self) -> None:
        plist_dir = self.launchagent_path.parent
        plist_dir.mkdir(parents=True, exist_ok=True)

        program_path = self.user_home / "02luka" / "g" / "modules" / "fincept_bridge.py"
        stdout_path = self.log_dir / "fincept_bridge.out"
        stderr_path = self.log_dir / "fincept_bridge.err"

        payload = {
            "Label": "com.02luka.fincept.bridge",
            "ProgramArguments": ["/usr/bin/python3", str(program_path)],
            "RunAtLoad": True,
            "KeepAlive": True,
            "WorkingDirectory": str(program_path.parent),
            "StandardOutPath": str(stdout_path),
            "StandardErrorPath": str(stderr_path),
            "EnvironmentVariables": {
                "PYTHONUNBUFFERED": "1",
            },
        }

        existing: Optional[Dict[str, Any]] = None
        if self.launchagent_path.exists():
            try:
                with self.launchagent_path.open("rb") as fh:
                    existing = plistlib.load(fh)
            except Exception as exc:
                self.logger.warning("Failed to read existing LaunchAgent plist: %s", exc)

        if existing != payload:
            with self.launchagent_path.open("wb") as fh:
                plistlib.dump(payload, fh)
            self.logger.info("LaunchAgent configuration updated at %s", self.launchagent_path)
        else:
            self.logger.info("LaunchAgent configuration already up to date")

    # ------------------------------------------------------------------
    # Redis message handling
    # ------------------------------------------------------------------
    def handle_query(self, raw_message: Any) -> None:
        if raw_message is None:
            return

        try:
            request = json.loads(raw_message) if isinstance(raw_message, str) else raw_message
        except json.JSONDecodeError as exc:
            self.logger.error("Invalid query payload: %s", exc)
            return

        if not isinstance(request, dict):
            self.logger.error("Unsupported query payload type: %r", request)
            return

        action = (request.get("action") or "read").lower()
        asset_class = request.get("asset") or request.get("asset_class") or "stocks"
        symbol = request.get("symbol")
        relative_path = request.get("path")

        try:
            if action == "list":
                response = self._handle_list(asset_class, request)
            else:
                response = self._handle_read(asset_class, symbol, relative_path, request)
        except Exception as exc:  # pragma: no cover - filesystem/redis runtime paths
            self.logger.error("Query handling error: %s", exc)
            response = {
                "status": "error",
                "error": str(exc),
                "request": request,
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }

        if response:
            self.publish_signal(response)

    def _handle_list(self, asset_class: str, request: Dict[str, Any]) -> Dict[str, Any]:
        target_dir = self.trading_root() / "fincept" / asset_class / request.get("bucket", "raw")
        target_dir.mkdir(parents=True, exist_ok=True)
        pattern = request.get("glob", "*")
        files = sorted(
            str(path.relative_to(self.trading_root()))
            for path in target_dir.glob(pattern)
            if path.is_file()
        )
        return {
            "status": "ok",
            "action": "list",
            "files": files,
            "request": request,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }

    def _handle_read(
        self,
        asset_class: str,
        symbol: Optional[str],
        relative_path: Optional[str],
        request: Dict[str, Any],
    ) -> Dict[str, Any]:
        if relative_path:
            target = self.trading_root() / relative_path
        else:
            bucket = request.get("bucket", "raw")
            if not symbol:
                raise ValueError("Missing symbol for read action")
            extension = request.get("extension", "json")
            filename = request.get("filename") or f"{symbol}.{extension}"
            target = self.trading_root() / "fincept" / asset_class / bucket / filename

        if not target.exists():
            raise FileNotFoundError(f"Data not found at {target}")

        data = target.read_text(encoding="utf-8")
        return {
            "status": "ok",
            "action": "read",
            "symbol": symbol,
            "asset_class": asset_class,
            "request": request,
            "data": data,
            "source": str(target.relative_to(self.trading_root())),
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }

    # ------------------------------------------------------------------
    # Redis publishing & health
    # ------------------------------------------------------------------
    def publish_signal(self, payload: Dict[str, Any]) -> None:
        if not self.redis_client:
            self.logger.error("Cannot publish signal; Redis unavailable")
            return
        try:
            self.redis_client.publish(self.SIGNAL_TOPIC, json.dumps(payload))
            self.logger.info("Published signal to %s", self.SIGNAL_TOPIC)
        except RedisError as exc:  # pragma: no cover - network dependent
            self.logger.error("Failed to publish signal: %s", exc)

    def _publish_health(self) -> None:
        if not self.redis_client:
            return
        now = time.monotonic()
        if now - self._last_health < self.HEALTH_INTERVAL:
            return
        payload = {
            "status": "alive",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "hd2": str(self.hd2_root),
        }
        try:
            self.redis_client.publish(self.HEALTH_TOPIC, json.dumps(payload))
            self._last_health = now
            self.logger.debug("Health ping published")
        except RedisError as exc:  # pragma: no cover - network dependent
            self.logger.warning("Failed to publish health ping: %s", exc)

    # ------------------------------------------------------------------
    # Reporting
    # ------------------------------------------------------------------
    def _write_report(self, status: str, details: Iterable[str]) -> None:
        try:
            self.report_dir.mkdir(parents=True, exist_ok=True)
            report_name = f"REPORT_fincept_bridge_{datetime.utcnow():%Y%m%d}.md"
            report_path = self.report_dir / report_name
            lines = [
                "# Fincept Bridge Deployment Report",
                "",
                f"**Status:** {status}",
                f"**Timestamp:** {datetime.utcnow().isoformat()}Z",
                "",
                "## Details",
            ]
            lines.extend(f"- {line}" for line in details)
            report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            self.logger.info("Report written to %s", report_path)
        except Exception as exc:  # pragma: no cover - filesystem dependent
            self.logger.warning("Failed to write report: %s", exc)

    # ------------------------------------------------------------------
    # HD2 handling
    # ------------------------------------------------------------------
    def _resolve_hd2_root(self) -> bool:
        for candidate in self.hd2_candidates:
            if candidate.exists():
                if candidate != self.hd2_root:
                    self.logger.info("HD2 mount switched to %s", candidate)
                self.hd2_root = candidate
                return True
        return False

    # ------------------------------------------------------------------
    # Main loop
    # ------------------------------------------------------------------
    def run(self) -> None:
        self.logger.info("Starting FinceptBridge")

        signal.signal(signal.SIGTERM, self._handle_stop)
        signal.signal(signal.SIGINT, self._handle_stop)

        if not self._resolve_hd2_root():
            self.logger.error("HD2 mount not found; exiting safely")
            self._write_report("failed", ["HD2 mount unavailable"])
            return

        try:
            self.ensure_dirs()
        except Exception as exc:
            self.logger.error("Failed to prepare HD2 directories: %s", exc)
            self._write_report("failed", [f"HD2 preparation error: {exc}"])
            return

        if not self._connect_redis():
            self._write_report("failed", ["Redis connection unavailable"])
            return

        report_details = [
            f"HD2 root: {self.hd2_root}",
            "Directories ensured",
            "Redis connected",
        ]

        try:
            self.ensure_launchagent()
            report_details.append(f"LaunchAgent: {self.launchagent_path}")
        except Exception as exc:
            self.logger.error("Failed to configure LaunchAgent: %s", exc)
            report_details.append(f"LaunchAgent configuration error: {exc}")

        self._write_report("ok", report_details)

        pubsub = self.redis_client.pubsub(ignore_subscribe_messages=True)
        pubsub.subscribe(self.QUERY_TOPIC)
        self.logger.info("Subscribed to %s", self.QUERY_TOPIC)

        hd2_retries = self.RETRY_ATTEMPTS
        redis_retries = self.RETRY_ATTEMPTS

        while not self.stop_event.is_set():
            if not self._resolve_hd2_root():
                hd2_retries -= 1
                self.logger.warning("HD2 mount missing; retries left: %s", hd2_retries)
                if hd2_retries <= 0:
                    self.logger.error("HD2 mount unavailable after retries; shutting down")
                    break
                time.sleep(5)
                continue
            else:
                hd2_retries = self.RETRY_ATTEMPTS

            try:
                message = pubsub.get_message(timeout=1.0)
                redis_retries = self.RETRY_ATTEMPTS
            except ConnectionError as exc:
                redis_retries -= 1
                self.logger.warning("Redis pubsub error: %s (retries left %s)", exc, redis_retries)
                if redis_retries <= 0 or not self._connect_redis():
                    self.logger.error("Redis unavailable; shutting down")
                    break
                pubsub = self.redis_client.pubsub(ignore_subscribe_messages=True)
                pubsub.subscribe(self.QUERY_TOPIC)
                redis_retries = self.RETRY_ATTEMPTS
                continue

            if message:
                self.logger.info("Received message on %s", self.QUERY_TOPIC)
                self.handle_query(message.get("data"))

            self._publish_health()
            time.sleep(0.2)

        pubsub.close()
        self.logger.info("FinceptBridge stopped")

    def _handle_stop(self, signum: int, _: Optional[object]) -> None:
        self.logger.info("Received stop signal (%s)", signum)
        self.stop_event.set()


if __name__ == "__main__":  # pragma: no cover - entry point
    FinceptBridge().run()
