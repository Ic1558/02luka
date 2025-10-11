"""High-level orchestration for the delegation pipeline."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, Optional

from .call_model import build_request
from .logging_utils import build_idempotency_key, compute_prompt_hash, log_request_event
from .render import render_prompt
from .validate import (
    SchemaValidationError,
    load_schema,
    schema_error_summary,
    validate_response,
)

REPAIR_SYSTEM_PROMPT = """Your previous output failed JSON Schema validation. Here is the validator error:\n<ERRORS>\nRewrite the entire response so it VALIDATES. Do not add extra keys. Keep content identical where possible."""


@dataclass
class PipelineConfig:
    """Configuration container for :class:`DelegationPipeline`."""

    prompt_root: Path = Path("delegation/prompts/codex_delegation/v1.4.2")
    telemetry_path: Path = Path("delegation/telemetry/events.jsonl")
    model: str = "codex-delegation"
    max_repairs: int = 2


class DelegationPipeline:
    """Compose prompts, call the model, and enforce schema compliance."""

    def __init__(self, config: Optional[PipelineConfig] = None) -> None:
        self.config = config or PipelineConfig()
        self.prompt_root = self.config.prompt_root
        self.spec = self._load_json(self.prompt_root / "spec.json")
        self.policy = self._load_json(self.prompt_root / "policy.json")
        self.schema = load_schema(self.prompt_root / "schema.json")
        self.version = f"{self.spec.get('name', 'codex_delegation')}@{self.spec.get('version', '0.0.0')}"

    def _load_json(self, path: Path) -> Dict[str, Any]:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)

    def render_prompt(self, inputs: Dict[str, Any], request_id: str) -> str:
        """Render the deterministic prompt payload.

        The composed contract always contains the immutable specification stored
        on disk, the request-specific inputs, and the active policy envelope.
        """

        contract_json = render_prompt(self.spec, inputs, self.policy)
        contract = json.loads(contract_json)
        prompt_document = {
            "request_id": request_id,
            "prompt_version": self.version,
            "contract": contract,
        }
        return json.dumps(prompt_document, separators=(",", ":"), sort_keys=True, ensure_ascii=False)

    def run(
        self,
        api_client: Any,
        inputs: Dict[str, Any],
        request_id: str,
        user_intent: str,
    ) -> Dict[str, Any]:
        """Execute the pipeline and return the validated response.

        Args:
            api_client: Object exposing a ``create`` method that accepts the
                JSON payload produced by :func:`build_request`.
            inputs: Request-specific input document (task description, files,
                context snippets, etc.).
            request_id: Stable identifier supplied by the caller.
            user_intent: High-level intent string used for idempotency keys.
        """

        prompt_json = self.render_prompt(inputs, request_id)
        prompt_hash = compute_prompt_hash(prompt_json)
        idempotency_key = build_idempotency_key(prompt_hash, user_intent, inputs)

        request_payload = build_request(prompt_json, self.schema, self.config.model, idempotency_key)
        log_request_event(
            self.config.telemetry_path,
            {
                "request_id": request_id,
                "prompt_version": self.version,
                "prompt_hash": prompt_hash,
                "idempotency_key": idempotency_key,
                "model": self.config.model,
            },
        )

        response = api_client.create(json=request_payload)
        if isinstance(response, str):
            response_payload = json.loads(response)
        else:
            response_payload = response

        try:
            validate_response(response_payload, self.schema)
            return response_payload
        except SchemaValidationError as exc:
            return self._repair_response(
                api_client,
                response_payload,
                exc.errors,
                request_id,
                idempotency_key,
            )

    def _repair_response(
        self,
        api_client: Any,
        previous_response: Dict[str, Any],
        errors: Iterable[str],
        request_id: str,
        idempotency_key: str,
    ) -> Dict[str, Any]:
        """Attempt to repair a schema-invalid response by re-prompting the model."""

        attempt = 0
        payload = previous_response
        while attempt < self.config.max_repairs:
            attempt += 1
            repair_prompt = json.dumps(
                {
                    "previous_response": previous_response,
                    "errors": list(errors),
                },
                separators=(",", ":"),
                sort_keys=True,
                ensure_ascii=False,
            )
            request = {
                "model": self.config.model,
                "messages": [
                    {"role": "system", "content": REPAIR_SYSTEM_PROMPT.replace("<ERRORS>", schema_error_summary(errors))},
                    {"role": "user", "content": repair_prompt},
                ],
                "response_format": {
                    "type": "json_schema",
                    "json_schema": self.schema,
                },
                "extra_headers": {
                    "Idempotency-Key": idempotency_key,
                },
            }
            log_request_event(
                self.config.telemetry_path,
                {
                    "request_id": request_id,
                    "prompt_version": self.version,
                    "prompt_hash": compute_prompt_hash(repair_prompt),
                    "idempotency_key": idempotency_key,
                    "model": self.config.model,
                    "repair_attempt": attempt,
                },
            )
            response = api_client.create(json=request)
            payload = json.loads(response) if isinstance(response, str) else response
            try:
                validate_response(payload, self.schema)
                return payload
            except SchemaValidationError as exc:  # pragma: no cover - loops until exhausted
                errors = exc.errors
                continue

        raise SchemaValidationError(errors)


__all__ = ["DelegationPipeline", "PipelineConfig", "REPAIR_SYSTEM_PROMPT"]
