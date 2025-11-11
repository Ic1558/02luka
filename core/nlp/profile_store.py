"""Persistent chat profile store for Kim NLP routing."""
from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from threading import RLock
from typing import Dict, Optional

ISO_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"


def _utcnow() -> datetime:
    """Return timezone-aware UTC now."""
    return datetime.now(timezone.utc)


@dataclass(frozen=True)
class ProfileRecord:
    """Represents a stored chat profile selection."""

    profile_id: str
    updated_at: datetime

    def to_payload(self) -> Dict[str, str]:
        return {
            "profile": self.profile_id,
            "updated_at": self.updated_at.strftime(ISO_FORMAT),
        }

    @staticmethod
    def from_payload(payload: Dict[str, str]) -> Optional["ProfileRecord"]:
        """Create a record from persisted payload data."""
        if not payload:
            return None
        profile_id = payload.get("profile")
        timestamp = payload.get("updated_at")
        if not profile_id or not isinstance(profile_id, str):
            return None
        if not timestamp or not isinstance(timestamp, str):
            return None
        try:
            updated = datetime.strptime(timestamp, ISO_FORMAT)
            updated = updated.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
        return ProfileRecord(profile_id=profile_id, updated_at=updated)


class ProfileStore:
    """Tracks per-chat profile preferences with TTL semantics."""

    def __init__(
        self,
        store_path: Path | str,
        *,
        default_profile: str = "default",
        ttl_days: int = 30,
    ) -> None:
        self.store_path = Path(store_path)
        self.store_path.parent.mkdir(parents=True, exist_ok=True)
        self.default_profile = default_profile
        self.ttl = timedelta(days=ttl_days)
        self._lock = RLock()
        self._cache: Dict[str, ProfileRecord] = {}
        self._load()

    # ------------------------------------------------------------------
    def _load(self) -> None:
        if not self.store_path.exists():
            self._cache = {}
            return
        try:
            with self.store_path.open("r", encoding="utf-8") as handle:
                raw = json.load(handle)
        except Exception:
            raw = {}
        cache: Dict[str, ProfileRecord] = {}
        if isinstance(raw, dict):
            for chat_id, payload in raw.items():
                if not isinstance(chat_id, str):
                    continue
                record = ProfileRecord.from_payload(payload)
                if record:
                    cache[chat_id] = record
        self._cache = cache

    def _persist(self) -> None:
        data = {chat_id: record.to_payload() for chat_id, record in self._cache.items()}
        with self.store_path.open("w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2, sort_keys=True)

    def _prune_expired(self, now: Optional[datetime] = None) -> None:
        now = now or _utcnow()
        expired = [
            chat_id
            for chat_id, record in self._cache.items()
            if now - record.updated_at >= self.ttl
        ]
        for chat_id in expired:
            self._cache.pop(chat_id, None)
        if expired:
            self._persist()

    # ------------------------------------------------------------------
    def set_profile(self, chat_id: str | int, profile_id: str, *, now: Optional[datetime] = None) -> None:
        """Persist the selected profile for a chat."""
        if not profile_id:
            raise ValueError("profile_id required")
        chat_key = str(chat_id)
        timestamp = now or _utcnow()
        record = ProfileRecord(profile_id=profile_id, updated_at=timestamp)
        with self._lock:
            self._cache[chat_key] = record
            self._persist()

    def clear_profile(self, chat_id: str | int) -> None:
        chat_key = str(chat_id)
        with self._lock:
            if chat_key in self._cache:
                self._cache.pop(chat_key, None)
                self._persist()

    def get_profile(
        self, chat_id: str | int, *, now: Optional[datetime] = None
    ) -> ProfileRecord:
        """Return the profile record for a chat (default when missing/expired)."""
        chat_key = str(chat_id)
        now = now or _utcnow()
        with self._lock:
            record = self._cache.get(chat_key)
            if record and now - record.updated_at < self.ttl:
                return record
            if record:
                # prune lazy expired entry
                self._cache.pop(chat_key, None)
                self._persist()
            return ProfileRecord(profile_id=self.default_profile, updated_at=now)

    def clear_expired(self, *, now: Optional[datetime] = None) -> int:
        """Remove all expired profiles and return the number cleared."""
        now = now or _utcnow()
        with self._lock:
            before = len(self._cache)
            self._prune_expired(now)
            after = len(self._cache)
        return before - after

    # ------------------------------------------------------------------
    def export_cache(self) -> Dict[str, Dict[str, str]]:
        """Expose the raw cache for diagnostics/testing."""
        with self._lock:
            return {
                chat_id: record.to_payload()
                for chat_id, record in self._cache.items()
            }


__all__ = ["ProfileStore", "ProfileRecord"]
