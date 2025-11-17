#!/usr/bin/env python3
"""Local Patch Engine Safe Idempotent Patch helper."""

import sys
import pathlib
import json
import yaml

BASE_PATH = (pathlib.Path(__file__).resolve().parent.parent)
SAFE_ROOTS = {"g", "core", "LaunchAgents", "tools", "apps", "docs", "config", "etc", "server", "scripts", "bin", "web", "bridge", "analytics", "memory", "telemetry", "wo", "work_orders", "logs", "mls", "knowledge"}


def _load_patch(path: pathlib.Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError("Patch file must contain a mapping at the top level")
    if "ops" not in data or not isinstance(data["ops"], list):
        raise ValueError("Patch file must include an 'ops' list")
    return data


def _ensure_safe_path(relative: str) -> pathlib.Path:
    rel_path = pathlib.Path(relative)
    if rel_path.is_absolute():
        raise ValueError(f"Absolute paths are not allowed: {relative}")
    if ".." in rel_path.parts:
        raise ValueError(f"Parent directory references are not allowed: {relative}")
    top = rel_path.parts[0]
    if top not in SAFE_ROOTS:
        raise ValueError(f"Forbidden path outside allowed roots: {relative}")
    resolved = (BASE_PATH / rel_path).resolve()
    if BASE_PATH not in resolved.parents and resolved != BASE_PATH:
        raise ValueError(f"Resolved path escapes base directory: {relative}")
    resolved.parent.mkdir(parents=True, exist_ok=True)
    return resolved


def _append_content(target: pathlib.Path, content: str) -> bool:
    existing = target.read_text(encoding="utf-8") if target.exists() else ""
    if content in existing:
        return False
    with target.open("a", encoding="utf-8") as handle:
        if existing and not existing.endswith("\n"):
            handle.write("\n")
        handle.write(content)
        if not content.endswith("\n"):
            handle.write("\n")
    return True


def _replace_block(target: pathlib.Path, match: str, content: str) -> bool:
    if not target.exists():
        raise FileNotFoundError(f"Target for replace_block does not exist: {target}")
    text = target.read_text(encoding="utf-8")
    if content in text:
        return False
    if match not in text:
        raise ValueError(f"Match text not found for replace_block: {match}")
    new_text = text.replace(match, content, 1)
    target.write_text(new_text, encoding="utf-8")
    return True


def _insert_relative(target: pathlib.Path, match: str, content: str, *, before: bool) -> bool:
    if not target.exists():
        raise FileNotFoundError(f"Target for insert does not exist: {target}")
    text = target.read_text(encoding="utf-8")
    if content in text:
        return False
    index = text.find(match)
    if index == -1:
        raise ValueError(f"Match text not found for insert: {match}")
    insertion_point = index if before else index + len(match)
    new_text = text[:insertion_point] + content + text[insertion_point:]
    target.write_text(new_text, encoding="utf-8")
    return True


MODE_HANDLERS = {
    "append": _append_content,
    "replace_block": _replace_block,
    "insert_before": lambda t, m, c: _insert_relative(t, m, c, before=True),
    "insert_after": lambda t, m, c: _insert_relative(t, m, c, before=False),
}


def apply_op(op: dict) -> bool:
    if not isinstance(op, dict):
        raise ValueError("Each op must be a mapping")
    if "path" not in op:
        raise ValueError("Each op must include a 'path'")

    path = op["path"]
    mode = op.get("mode", "append")
    content = op.get("content", "")
    match = op.get("match", "")

    target = _ensure_safe_path(path)

    if mode not in MODE_HANDLERS:
        raise ValueError(f"Unsupported mode: {mode}")

    handler = MODE_HANDLERS[mode]

    if mode == "append":
        return handler(target, content)

    if mode in {"replace_block", "insert_before", "insert_after"}:
        if not match:
            raise ValueError(f"Mode '{mode}' requires a 'match' value")
        return handler(target, match, content)

    raise ValueError(f"Unhandled mode: {mode}")


def main(patch_file: str) -> None:
    patch_path = pathlib.Path(patch_file).resolve()
    patch_data = _load_patch(patch_path)

    results = []
    for op in patch_data.get("ops", []):
        changed = apply_op(op)
        results.append({"path": op.get("path"), "mode": op.get("mode", "append"), "changed": changed})

    summary_path = BASE_PATH / "mls" / "ledger" / "lpe_last_result.json"
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(
        json.dumps({"results": results}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: lpe_sip_apply.py PATCH.yaml", file=sys.stderr)
        sys.exit(1)
    main(sys.argv[1])
