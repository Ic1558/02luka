"""
Helper utilities for Alter polish integration.
"""

from __future__ import annotations

from typing import Any, Dict, Optional

from agents.alter.polish_service import AlterPolishService

_POLISH_SERVICE: Optional[AlterPolishService] = None


def get_polish_service() -> AlterPolishService:
    global _POLISH_SERVICE
    if _POLISH_SERVICE is None:
        _POLISH_SERVICE = AlterPolishService()
    return _POLISH_SERVICE


def should_polish(content: str, context: Optional[Dict[str, Any]] = None) -> bool:
    ctx = context or {}
    if not content:
        return False
    if ctx.get("polish") is True:
        return True
    if ctx.get("alter_polish_enabled") is False:
        return False
    if ctx.get("client_facing") is True:
        return True
    project = str(ctx.get("project") or "").upper()
    if project == "PD17":
        return True
    return False


def polish_if_needed(content: str, context: Optional[Dict[str, Any]] = None) -> str:
    if not should_polish(content, context):
        return content
    service = get_polish_service()
    tone = (context or {}).get("tone") or "formal"
    return service.polish_text(content, tone=tone)


def polish_and_translate_if_needed(content: str, context: Optional[Dict[str, Any]] = None) -> str:
    ctx = context or {}
    if not should_polish(content, ctx):
        return content
    target_lang = ctx.get("target_language")
    if not target_lang:
        return polish_if_needed(content, ctx)
    tone = ctx.get("tone") or "formal"
    return get_polish_service().polish_and_translate(content, target_lang=target_lang, tone=tone)


__all__ = [
    "get_polish_service",
    "should_polish",
    "polish_if_needed",
    "polish_and_translate_if_needed",
]
