# 02luka V4 - CLC Interface (เปลี่ยนจาก "Claude Code" → "Slot")
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List, Optional


@dataclass
class ClcConfig:
    provider: str  # "openai" | "google" | "local" | ...
    model: str
    temperature: float = 0.1
    max_tokens: int = 4096


class CLCInterface:
    def __init__(self, config: ClcConfig):
        self.config = config

    def run_code_task(
        self,
        task_spec: Dict[str, Any],
        file_slices: Dict[str, str],
    ) -> str:
        """
        task_spec: UPP object
        file_slices: mapping path -> content slice ที่เกี่ยวข้อง
        return: text (patch หรือไฟล์ใหม่) ตาม output.format
        """
        if self.config.provider == "openai":
            return self._run_openai(task_spec, file_slices)
        elif self.config.provider == "google":
            return self._run_gemini(task_spec, file_slices)
        elif self.config.provider == "local":
            return self._run_local(task_spec, file_slices)
        else:
            raise ValueError(f"Unknown provider: {self.config.provider}")

    # ----- provider specifics (TODO: คุณเติมภายหลัง) -----

    def _run_openai(self, task_spec: Dict[str, Any], file_slices: Dict[str, str]) -> str:
        # TODO: implement using openai sdk
        raise NotImplementedError

    def _run_gemini(self, task_spec: Dict[str, Any], file_slices: Dict[str, str]) -> str:
        # TODO: implement using google-genai
        raise NotImplementedError

    def _run_local(self, task_spec: Dict[str, Any], file_slices: Dict[str, str]) -> str:
        # TODO: implement using local model / ollama
        raise NotImplementedError
