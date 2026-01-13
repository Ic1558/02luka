"""
Idempotency Ledger for Gemini Bridge (Phase 18)

Provides crash-safe, append-only JSONL ledger for tracking processed files.
Enables duplicate detection and replay safety.

Usage:
    from idempotency_ledger import IdempotencyLedger
    ledger = IdempotencyLedger()
    key = ledger.compute_key(file_path, content)
    if ledger.is_processed(key):
        return ledger.get_cached_output(key)
    # ... process file ...
    ledger.record_success(key, input_path, output_path)
"""

import os
import json
import hashlib
from datetime import datetime, timezone
from pathlib import Path


def get_repo_root():
    """Find repository root by looking for .git directory."""
    current = Path(__file__).resolve().parent
    while current != current.parent:
        if (current / ".git").exists():
            return current
        current = current.parent
    # Fallback to script directory
    return Path(__file__).resolve().parent


class IdempotencyLedger:
    """Append-only JSONL ledger for idempotent execution tracking."""
    
    EXECUTION_LANE_ID = "gemini_bridge:v1"
    
    def __init__(self, ledger_path=None):
        """Initialize ledger at specified path or default location."""
        if ledger_path is None:
            repo_root = get_repo_root()
            self.ledger_path = repo_root / "g" / "telemetry" / "idempotency_ledger.jsonl"
        else:
            self.ledger_path = Path(ledger_path)
        
        # Ensure directory exists
        self.ledger_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Load existing entries into memory for fast lookup
        self._cache = {}
        self._load_cache()
    
    def _load_cache(self):
        """Load existing ledger entries into memory."""
        if not self.ledger_path.exists():
            return
        
        try:
            with open(self.ledger_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                        key = entry.get("idempotency_key")
                        if key and entry.get("result", {}).get("status") == "success":
                            self._cache[key] = entry
                    except json.JSONDecodeError:
                        continue  # Skip corrupted lines
        except Exception:
            pass  # Silent fail on load, will rebuild on writes
    
    def compute_key(self, file_path: str, content: str) -> str:
        """
        Compute deterministic idempotency key.
        
        Key = SHA256(input_type + canonical_path + content_hash + lane_id)
        """
        # Canonical path (resolved, lowercase on case-insensitive systems)
        canonical_path = str(Path(file_path).resolve())
        
        # Content hash (strip volatile whitespace)
        content_normalized = content.strip()
        content_hash = hashlib.sha256(content_normalized.encode("utf-8")).hexdigest()
        
        # Combine components
        key_material = f"file:{canonical_path}:{content_hash}:{self.EXECUTION_LANE_ID}"
        return hashlib.sha256(key_material.encode("utf-8")).hexdigest()[:16]
    
    def is_processed(self, idempotency_key: str) -> bool:
        """Check if this key has already been successfully processed."""
        return idempotency_key in self._cache
    
    def get_cached_output(self, idempotency_key: str) -> str | None:
        """Get the output path from a previously successful execution."""
        entry = self._cache.get(idempotency_key)
        if entry:
            return entry.get("result", {}).get("output")
        return None
    
    def record_success(self, idempotency_key: str, input_path: str, output_path: str, 
                       build_sha: str = None):
        """Record a successful execution to the ledger."""
        entry = self._create_entry(
            idempotency_key=idempotency_key,
            input_path=input_path,
            status="success",
            output_path=output_path,
            build_sha=build_sha
        )
        self._append(entry)
        self._cache[idempotency_key] = entry
    
    def record_skipped(self, idempotency_key: str, input_path: str, cached_output: str):
        """Record that execution was skipped due to duplicate."""
        entry = self._create_entry(
            idempotency_key=idempotency_key,
            input_path=input_path,
            status="skipped_duplicate",
            output_path=cached_output
        )
        self._append(entry)
    
    def record_failed(self, idempotency_key: str, input_path: str, reason: str):
        """Record a failed execution attempt."""
        entry = self._create_entry(
            idempotency_key=idempotency_key,
            input_path=input_path,
            status="failed",
            reason=reason
        )
        self._append(entry)
    
    def _create_entry(self, idempotency_key: str, input_path: str, status: str,
                      output_path: str = None, reason: str = None, build_sha: str = None) -> dict:
        """Create a ledger entry."""
        # Content hash for input
        try:
            with open(input_path, "r", encoding="utf-8") as f:
                content = f.read()
            input_hash = hashlib.sha256(content.strip().encode("utf-8")).hexdigest()[:16]
        except Exception:
            input_hash = "unknown"
        
        entry = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "idempotency_key": idempotency_key,
            "input": {
                "path": str(Path(input_path).name),
                "hash": f"sha256:{input_hash}"
            },
            "action": "process_file",
            "result": {
                "status": status
            },
            "runtime": {
                "pid": os.getpid(),
                "lane": self.EXECUTION_LANE_ID
            }
        }
        
        if output_path:
            entry["result"]["output"] = str(Path(output_path).name)
        if reason:
            entry["result"]["reason"] = reason
        if build_sha:
            entry["runtime"]["build_sha"] = build_sha
        
        return entry
    
    def _append(self, entry: dict):
        """Append entry to ledger with fsync for durability."""
        try:
            with open(self.ledger_path, "a", encoding="utf-8") as f:
                f.write(json.dumps(entry) + "\n")
                f.flush()
                os.fsync(f.fileno())  # Crash-safe
        except Exception as e:
            print(f"   ⚠️ Ledger write failed: {e}")
