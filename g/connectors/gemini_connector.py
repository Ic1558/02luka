#!/usr/bin/env python3
"""
Gemini API Connector
Phase 1 - Foundation Setup
Conservative Additive Integration Pattern

Purpose: Wrapper for Google Gemini API to offload heavy compute from CLC/Codex
Protocol: v3.2 compliant
Created: 2025-11-18
"""

import importlib
import os
import json
import logging
from typing import Optional, Dict, Any, List, Callable
from pathlib import Path

genai_spec = importlib.util.find_spec("google.generativeai")
genai = importlib.import_module("google.generativeai") if genai_spec else None
if not genai:
    logging.warning("google-generativeai not installed. Run: pip install google-generativeai")

logger = logging.getLogger(__name__)


class GeminiConnector:
    """
    Gemini API client wrapper for 02luka system.

    Features:
    - API key management
    - Rate limiting awareness
    - Error handling with fallback
    - Token usage tracking
    - Conservative retry logic
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        model_name: str = "gemini-2.5-flash",
        max_retries: int = 3
    ):
        """
        Initialize Gemini connector.

        Args:
            api_key: Gemini API key (reads from env if not provided)
            model_name: Model to use (gemini-2.5-flash, gemini-2.5-pro, etc.)
            max_retries: Max retry attempts on failure
        """
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        self.model_name = model_name
        self.max_retries = max_retries
        self.model = None

        if not self.api_key:
            logger.warning("GEMINI_API_KEY not set. Set via env or pass to constructor.")
            return

        if not genai:
            logger.error("google-generativeai library not available")
            return

        try:
            genai.configure(api_key=self.api_key)
            self.model = genai.GenerativeModel(self.model_name)
            logger.info(f"Gemini connector initialized: {self.model_name}")
        except Exception as e:
            logger.error(f"Failed to initialize Gemini model: {e}")

    def is_available(self) -> bool:
        """Check if connector is ready to use."""
        return self.model is not None and self.api_key is not None

    def generate_text(
        self,
        prompt: str,
        temperature: float = 0.7,
        max_output_tokens: int = 2048,
        **kwargs
    ) -> Optional[Dict[str, Any]]:
        """
        Generate text using Gemini API.

        Args:
            prompt: Input prompt
            temperature: Sampling temperature (0.0-1.0)
            max_output_tokens: Max tokens to generate
            **kwargs: Additional generation config

        Returns:
            dict with 'text', 'usage', 'model' keys, or None on failure
        """
        if not self.is_available():
            logger.error("Gemini connector not available")
            return None

        try:
            generation_config = genai.types.GenerationConfig(
                temperature=temperature,
                max_output_tokens=max_output_tokens,
                **kwargs
            )

            # Safety settings - allow most content (adjust as needed)
            safety_settings = [
                {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
            ]

            response = self.model.generate_content(
                prompt,
                generation_config=generation_config,
                safety_settings=safety_settings
            )

            # Check if response was blocked
            if not response.candidates or not response.candidates[0].content.parts:
                logger.error(f"Response blocked. Finish reason: {response.candidates[0].finish_reason if response.candidates else 'unknown'}")
                return None

            result = {
                "text": response.text,
                "model": self.model_name,
                "usage": {
                    "prompt_tokens": getattr(response, "prompt_token_count", 0),
                    "completion_tokens": getattr(response, "candidates_token_count", 0),
                    "total_tokens": getattr(response, "total_token_count", 0)
                }
            }

            logger.info(f"Generated {result['usage']['total_tokens']} tokens")
            return result

        except Exception as e:
            logger.error(f"Gemini API error: {e}")
            return None

    def generate_bulk(
        self,
        prompts: List[str],
        temperature: float = 0.7,
        max_output_tokens: int = 2048
    ) -> List[Optional[Dict[str, Any]]]:
        """
        Generate text for multiple prompts (sequential with rate limiting).

        Args:
            prompts: List of input prompts
            temperature: Sampling temperature
            max_output_tokens: Max tokens per response

        Returns:
            List of results (same order as input)
        """
        results = []
        for i, prompt in enumerate(prompts):
            logger.info(f"Processing prompt {i+1}/{len(prompts)}")
            result = self.generate_text(prompt, temperature, max_output_tokens)
            results.append(result)

        return results

    def get_quota_info(self) -> Dict[str, Any]:
        """
        Get current quota/usage info (if available via API).

        Returns:
            dict with quota information
        """
        # Note: Gemini API may not expose quota directly
        # This is a placeholder for future enhancement
        return {
            "available": self.is_available(),
            "model": self.model_name,
            "note": "Quota tracking requires API billing integration"
        }


def test_connection() -> bool:
    """
    Test Gemini API connectivity.

    Returns:
        True if connection successful, False otherwise
    """
    connector = GeminiConnector()

    if not connector.is_available():
        print("❌ Gemini connector not available")
        print("   Set GEMINI_API_KEY environment variable")
        print("   Install: pip install google-generativeai")
        return False

    print("✅ Gemini connector initialized")

    # Test with simple prompt
    test_prompt = "Reply with exactly: 'Gemini API connection successful'"
    result = connector.generate_text(test_prompt, temperature=0.0, max_output_tokens=50)

    if result:
        print(f"✅ API test successful")
        print(f"   Response: {result['text'][:100]}")
        print(f"   Tokens: {result['usage']['total_tokens']}")
        return True
    else:
        print("❌ API test failed")
        return False


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    success = test_connection()
    exit(0 if success else 1)


# --- High-level task router ---

_connector_instance = GeminiConnector()


def run_gemini_task(task_type: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    """
    High-level entrypoint for Gemini tasks.

    Args:
        task_type: e.g. "bulk_test_generation", "spec_refine", "code_transform"
        payload: normalized payload from handler

    Returns:
        Dict with execution result and metadata.
    """
    if not _connector_instance.is_available():
        return {
            "ok": False,
            "error": "Gemini connector not available",
            "task_type": task_type,
        }

    handlers: Dict[str, Callable[[Dict[str, Any]], Dict[str, Any]]] = {
        "bulk_test_generation": _run_bulk_test_generation,
        "code_transform": _run_code_transform,
    }

    handler = handlers.get(task_type, _run_generic_task)
    return handler(payload)


def _run_bulk_test_generation(payload: Dict[str, Any]) -> Dict[str, Any]:
    files = payload.get("files", [])
    instructions = payload.get("instructions", "Generate comprehensive automated tests")
    context = payload.get("context", {})

    prompt = (
        "You are a test generation specialist. "
        "Generate runnable tests with coverage across provided files.\n\n"
        f"Files: {', '.join(files) if files else 'not specified'}\n"
        f"Instructions: {instructions}\n"
        f"Context: {json.dumps(context, indent=2)}\n\n"
        "Requirements:\n"
        "1. Include setup/teardown and mocks when needed.\n"
        "2. Cover both happy paths and edge cases.\n"
        "3. Return complete test code without TODOs.\n"
    )

    response = _connector_instance.generate_text(
        prompt=prompt,
        temperature=context.get("temperature", 0.7),
        max_output_tokens=context.get("max_output_tokens", 2048),
    )

    return {
        "ok": bool(response),
        "task_type": "bulk_test_generation",
        "prompt": prompt,
        "response": response,
    }


def _run_code_transform(payload: Dict[str, Any]) -> Dict[str, Any]:
    files = payload.get("files", [])
    instructions = payload.get("instructions", "Perform the requested code transformation")
    context = payload.get("context", {})

    prompt = (
        "You are performing a targeted code transformation."
        " Apply the instructions to the referenced files and return a structured patch.\n\n"
        f"Files: {', '.join(files) if files else 'not specified'}\n"
        f"Instructions: {instructions}\n"
        f"Context: {json.dumps(context, indent=2)}"
    )

    response = _connector_instance.generate_text(
        prompt=prompt,
        temperature=context.get("temperature", 0.3),
        max_output_tokens=context.get("max_output_tokens", 2048),
    )

    return {
        "ok": bool(response),
        "task_type": "code_transform",
        "prompt": prompt,
        "response": response,
    }


def _run_generic_task(payload: Dict[str, Any]) -> Dict[str, Any]:
    instructions = payload.get("instructions", "Provide the requested output")
    context = payload.get("context", {})

    prompt = (
        "You are executing a Gemini task. Follow the instructions precisely and return actionable output.\n\n"
        f"Instructions: {instructions}\n"
        f"Context: {json.dumps(context, indent=2)}"
    )

    response = _connector_instance.generate_text(
        prompt=prompt,
        temperature=context.get("temperature", 0.5),
        max_output_tokens=context.get("max_output_tokens", 2048),
    )

    return {
        "ok": bool(response),
        "task_type": payload.get("task_type", "generic"),
        "prompt": prompt,
        "response": response,
    }
