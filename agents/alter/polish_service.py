"""
Alter polish and translation service (text-only).

Uses Alter's OpenAI-compatible gateway, enforces dual quota checks,
and degrades gracefully by returning the original text on any failure.
"""

from __future__ import annotations

import logging
import os
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml
from agents.alter.usage_tracker import UsageTracker

try:
    from openai import OpenAI
except Exception:  # pragma: no cover - handled via injected client in tests
    OpenAI = None  # type: ignore

LOGGER = logging.getLogger("alter_polish_service")
DEFAULT_MAX_RETRIES = 2
DEFAULT_BACKOFF_BASE = 1.5


def _resolve_base_dir() -> Path:
    base_dir = os.getenv("LAC_BASE_DIR")
    return Path(base_dir).resolve() if base_dir else Path.cwd().resolve()


class AlterPolishService:
    """Polish/translate text via Alter API, with quota guard and safe fallbacks."""

    def __init__(
        self,
        base_dir: Optional[Path] = None,
        tracker: Optional[UsageTracker] = None,
        client: Optional[Any] = None,
        config_path: Optional[Path] = None,
        max_retries: int = DEFAULT_MAX_RETRIES,
        backoff_base: float = DEFAULT_BACKOFF_BASE,
    ):
        self.base_dir = Path(base_dir).resolve() if base_dir else _resolve_base_dir()
        self.config_path = Path(config_path) if config_path else self.base_dir / "g" / "config" / "ai_providers.yaml"
        self.tracker = tracker or UsageTracker(base_dir=self.base_dir)
        self.max_retries = max_retries
        self.backoff_base = backoff_base

        config = self._load_config()
        self.model = config.get("model", "Claude#claude-3-haiku-20240307")
        self.base_url = config.get("base_url", "https://alterhq.com/api/v1")
        api_key_env = config.get("api_key_env", "ALTER_API_KEY")
        self.api_key = os.getenv(api_key_env)
        self._client = client or self._build_client()

    def polish_text(self, text: str, tone: str = "formal") -> str:
        if not text:
            return text
        messages = self._build_polish_messages(text, tone)
        result = self._invoke_api(messages, operation="polish_text", original=text)
        return result if result is not None else text

    def translate(self, text: str, target_lang: str) -> str:
        if not text or not target_lang:
            return text
        messages = self._build_translate_messages(text, target_lang)
        result = self._invoke_api(messages, operation="translate", original=text)
        return result if result is not None else text

    def polish_and_translate(self, text: str, target_lang: str, tone: str = "formal") -> str:
        if not text or not target_lang:
            return text
        polished = self.polish_text(text, tone=tone)
        if not polished:
            return text
        translated = self.translate(polished, target_lang)
        return translated if translated is not None else text

    def _load_config(self) -> Dict[str, Any]:
        if not self.config_path.exists():
            LOGGER.warning("Alter config not found at %s; using defaults", self.config_path)
            return {}
        try:
            with self.config_path.open("r", encoding="utf-8") as handle:
                data = yaml.safe_load(handle) or {}
            return data.get("providers", {}).get("ALTER_LIGHT", {}) or {}
        except Exception as exc:  # pragma: no cover - defensive
            LOGGER.error("Failed to load Alter config: %s", exc)
            return {}

    def _build_client(self) -> Optional[Any]:
        if OpenAI is None:
            LOGGER.error("openai library not available; Alter client disabled")
            return None
        if not self.api_key:
            LOGGER.error("ALTER_API_KEY not set; Alter client disabled")
            return None
        try:
            return OpenAI(base_url=self.base_url, api_key=self.api_key)
        except Exception as exc:  # pragma: no cover - defensive
            LOGGER.error("Failed to initialize Alter client: %s", exc)
            return None

    def _invoke_api(self, messages: List[Dict[str, str]], operation: str, original: str) -> Optional[str]:
        if not self._client:
            LOGGER.error("Alter client unavailable; skipping %s", operation)
            return None

        quota = self.tracker.check_quota(1)
        if not quota.get("lifetime", False):
            LOGGER.error("Alter lifetime quota exceeded; skipping %s", operation)
            return None
        if not quota.get("daily", False):
            LOGGER.warning("Alter daily quota exceeded; skipping %s", operation)
            return None

        attempt = 0
        while attempt <= self.max_retries:
            try:
                response = self._client.chat.completions.create(model=self.model, messages=messages)
                content = self._extract_content(response)
                if content is None:
                    LOGGER.error("Empty Alter response for %s; returning original", operation)
                    return None
                self.tracker.record_usage(1)
                return content
            except Exception as exc:
                attempt += 1
                if attempt > self.max_retries:
                    LOGGER.error("Alter %s failed after retries: %s", operation, exc)
                    return None
                sleep_time = self.backoff_base ** attempt
                LOGGER.warning("Alter %s error (%s); retrying in %.2fs", operation, exc, sleep_time)
                time.sleep(sleep_time)
        return None

    def _extract_content(self, response: Any) -> Optional[str]:
        try:
            choice = response.choices[0]
            content = getattr(choice.message, "content", None)
            if isinstance(content, list):
                # OpenAI SDK may return a list of content parts
                parts = [part.get("text", "") if isinstance(part, dict) else str(part) for part in content]
                return "".join(parts).strip()
            if content is None:
                return None
            return str(content).strip()
        except Exception:  # pragma: no cover - defensive
            return None

    def _build_polish_messages(self, text: str, tone: str) -> List[Dict[str, str]]:
        return [
            {
                "role": "system",
                "content": (
                    "You are a professional editor. Improve clarity, correctness, and structure while preserving intent. "
                    f"Use a {tone} tone."
                ),
            },
            {"role": "user", "content": text},
        ]

    def _build_translate_messages(self, text: str, target_lang: str) -> List[Dict[str, str]]:
        return [
            {
                "role": "system",
                "content": (
                    "Translate the following text accurately. Preserve meaning and tone. "
                    f"Output language: {target_lang}"
                ),
            },
            {"role": "user", "content": text},
        ]


__all__ = ["AlterPolishService"]
