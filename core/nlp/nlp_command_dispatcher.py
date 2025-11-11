"""Redis-backed NLP command dispatcher for the Kim agent."""
from __future__ import annotations

import json
import logging
import os
import signal
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Dict, Optional

import yaml  # type: ignore
from redis import Redis

from .profile_store import ProfileStore

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class Profile:
    """Represents a logical Kim profile."""

    id: str
    name: str
    description: str
    provider: str
    channel: str = "kim:requests"
    metadata: Dict[str, object] = field(default_factory=dict)

    def as_dict(self) -> Dict[str, object]:
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "provider": self.provider,
            "channel": self.channel,
            "metadata": self.metadata,
        }


DEFAULT_PROFILE = Profile(
    id="default",
    name="Kim Default",
    description="Baseline Kim profile using legacy routing",
    provider="kim.default",
    channel="kim:requests",
    metadata={"mode": "default"},
)


def load_profiles(profile_dir: Path) -> Dict[str, Profile]:
    """Load profile descriptors from a directory of YAML files."""
    profiles: Dict[str, Profile] = {DEFAULT_PROFILE.id: DEFAULT_PROFILE}
    if not profile_dir.exists():
        return profiles

    for entry in sorted(profile_dir.glob("*.y*ml")):
        try:
            with entry.open("r", encoding="utf-8") as handle:
                payload = yaml.safe_load(handle) or {}
        except Exception as exc:  # pragma: no cover - logged for diagnostics
            logger.warning("Failed to load profile %s: %s", entry, exc)
            continue
        if not isinstance(payload, dict):
            continue
        profile_id = payload.get("id") or payload.get("profile_id")
        name = payload.get("name") or profile_id
        provider = payload.get("provider") or payload.get("backend")
        description = payload.get("description") or ""
        channel = payload.get("channel") or payload.get("redis_channel") or "kim:requests"
        metadata = payload.get("metadata") or {}
        if not profile_id or not provider:
            continue
        profiles[str(profile_id)] = Profile(
            id=str(profile_id),
            name=str(name or profile_id),
            description=str(description or ""),
            provider=str(provider),
            channel=str(channel),
            metadata=metadata if isinstance(metadata, dict) else {},
        )
    return profiles


class CommandDispatcher:
    """Stateful NLP command dispatcher."""

    def __init__(
        self,
        profile_store: ProfileStore,
        profiles: Optional[Dict[str, Profile]] = None,
        *,
        publisher: Optional[Callable[[str, Dict[str, object]], None]] = None,
        events_channel: str = "kim:dispatcher:events",
        default_profile_id: str = DEFAULT_PROFILE.id,
        k2_profile_id: str = "kim_k2_poc",
    ) -> None:
        self.profile_store = profile_store
        self.profiles = profiles or {DEFAULT_PROFILE.id: DEFAULT_PROFILE}
        if default_profile_id not in self.profiles:
            self.profiles[default_profile_id] = DEFAULT_PROFILE
        self.default_profile_id = default_profile_id
        self.k2_profile_id = k2_profile_id
        self.publisher = publisher or (lambda _channel, _payload: None)
        self.events_channel = events_channel

    # ------------------------------------------------------------------
    def _profile_for_chat(self, chat_id: str) -> Profile:
        record = self.profile_store.get_profile(chat_id)
        profile = self.profiles.get(record.profile_id)
        if profile:
            return profile
        return self.profiles[self.default_profile_id]

    def _publish(self, channel: str, payload: Dict[str, object]) -> None:
        try:
            self.publisher(channel, payload)
        except Exception:  # pragma: no cover - defensive logging
            logger.exception("Publisher failed for channel %s", channel)

    def _emit_event(self, payload: Dict[str, object]) -> None:
        event = {"ts": datetime.now(timezone.utc).isoformat(), **payload}
        self._publish(self.events_channel, event)

    def _normalise_chat_id(self, payload: Dict[str, object]) -> Optional[str]:
        chat = payload.get("chat")
        if isinstance(chat, dict):
            chat_id = chat.get("id")
            if chat_id is not None:
                return str(chat_id)
        for key in ("chat_id", "conversation_id", "session_id"):
            value = payload.get(key)
            if value is not None:
                return str(value)
        return None

    def _extract_text(self, payload: Dict[str, object]) -> str:
        text = payload.get("text")
        if isinstance(text, str):
            return text.strip()
        return ""

    def _dispatch_message(
        self,
        *,
        chat_id: str,
        text: str,
        profile: Profile,
        payload: Dict[str, object],
        one_off: bool = False,
    ) -> Dict[str, object]:
        request = {
            "type": "kim_nlp_request",
            "profile": profile.id,
            "provider": profile.provider,
            "channel": profile.channel,
            "prompt": text,
            "chat": payload.get("chat"),
            "user": payload.get("from") or payload.get("user"),
            "metadata": profile.metadata,
            "source": payload.get("source", "telegram"),
            "one_off": one_off,
            "message_id": payload.get("message_id"),
            "reply_to": payload.get("reply_to") or f"kim:reply:telegram:{chat_id}",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        self._publish(profile.channel, request)
        self._emit_event(
            {
                "event": "kim.dispatch.sent",
                "chat_id": chat_id,
                "profile": profile.id,
                "provider": profile.provider,
                "one_off": one_off,
            }
        )
        return {
            "ok": True,
            "action": "dispatch",
            "profile": profile.id,
            "provider": profile.provider,
            "channel": profile.channel,
            "one_off": one_off,
        }

    def _handle_use(self, chat_id: str, text: str) -> Dict[str, object]:
        parts = text.split(maxsplit=1)
        if len(parts) < 2 or not parts[1].strip():
            return {
                "ok": False,
                "action": "profile_update",
                "error": "profile id required",
                "available_profiles": sorted(self.profiles.keys()),
            }
        profile_token = parts[1].strip()
        if profile_token.lower() == self.default_profile_id:
            self.profile_store.clear_profile(chat_id)
            profile = self.profiles[self.default_profile_id]
            self._emit_event(
                {
                    "event": "kim.dispatch.profile_reset",
                    "chat_id": chat_id,
                    "profile": profile.id,
                }
            )
            return {
                "ok": True,
                "action": "profile_update",
                "profile": profile.id,
                "message": f"Profile reset to {profile.name}",
            }
        profile = self.profiles.get(profile_token)
        if not profile:
            return {
                "ok": False,
                "action": "profile_update",
                "error": f"unknown profile: {profile_token}",
                "available_profiles": sorted(self.profiles.keys()),
            }
        self.profile_store.set_profile(chat_id, profile.id)
        self._emit_event(
            {
                "event": "kim.dispatch.profile_set",
                "chat_id": chat_id,
                "profile": profile.id,
            }
        )
        return {
            "ok": True,
            "action": "profile_update",
            "profile": profile.id,
            "message": f"Profile set to {profile.name}",
        }

    def _handle_k2(self, chat_id: str, text: str, payload: Dict[str, object]) -> Dict[str, object]:
        profile = self.profiles.get(self.k2_profile_id)
        parts = text.split(maxsplit=1)
        if not profile:
            return {
                "ok": False,
                "action": "dispatch",
                "error": f"profile not configured: {self.k2_profile_id}",
            }
        if len(parts) < 2 or not parts[1].strip():
            return {
                "ok": False,
                "action": "dispatch",
                "error": "question required",
            }
        question = parts[1].strip()
        return self._dispatch_message(
            chat_id=chat_id,
            text=question,
            profile=profile,
            payload=payload,
            one_off=True,
        )

    def handle_payload(self, payload: Dict[str, object]) -> Dict[str, object]:
        chat_id = self._normalise_chat_id(payload)
        if not chat_id:
            logger.warning("Skipping payload without chat id: %s", payload)
            return {"ok": False, "error": "chat id missing"}
        text = self._extract_text(payload)
        if not text:
            return {"ok": False, "error": "empty message"}

        if text.startswith("/use"):
            return self._handle_use(chat_id, text)
        if text.startswith("/k2"):
            return self._handle_k2(chat_id, text, payload)

        forced_profile = payload.get("force_profile")
        if isinstance(forced_profile, str):
            profile = self.profiles.get(forced_profile) or self.profiles[self.default_profile_id]
            return self._dispatch_message(
                chat_id=chat_id,
                text=text,
                profile=profile,
                payload=payload,
                one_off=True,
            )

        profile = self._profile_for_chat(chat_id)
        return self._dispatch_message(
            chat_id=chat_id,
            text=text,
            profile=profile,
            payload=payload,
            one_off=False,
        )

    # ------------------------------------------------------------------
    def run(self, redis_client: Redis, channel: Optional[str] = None) -> None:
        """Start listening for messages and dispatching them."""
        channel = channel or os.getenv("REDIS_CHANNEL_IN", "gg:nlp")
        pubsub = redis_client.pubsub(ignore_subscribe_messages=True)
        pubsub.subscribe(channel)
        logger.info("Subscribed to %s", channel)

        stop_requested = False

        def _signal_handler(_signum, _frame):
            nonlocal stop_requested
            stop_requested = True
            logger.info("Stop signal received")

        original_sigint = signal.getsignal(signal.SIGINT)
        original_sigterm = signal.getsignal(signal.SIGTERM)
        signal.signal(signal.SIGINT, _signal_handler)
        signal.signal(signal.SIGTERM, _signal_handler)

        try:
            while not stop_requested:
                message = pubsub.get_message(timeout=1.0)
                if not message:
                    continue
                if message.get("type") != "message":
                    continue
                raw = message.get("data")
                try:
                    payload = json.loads(raw)
                except Exception:
                    payload = {"text": raw}
                result = self.handle_payload(payload)
                logger.debug("Handled payload result=%s", result)
        finally:
            pubsub.close()
            signal.signal(signal.SIGINT, original_sigint)
            signal.signal(signal.SIGTERM, original_sigterm)
            logger.info("Dispatcher stopped")


def create_redis_publisher(redis_client: Redis) -> Callable[[str, Dict[str, object]], None]:
    def _publish(channel: str, payload: Dict[str, object]) -> None:
        redis_client.publish(channel, json.dumps(payload, ensure_ascii=False))
    return _publish


def resolve_default_paths() -> tuple[Path, Path]:
    base = Path.home() / "02luka"
    store_path = Path(os.getenv("KIM_PROFILE_STORE", base / "core" / "nlp" / "kim_session_profiles.json"))
    profile_dir = Path(os.getenv("KIM_PROFILE_DIR", base / "config" / "kim_agent_profiles"))
    return store_path, profile_dir


def configure_logging() -> None:
    level = os.getenv("KIM_DISPATCH_LOG_LEVEL", "INFO").upper()
    logging.basicConfig(
        level=getattr(logging, level, logging.INFO),
        format="%(asctime)s [kim-dispatcher] %(levelname)s: %(message)s",
    )


def main() -> None:
    configure_logging()
    store_path, profile_dir = resolve_default_paths()
    profiles = load_profiles(profile_dir)
    store = ProfileStore(store_path)

    redis_host = os.getenv("REDIS_HOST", "127.0.0.1")
    redis_port = int(os.getenv("REDIS_PORT", "6379"))
    redis_password = os.getenv("REDIS_PASSWORD") or None

    redis_client = Redis(
        host=redis_host,
        port=redis_port,
        password=redis_password,
        decode_responses=True,
    )
    dispatcher = CommandDispatcher(
        profile_store=store,
        profiles=profiles,
        publisher=create_redis_publisher(redis_client),
        events_channel=os.getenv("KIM_DISPATCH_EVENTS_CHANNEL", "kim:dispatcher:events"),
        k2_profile_id=os.getenv("KIM_K2_PROFILE_ID", "kim_k2_poc"),
    )
    dispatcher.run(redis_client, channel=os.getenv("REDIS_CHANNEL_IN", "gg:nlp"))


if __name__ == "__main__":
    main()
