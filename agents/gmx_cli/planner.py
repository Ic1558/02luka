# agents/gmx_cli/planner.py
"""
Core GMX planning logic. Converts a natural language prompt into a
structured GMX JSON plan using the GeminiConnector.
"""
from __future__ import annotations
import json
import os
import sys
from pathlib import Path
from typing import Dict, Any

# Assume this script is run from a context where project root is in path
from g.connectors.gemini_connector import GeminiConnector

SCRIPT_DIR = Path(__file__).parent.resolve()
PERSONA_PROMPT_PATH = SCRIPT_DIR / "PERSONA_PROMPT.md"
GMX_MODEL = os.environ.get("GMX_MODEL", "gemini-2.5-flash")

class GMXPlanner:
    """Handles the core reasoning for GMX planning."""

    def __init__(self):
        self.system_prompt = self._load_system_prompt()
        self.connector = GeminiConnector(model_name=GMX_MODEL)

    def _load_system_prompt(self) -> str:
        try:
            return PERSONA_PROMPT_PATH.read_text(encoding='utf-8')
        except FileNotFoundError:
            return "You are the GMX Planner. Your only job is to create a GMX JSON plan."

    def create_plan_from_prompt(self, user_prompt: str) -> Dict[str, Any]:
        """Generates a GMX plan by calling the Gemini API."""
        if not self.connector.is_available():
            return {"status": "ERROR", "reason": "GMXPlanner cannot connect to Gemini."}

        full_prompt = f"{self.system_prompt}\n\nUSER REQUEST: {user_prompt}"
        response = self.connector.generate_text(full_prompt, temperature=0.2)

        if "error" in response:
            return {"status": "ERROR", "reason": response["error"]}
        
        try:
            return json.loads(response["text"])
        except json.JSONDecodeError as e:
            return {"status": "ERROR", "reason": f"GMX plan from Gemini API was not valid JSON. Error: {e!r}"}
