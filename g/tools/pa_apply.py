#!/usr/bin/env python3
"""Personal assistant apply step with approve token verification."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
from typing import Any, Dict, List

import yaml

from core.pro_docs.utils import canonical_json_dumps, sha256_digest

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


def _read_json(path: Path) -> Dict[str, Any]:
    if not path.exists():
        raise ValueError(f"Missing required file: {path}")
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def _error_output(code: str, message: str) -> Dict[str, Any]:
    return {"status": "error", "code": code, "message": message}


def _approve_token_payload(plan_hash: str, doc_spec_hash: str, validation_hash: str) -> Dict[str, Any]:
    return {
        "plan_hash": plan_hash,
        "doc_spec_hash": doc_spec_hash,
        "validation_hash": validation_hash,
    }


def _load_token(token_value: str) -> str:
    token_path = Path(token_value).expanduser().resolve()
    if token_path.exists():
        return token_path.read_text(encoding="utf-8").strip()
    return token_value.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Personal assistant apply step")
    parser.add_argument("--approve-token", required=True, help="Approve token or path to token file")
    parser.add_argument("--output-dir", required=True, help="Run output directory")
    parser.add_argument("--target-root", required=True, help="Allowed target root for future execution")
    parser.add_argument("--allowlist", help="Path to allowlist config")
    args = parser.parse_args()

    try:
        allowlist = _resolve_allowlist(Path(args.allowlist).expanduser().resolve() if args.allowlist else None)
        output_dir = Path(args.output_dir).expanduser().resolve()
        target_root = Path(args.target_root).expanduser().resolve()
        _ensure_allowed(output_dir, allowlist["output_roots"], "output_dir")
        _ensure_allowed(target_root, allowlist["project_roots"], "target_root")

        plan_path = _safe_path(output_dir, "plan.json")
        plan_data = _read_json(plan_path)
        if not isinstance(plan_data, dict) or plan_data.get("plan", {}).get("plan_version") != PA_VERSION:
            raise ValueError("Invalid plan.json or plan_version")
        plan_hash = plan_data.get("plan_hash")
        if not plan_hash:
            raise ValueError("Missing plan_hash in plan.json")

        dry_run_manifest = _read_json(_safe_path(output_dir, "dry_run/manifest.json"))
        doc_spec_path = _safe_path(output_dir, "dry_run/doc_spec.json")
        validation_path = _safe_path(output_dir, "dry_run/validation.json")

        doc_spec = _read_json(doc_spec_path)
        validation = _read_json(validation_path)

        doc_spec_hash = sha256_digest(doc_spec)
        validation_hash = sha256_digest(validation)

        manifest_doc_hash = dry_run_manifest.get("doc_spec", {}).get("hash")
        manifest_val_hash = dry_run_manifest.get("validation", {}).get("hash")
        if manifest_doc_hash != doc_spec_hash or manifest_val_hash != validation_hash:
            raise ValueError("Dry-run artifacts do not match manifest")

        approve_payload = _approve_token_payload(plan_hash, doc_spec_hash, validation_hash)
        expected_token = sha256_digest(approve_payload)
        provided_token = _load_token(args.approve_token)

        if provided_token != expected_token:
            raise ValueError("Approve token mismatch")

        apply_manifest = {
            "status": "approved",
            "plan_hash": plan_hash,
            "doc_spec_hash": doc_spec_hash,
            "validation_hash": validation_hash,
            "approve_token": provided_token,
            "target_root": str(target_root),
        }

        apply_path = _safe_path(output_dir, "apply/apply_manifest.json")
        apply_path.parent.mkdir(parents=True, exist_ok=True)
        apply_path.write_text(canonical_json_dumps(apply_manifest), encoding="utf-8")

        response = {
            "status": "ok",
            "apply_manifest": str(apply_path),
        }
        print(canonical_json_dumps(response))
        return 0
    except ValueError as exc:
        print(canonical_json_dumps(_error_output("INVALID_REQUEST", str(exc))))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
