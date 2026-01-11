import datetime
import hashlib
import json
import os
from typing import Optional, Tuple


def _find_repo_root(start_path: str) -> Optional[str]:
    current = os.path.abspath(start_path)
    while True:
        if os.path.isdir(os.path.join(current, ".git")):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            return None
        current = parent


def default_ledger_path() -> str:
    repo_root = _find_repo_root(os.path.dirname(__file__))
    if repo_root is None:
        repo_root = os.getcwd()
    return os.path.join(repo_root, "g", "telemetry", "idempotency_ledger.jsonl")


class IdempotencyLedger:
    def __init__(self, ledger_path: str) -> None:
        self.ledger_path = ledger_path

    def find_success(self, key: str) -> Optional[dict]:
        if not os.path.exists(self.ledger_path):
            return None
        try:
            with open(self.ledger_path, "r", encoding="utf-8") as handle:
                for line in handle:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if entry.get("idempotency_key") != key:
                        continue
                    result = entry.get("result", {})
                    if result.get("status") == "success":
                        return entry
        except FileNotFoundError:
            return None
        return None

    def append_entry(self, entry: dict) -> None:
        directory = os.path.dirname(self.ledger_path)
        if directory:
            os.makedirs(directory, exist_ok=True)
        with open(self.ledger_path, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(entry, ensure_ascii=False) + "\n")
            handle.flush()
            os.fsync(handle.fileno())

    def compute_key(self, input_path: str) -> Tuple[str, str]:
        real_path = os.path.realpath(input_path)
        with open(real_path, "rb") as handle:
            payload = handle.read()
        content_hash = hashlib.sha256(payload).hexdigest()
        key_material = f"{real_path}\n{content_hash}\ngemini_bridge:v1"
        key_hex = hashlib.sha256(key_material.encode("utf-8")).hexdigest()
        return key_hex, content_hash
