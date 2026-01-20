#!/usr/bin/env python3
"""Personal assistant intake for plan/dry_run workflows."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List

import yaml

from core.pro_docs.engine import build_doc_spec, load_rules_config
from core.pro_docs.utils import canonical_json_dumps, sha256_digest
from core.pro_docs.validate import ValidationError, validate_doc_spec, validate_project_input

PA_VERSION = "pa_flow_v0_1"


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _load_yaml(path: Path) -> Dict[str, Any]:
    if not path.exists():
        raise ValueError(f"Missing config file: {path}")
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError("Config file must be a YAML mapping")
    return data


def _expand_path(value: str) -> Path:
    expanded = os.path.expandvars(value)
    return Path(expanded).expanduser().resolve()


def _resolve_allowlist(path: Path | None) -> Dict[str, List[Path]]:
    config_path = path or _repo_root() / "g" / "config" / "personal_assistant_paths.yaml"
    data = _load_yaml(config_path)
    project_roots = data.get("project_roots")
    output_roots = data.get("output_roots")
    if not project_roots or not output_roots:
        raise ValueError("Allowlist must define project_roots and output_roots")
    return {
        "project_roots": [_expand_path(root) for root in project_roots],
        "output_roots": [_expand_path(root) for root in output_roots],
    }


def _is_within(path: Path, roots: List[Path]) -> bool:
    for root in roots:
        try:
            path.relative_to(root)
        except ValueError:
            continue
        return True
    return False


def _ensure_allowed(path: Path, roots: List[Path], label: str) -> Path:
    if not _is_within(path, roots):
        raise ValueError(f"{label} not allowed: {path}")
    return path


def _safe_path(root: Path, relative: str) -> Path:
    target = (root / relative).resolve()
    try:
        target.relative_to(root)
    except ValueError as exc:
        raise ValueError("Output path escapes output_dir") from exc
    return target


def _load_input(input_text: str | None, input_file: str | None, allowlist: Dict[str, List[Path]]) -> Dict[str, Any]:
    if input_text and input_file:
        raise ValueError("Use --input or --input-file, not both")
    if not input_text and not input_file:
        raise ValueError("Missing input")

    if input_file:
        input_path = Path(input_file).expanduser().resolve()
        _ensure_allowed(input_path, allowlist["project_roots"], "input file path")
        with input_path.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
    else:
        input_path = Path(input_text).expanduser().resolve()
        if input_path.exists():
            _ensure_allowed(input_path, allowlist["project_roots"], "input file path")
            with input_path.open("r", encoding="utf-8") as handle:
                payload = json.load(handle)
        else:
            try:
                payload = json.loads(input_text)
            except json.JSONDecodeError as exc:
                raise ValueError("input text must be JSON or a valid file path") from exc

    if not isinstance(payload, dict):
        raise ValueError("input payload must be a JSON object")
    return payload


def _error_output(code: str, message: str) -> Dict[str, Any]:
    return {"status": "error", "code": code, "message": message}


def _build_plan(doc_spec: Dict[str, Any], validation: Dict[str, Any]) -> Dict[str, Any]:
    input_hash = doc_spec.get("audit", {}).get("input_hash")
    config_hash = doc_spec.get("audit", {}).get("config_hash")
    spec_hash = doc_spec.get("audit", {}).get("spec_hash")

    artifacts = {
        "plan": "plan.json",
        "approve_token": "approve_token.txt",
        "dry_run": [
            "dry_run/doc_spec.json",
            "dry_run/validation.json",
            "dry_run/manifest.json",
        ],
    }

    plan_payload = {
        "plan_version": PA_VERSION,
        "input_hash": input_hash,
        "config_hash": config_hash,
        "spec_hash": spec_hash,
        "artifacts": artifacts,
        "doc_spec": doc_spec,
        "validation": validation,
    }
    plan_hash = sha256_digest(plan_payload)
    return {
        "status": "ok",
        "plan_hash": plan_hash,
        "plan": plan_payload,
    }


def _write_json(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(canonical_json_dumps(payload), encoding="utf-8")


def _approve_token_payload(plan_hash: str, doc_spec_hash: str, validation_hash: str) -> Dict[str, Any]:
    return {
        "plan_hash": plan_hash,
        "doc_spec_hash": doc_spec_hash,
        "validation_hash": validation_hash,
    }


def _dry_run_artifacts(output_dir: Path, plan_data: Dict[str, Any], validation: Dict[str, Any]) -> Dict[str, Any]:
    plan_payload = plan_data["plan"]
    doc_spec = plan_payload["doc_spec"]

    doc_spec_hash = sha256_digest(doc_spec)
    validation_hash = sha256_digest(validation)

    dry_run_manifest = {
        "doc_spec": {"path": "dry_run/doc_spec.json", "hash": doc_spec_hash},
        "validation": {"path": "dry_run/validation.json", "hash": validation_hash},
    }

    _write_json(_safe_path(output_dir, "dry_run/doc_spec.json"), doc_spec)
    _write_json(_safe_path(output_dir, "dry_run/validation.json"), validation)
    _write_json(_safe_path(output_dir, "dry_run/manifest.json"), dry_run_manifest)

    approve_payload = _approve_token_payload(plan_data["plan_hash"], doc_spec_hash, validation_hash)
    approve_token = sha256_digest(approve_payload)
    token_path = _safe_path(output_dir, "approve_token.txt")
    token_path.write_text(approve_token + "\n", encoding="utf-8")

    return {
        "approve_token": approve_token,
        "approve_token_path": str(token_path),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Personal assistant plan/dry_run intake")
    parser.add_argument("--mode", choices=["plan", "dry_run"], required=True)
    parser.add_argument("--input", help="Input JSON string or file path")
    parser.add_argument("--input-file", help="Input JSON file path")
    parser.add_argument("--output-dir", required=True, help="Run output directory")
    parser.add_argument("--allowlist", help="Path to allowlist config")
    args = parser.parse_args()

    try:
        allowlist = _resolve_allowlist(Path(args.allowlist).expanduser().resolve() if args.allowlist else None)
        output_dir = Path(args.output_dir).expanduser().resolve()
        _ensure_allowed(output_dir, allowlist["output_roots"], "output_dir")
        output_dir.mkdir(parents=True, exist_ok=True)

        payload = _load_input(args.input, args.input_file, allowlist)
        config = load_rules_config()

        input_report = validate_project_input(payload, config)
        if input_report.errors:
            print(canonical_json_dumps(input_report.to_dict()))
            return 1

        try:
            doc_spec = build_doc_spec(payload, config).to_dict()
        except ValidationError as exc:
            print(canonical_json_dumps(exc.report.to_dict()))
            return 1

        validation_report = validate_doc_spec(doc_spec, config)
        if validation_report.errors:
            print(canonical_json_dumps(validation_report.to_dict()))
            return 1

        plan_data = _build_plan(doc_spec, validation_report.to_dict())
        _write_json(_safe_path(output_dir, "plan.json"), plan_data)

        response: Dict[str, Any] = {
            "status": "ok",
            "plan_hash": plan_data["plan_hash"],
            "output_dir": str(output_dir),
        }

        if args.mode == "dry_run":
            response.update(_dry_run_artifacts(output_dir, plan_data, validation_report.to_dict()))

        print(canonical_json_dumps(response))
        return 0
    except ValueError as exc:
        print(canonical_json_dumps(_error_output("INVALID_REQUEST", str(exc))))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
