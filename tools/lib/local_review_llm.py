from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass
from typing import Any, Dict, Optional


class LLMError(RuntimeError):
    """Raised when LLM calls fail."""


@dataclass
class LLMConfig:
    provider: str
    model: str
    max_tokens: int
    temperature: float
    max_calls: int


class LLMClient:
    """Anthropic-backed LLM client with a simple contract."""

    def __init__(self, config: LLMConfig) -> None:
        self.config = config
        self.calls_made = 0
        self._client = None
        if config.provider != "anthropic":
            raise LLMError(f"Unsupported provider: {config.provider}")
        self._init_anthropic()

    def _init_anthropic(self) -> None:
        # Load from .env.local (following codebase pattern)
        try:
            from pathlib import Path
            from dotenv import load_dotenv
            
            # Determine project root (tools/lib/ -> tools/ -> repo root)
            PROJECT_ROOT = Path(__file__).parent.parent.parent
            
            # Try .env first, then .env.local (following g/tools/gmx_cli.py pattern)
            env_path = PROJECT_ROOT / ".env"
            if env_path.exists():
                load_dotenv(dotenv_path=env_path, override=True)
            else:
                env_local_path = PROJECT_ROOT / ".env.local"
                if env_local_path.exists():
                    load_dotenv(dotenv_path=env_local_path, override=True)
        except ImportError:
            # python-dotenv not installed, rely on system environment
            pass
        
        try:
            import anthropic  # type: ignore
        except ImportError as exc:
            raise LLMError("anthropic package not installed. Install via pip.") from exc

        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            raise LLMError("ANTHROPIC_API_KEY is not set.")
        self._client = anthropic.Anthropic(api_key=api_key)

    def complete(self, system_prompt: str, user_prompt: str) -> Dict[str, Any]:
        if self.calls_made >= self.config.max_calls:
            raise LLMError("max_review_calls_per_run exceeded")

        if not self._client:
            raise LLMError("LLM client not initialized")

        self.calls_made += 1
        logging.debug("Calling Anthropic model=%s", self.config.model)

        try:
            resp = self._client.messages.create(
                model=self.config.model,
                max_tokens=self.config.max_tokens,
                temperature=self.config.temperature,
                system=system_prompt,
                messages=[{"role": "user", "content": user_prompt}],
            )
        except Exception as exc:  # noqa: BLE001
            raise LLMError(str(exc)) from exc

        # For Claude v3.5: response.content is a list of parts; extract text
        content_text = ""
        if hasattr(resp, "content"):
            parts = getattr(resp, "content")
            if parts and hasattr(parts[0], "text"):
                content_text = parts[0].text
            elif isinstance(parts, list) and parts and isinstance(parts[0], dict):
                content_text = parts[0].get("text", "")  # type: ignore[index]

        if not content_text:
            raise LLMError("Empty response from LLM")

        try:
            return json.loads(content_text)
        except json.JSONDecodeError as exc:
            raise LLMError(f"Invalid JSON from LLM: {exc}") from exc
