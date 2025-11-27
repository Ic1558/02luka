"""
Minimal reasoner backend interfaces and implementations for dev lanes.
Backends return structured answers so workers can stay pluggable.
"""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional, Protocol

try:
    import yaml
except ImportError:  # pragma: no cover - fallback if PyYAML not available
    yaml = None


class ReasonerBackend(Protocol):
    def run(self, prompt: str, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Execute a reasoning call.
        Returns a dict like:
        {
            "answer": str,
            "tokens_used": int | None,
            "model_name": str | None,
            "raw": Any (optional)
        }
        """
        ...


@dataclass
class BackendConfig:
    model: str
    endpoint: Optional[str] = None
    command: Optional[str] = None
    extra_args: Optional[list[str]] = None
    health_args: Optional[list[str]] = None

    @staticmethod
    def load(path: str) -> "BackendConfig":
        raw = Path(path).read_text()
        suffix = Path(path).suffix.lower()
        if yaml and suffix in {".yaml", ".yml"}:
            data = yaml.safe_load(raw) or {}
        else:
            data = json.loads(raw)
        return BackendConfig(
            model=data.get("model", ""),
            endpoint=data.get("endpoint"),
            command=data.get("command"),
            extra_args=data.get("extra_args", []),
            health_args=data.get("health_args"),
        )


class OssLLMBackend:
    """
    OSS backend using a configurable CLI command (e.g., ollama, deepseek_cli).
    Expects config with fields: model, command, extra_args.
    """

    def __init__(self, config_path: str = "config/dev_oss_backend.yaml"):
        self.config = BackendConfig.load(config_path)

    def run(self, prompt: str, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        cmd = [self.config.command or "echo"]
        if self.config.model:
            cmd.extend([self.config.model])
        if self.config.extra_args:
            cmd.extend(self.config.extra_args)

        cmd.append(prompt)

        try:
            completed = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
            )
            answer = completed.stdout.strip() or completed.stderr.strip()
        except (FileNotFoundError, OSError, TimeoutError) as exc:
            return {
                "answer": "",
                "model_name": self.config.model,
                "status": "error",
                "reason": str(exc),
            }

        status = "ok" if completed.returncode == 0 else "error"
        return {
            "answer": answer,
            "model_name": self.config.model,
            "tokens_used": None,
            "raw": {"returncode": completed.returncode},
            "status": status,
        }

    def health_check(self) -> Dict[str, Any]:
        cmd = [self.config.command or "echo"]
        health_args = self.config.health_args or ["--version"]
        cmd.extend(health_args)

        try:
            completed = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
            )
            status = "ok" if completed.returncode == 0 else "error"
            output = completed.stdout.strip() or completed.stderr.strip()
        except (FileNotFoundError, OSError, TimeoutError) as exc:
            return {"status": "error", "reason": str(exc)}

        return {"status": status, "output": output, "returncode": completed.returncode}


class GeminiCLIBackend:
    """
    Gemini CLI backend using a configurable command (e.g., gmx or gci).
    Config fields: model, command, extra_args.
    """

    def __init__(self, config_path: str = "config/dev_gmxcli_backend.yaml"):
        self.config = BackendConfig.load(config_path)

    def run(self, prompt: str, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        cmd = [self.config.command or "echo"]
        if self.config.model:
            cmd.extend(["-m", self.config.model])
        if self.config.extra_args:
            cmd.extend(self.config.extra_args)

        cmd.append(prompt)

        try:
            completed = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
            )
            answer = completed.stdout.strip() or completed.stderr.strip()
        except (FileNotFoundError, OSError, TimeoutError) as exc:
            return {
                "answer": "",
                "model_name": self.config.model,
                "status": "error",
                "reason": str(exc),
            }

        status = "ok" if completed.returncode == 0 else "error"
        return {
            "answer": answer,
            "model_name": self.config.model,
            "tokens_used": None,
            "raw": {"returncode": completed.returncode},
            "status": status,
        }

    def health_check(self) -> Dict[str, Any]:
        cmd = [self.config.command or "echo"]
        health_args = self.config.health_args or ["--version"]
        cmd.extend(health_args)

        try:
            completed = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
            )
            status = "ok" if completed.returncode == 0 else "error"
            output = completed.stdout.strip() or completed.stderr.strip()
        except (FileNotFoundError, OSError, TimeoutError) as exc:
            return {"status": "error", "reason": str(exc)}

        return {"status": status, "output": output, "returncode": completed.returncode}


__all__ = ["ReasonerBackend", "OssLLMBackend", "GeminiCLIBackend", "BackendConfig"]
