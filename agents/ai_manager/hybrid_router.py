"""
Hybrid Router V1 (Local + GG + Alter)

Code name: HYBRID_ROUTER_V1
Spec: g/reports/feature-dev/hybrid_router/251201_hybrid_router_spec_v01.md

Goal:
  - ใช้ Local + GG เป็นหลัก
  - ใช้ Alter เฉพาะกรณี client-facing / polish / translate
  - ไม่แตะ MLS / session_save โดยตรง (ให้ layer อื่นจัดการ)

NOTE:
  - จุดเรียก engine ทั้งสาม (_call_local/_call_gg/_call_alter_polish)
    ตั้งใจให้เป็น hook ให้ CLS/Liam ผูกกับ client ที่มีอยู่แล้ว
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

import yaml

try:
    from openai import OpenAI
except Exception:  # pragma: no cover - optional dependency
    OpenAI = None  # type: ignore

# Match keys defined in g/config/ai_providers.yaml
ENGINE_LOCAL = "LOCAL"
ENGINE_GG = "GG"
ENGINE_ALTER = "ALTER_LIGHT"

# Aliases for backward compatibility if callers still use older logical IDs.
_PROVIDER_MAP = {
    "local_general": ENGINE_LOCAL,
    "gg_core": ENGINE_GG,
    "alter_polish": ENGINE_ALTER,
}

LOGGER = logging.getLogger("hybrid_router")


@dataclass
class HybridResult:
    """ผลลัพธ์จาก hybrid router."""

    text: str
    engine_used: str
    alter_status: str = "skipped"  # "used" | "skipped" | "error" | "quota_exceeded"
    fallback: bool = False
    error: Optional[str] = None
    meta: Dict[str, Any] = field(default_factory=dict)

    def as_tuple(self) -> Tuple[str, Dict[str, Any]]:
        return self.text, {
            "engine_used": self.engine_used,
            "alter_status": self.alter_status,
            "fallback": self.fallback,
            "error": self.error,
            **self.meta,
        }


def hybrid_route_text(text: str, context: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
    """
    V1 Hybrid Router:

    - high sensitivity        → Local only
    - normal internal draft   → GG (core)
    - client-facing / polish  → GG/Local draft → Alter polish (ถ้าทำได้)

    Returns:
        (final_text, meta_dict)
    """
    sensitivity = (context.get("sensitivity") or "normal").lower()
    client_facing = bool(context.get("client_facing", False))
    mode = (context.get("mode") or "draft").lower()

    project_id = context.get("project_id")
    source_agent = context.get("source_agent")

    # base meta สำหรับ telemetry
    base_meta: Dict[str, Any] = {
        "project_id": project_id,
        "source_agent": source_agent,
        "mode": mode,
        "sensitivity": sensitivity,
        "client_facing": client_facing,
    }

    # --- Rule 1: Ultra-sensitive → Local only -------------------------------
    if sensitivity == "high":
        try:
            local_text = _call_local(text, context)
            result = HybridResult(
                text=local_text,
                engine_used=ENGINE_LOCAL,
                alter_status="skipped",
                fallback=False,
                meta=base_meta,
            )
            return result.as_tuple()
        except Exception as exc:  # noqa: BLE001
            # fallback → GG core (ปล่อยให้ layer บนตัดสินใจต่อ)
            gg_text = _safe_fallback_gg(text, context, error=str(exc))
            result = HybridResult(
                text=gg_text,
                engine_used=ENGINE_GG,
                alter_status="skipped",
                fallback=True,
                error=f"local_error: {exc}",
                meta=base_meta,
            )
            return result.as_tuple()

    # --- Rule 2: Normal internal work → GG core ----------------------------
    if not client_facing and mode in ("draft", "analysis"):
        try:
            gg_text = _call_gg(text, context)
            result = HybridResult(
                text=gg_text,
                engine_used=ENGINE_GG,
                alter_status="skipped",
                fallback=False,
                meta=base_meta,
            )
            return result.as_tuple()
        except Exception as exc:  # noqa: BLE001
            # fallback → local
            local_text = _safe_fallback_local(text, context, error=str(exc))
            result = HybridResult(
                text=local_text,
                engine_used=ENGINE_LOCAL,
                alter_status="skipped",
                fallback=True,
                error=f"gg_error: {exc}",
                meta=base_meta,
            )
            return result.as_tuple()

    # --- Rule 3: Client-facing / polish / translate ------------------------
    # 3.1 สร้าง draft ก่อน ด้วย GG หรือ Local ตามที่เห็นสมควร
    try:
        # เบื้องต้นใช้ GG เป็น default draft engine
        draft_text = _call_gg(text, context)
        draft_engine = ENGINE_GG
    except Exception:
        draft_text = _safe_fallback_local(text, context)
        draft_engine = ENGINE_LOCAL

    # 3.2 ลองส่งให้ Alter polish (ถ้าพลาดให้ใช้ draft เดิม)
    try:
        polished_text, alter_meta = _call_alter_polish(draft_text, context)
        result = HybridResult(
            text=polished_text,
            engine_used=ENGINE_ALTER,
            alter_status=alter_meta.get("alter_status", "used"),
            fallback=False,
            meta={**base_meta, "draft_engine": draft_engine, **alter_meta},
        )
        return result.as_tuple()
    except Exception as exc:  # noqa: BLE001
        # ถ้า Alter ล้มเหลว → ใช้ draft เดิม แต่เก็บ error
        result = HybridResult(
            text=draft_text,
            engine_used=draft_engine,
            alter_status="error",
            fallback=True,
            error=f"alter_error: {exc}",
            meta={**base_meta, "draft_engine": draft_engine},
        )
        return result.as_tuple()


# ---------------------------------------------------------------------------
# Engine call hooks
# ---------------------------------------------------------------------------

def _call_local(text: str, context: Dict[str, Any]) -> str:
    """
    Call local engine (Ollama / LM Studio).

    Uses OpenAI-compatible client pointed at Ollama (default localhost:11434).
    Falls back to returning original text on error.
    """
    provider = _provider_config(ENGINE_LOCAL)
    base_url = provider.get("base_url") or os.getenv("OLLAMA_BASE_URL") or "http://localhost:11434/v1"
    model = provider.get("model") or os.getenv("OLLAMA_MODEL") or "llama3"
    api_key = os.getenv(provider.get("api_key_env", "") or "OLLAMA_API_KEY") or "not-needed"
    client = _build_openai_client(base_url=base_url, api_key=api_key)
    if client is None:
        return text

    messages = [
        {
            "role": "system",
            "content": "You are a concise assistant for internal drafts. Keep responses brief and actionable.",
        },
        {"role": "user", "content": text},
    ]

    try:
        response = client.chat.completions.create(model=model, messages=messages)
        return _extract_choice_content(response) or text
    except Exception as exc:  # noqa: BLE001
        LOGGER.warning("local engine error: %s", exc)
        return text


def _call_gg(text: str, context: Dict[str, Any]) -> str:
    """
    Call GG (ChatGPT-based core) for reasoning / draft.
    """
    provider = _provider_config(ENGINE_GG)
    model = provider.get("model") or os.getenv("GG_MODEL") or "gpt-4o-mini"
    api_key_env = provider.get("api_key_env") or "OPENAI_API_KEY"
    api_key = os.getenv(api_key_env)
    client = _build_openai_client(api_key=api_key)
    if client is None:
        return text

    system_prompt = "You are a helpful assistant."
    if context.get("project_id"):
        system_prompt += f"\nProject: {context['project_id']}"
    if context.get("mode"):
        system_prompt += f"\nMode: {context['mode']}"

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": text},
    ]

    try:
        response = client.chat.completions.create(model=model, messages=messages)
        return _extract_choice_content(response) or text
    except Exception as exc:  # noqa: BLE001
        LOGGER.warning("gg engine error: %s", exc)
        return text


def _call_alter_polish(
    draft_text: str,
    context: Dict[str, Any],
) -> Tuple[str, Dict[str, Any]]:
    """
    Call AlterPolishService via API gateway.

    Expected behaviour (ตาม Alter spec):
      - รับ draft_text + context (tone, project_id, client_facing)
      - คืน (polished_text, meta_dict)

    ตัวอย่าง wiring ที่ CLS จะทำ:

      from agents.alter.polish_service import AlterPolishService
      service = AlterPolishService.from_default_config()
      return service.polish(draft_text, context)
    """
    from agents.alter.polish_service import AlterPolishService

    service = AlterPolishService()
    tone = context.get("tone") or "formal"
    lang = context.get("language") or context.get("target_language")
    target_lang = _normalize_language(lang)

    if target_lang and target_lang != "en":
        polished = service.polish_and_translate(draft_text, target_lang=target_lang, tone=tone)
    else:
        polished = service.polish_text(draft_text, tone=tone)

    tracker = service.tracker
    remaining = tracker.get_remaining()
    alter_status = "used" if polished and polished.strip() and polished != draft_text else "skipped"
    return polished, {
        "alter_status": alter_status,
        "quota_daily_remaining": remaining.get("daily"),
        "quota_lifetime_remaining": remaining.get("lifetime"),
    }


# ---------------------------------------------------------------------------
# Fallback helpers
# ---------------------------------------------------------------------------

def _safe_fallback_gg(text: str, context: Dict[str, Any], error: str | None = None) -> str:
    try:
        return _call_gg(text, context)
    except Exception:  # noqa: BLE001
        # ถ้า GG ก็พลาด ให้คืน text เดิม (ดีกว่าล้มทั้ง worker)
        return text


def _safe_fallback_local(text: str, context: Dict[str, Any], error: str | None = None) -> str:
    try:
        return _call_local(text, context)
    except Exception:  # noqa: BLE001
        return text


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_PROVIDER_CACHE: Dict[str, Dict[str, Any]] = {}


def _provider_config(provider_name: str) -> Dict[str, Any]:
    resolved = _PROVIDER_MAP.get(provider_name, provider_name)
    if resolved in _PROVIDER_CACHE:
        return _PROVIDER_CACHE[resolved]

    base_dir_env = os.getenv("LAC_BASE_DIR")
    base_dir = Path(base_dir_env).resolve() if base_dir_env else Path.cwd().resolve()
    config_path = base_dir / "g" / "config" / "ai_providers.yaml"

    data: Dict[str, Any] = {}
    if config_path.exists():
        try:
            with config_path.open("r", encoding="utf-8") as handle:
                loaded = yaml.safe_load(handle) or {}
            data = (loaded.get("providers") or {}).get(resolved, {}) or {}
        except Exception as exc:  # noqa: BLE001
            LOGGER.warning("failed to load provider config at %s: %s", config_path, exc)

    _PROVIDER_CACHE[resolved] = data
    return data


def _build_openai_client(base_url: Optional[str] = None, api_key: Optional[str] = None) -> Optional[Any]:
    if OpenAI is None:
        LOGGER.warning("openai client not available (missing dependency); returning None")
        return None
    if api_key is None:
        LOGGER.warning("openai api_key missing; returning None")
        return None
    try:
        return OpenAI(base_url=base_url, api_key=api_key) if base_url else OpenAI(api_key=api_key)
    except Exception as exc:  # noqa: BLE001
        LOGGER.warning("failed to init openai client: %s", exc)
        return None


def _extract_choice_content(response: Any) -> Optional[str]:
    try:
        choice = response.choices[0]
        content = getattr(choice.message, "content", None)
        return str(content).strip() if content else None
    except Exception:  # noqa: BLE001
        return None


def _normalize_language(raw: Optional[str]) -> Optional[str]:
    if not raw:
        return None
    value = str(raw).strip().lower()
    if "-" in value:
        parts = [p for p in value.split("-") if p]
        if not parts:
            return None
        # If second token is a known language code, treat it as target (e.g., th-en -> en)
        known_langs = {"en", "th", "fr", "es", "de", "ja", "zh", "ko", "vi", "id"}
        if len(parts) >= 2 and parts[1] in known_langs:
            return parts[1]
        # Otherwise use the first token (e.g., en-us -> en, zh-hans -> zh)
        return parts[0]
    return value
