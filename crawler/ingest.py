#!/usr/bin/env python3
"""Ingest NDJSON crawl output into a SQLite database."""
from __future__ import annotations

import argparse
import base64
import binascii
import importlib
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Iterable, NoReturn, Optional

@dataclass
class Document:
    doc_id: str
    url: str
    title: str
    text: str
    fetched_at: str
    content_hash: str
    source_path: str
    embedding: Optional[Any] = None

    def as_record(self) -> dict[str, Any]:
        record = {
            "doc_id": self.doc_id,
            "url": self.url,
            "title": self.title,
            "text": self.text,
            "fetched_at": self.fetched_at,
            "content_hash": self.content_hash,
            "source_path": self.source_path,
        }
        if self.embedding is not None:
            record["embedding"] = self.embedding
        return record


def iter_documents(ndjson_path: Path, hook: Optional[Callable[[dict[str, Any]], Any]]) -> Iterable[Document]:
    with ndjson_path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            payload = json.loads(line)
            embedding = None
            if hook is not None:
                try:
                    embedding = hook(payload)
                except Exception as exc:  # pragma: no cover - defensive
                    print(f"Embedding hook failed for {payload.get('url')}: {exc}")
            try:
                source = ndjson_path.relative_to(Path.cwd())
            except ValueError:
                source = ndjson_path
            yield Document(
                doc_id=payload["doc_id"],
                url=payload.get("url", ""),
                title=payload.get("title", ""),
                text=payload.get("text", ""),
                fetched_at=payload.get("fetched_at", ""),
                content_hash=payload.get("content_hash", ""),
                source_path=str(source),
                embedding=embedding,
            )


def load_embedding_hook(spec: Optional[str]) -> Optional[Callable[[dict[str, Any]], Any]]:
    if not spec:
        return None
    if ":" not in spec:
        raise ValueError("Embedding hook must be module:function")
    module_name, func_name = spec.split(":", 1)
    module = importlib.import_module(module_name)
    hook = getattr(module, func_name)
    if not callable(hook):
        raise TypeError("Embedding hook is not callable")
    return hook  # type: ignore[return-value]


def find_ndjson_files(corpus_dir: Path) -> list[Path]:
    if not corpus_dir.exists():
        return []
    return sorted(corpus_dir.glob("*/docs.ndjson"))


def ingest(ndjson_files: list[Path], database_path: Path, hook: Optional[Callable[[dict[str, Any]], Any]]) -> None:
    try:
        import sqlite_utils  # type: ignore[import]
    except ImportError:  # pragma: no cover - dependency resolution
        exit_with_error(
            "sqlite_utils is required to ingest documents. Install it with 'pip install sqlite-utils'"
        )

    database_path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite_utils.Database(database_path)
    table = db["documents"]
    inserted = False
    saw_embeddings = False
    for path in ndjson_files:
        batch = []
        for document in iter_documents(path, hook):
            record = document.as_record()
            if "embedding" in record:
                saw_embeddings = True
            batch.append(record)
        if batch:
            table.upsert_all(batch, pk="doc_id")
            inserted = True
    if not inserted:
        print("No documents to ingest")
        return
    table.create_index(["url"], if_not_exists=True)
    table.create_index(["content_hash"], if_not_exists=True)
    table.create_index(["source_path"], if_not_exists=True)
    if saw_embeddings and not table.fts:
        table.enable_fts(["text"], tokenize="porter", create_triggers=True)


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build SQLite index for crawled corpus")
    parser.add_argument(
        "--corpus-dir",
        default="g/data/corpus",
        help="Directory containing crawl output",
    )
    parser.add_argument(
        "--database",
        default="g/data/corpus.db",
        help="SQLite database path",
    )
    parser.add_argument(
        "--embedding-hook",
        default=None,
        help="Optional module:function hook returning embeddings",
    )
    parser.add_argument(
        "--payload-base64",
        default=None,
        help="Optional base64-encoded JSON payload overriding ingest options",
    )
    return parser.parse_args(argv)


def exit_with_error(message: str) -> NoReturn:
    print(message, file=sys.stderr)
    raise SystemExit(2)


def decode_payload(value: Optional[str]) -> dict[str, Any]:
    if not value:
        return {}
    try:
        raw = base64.b64decode(value)
    except (binascii.Error, ValueError) as exc:
        raise ValueError(f"Invalid base64 payload: {exc}") from exc
    try:
        decoded = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError("Payload is not valid UTF-8") from exc
    try:
        payload = json.loads(decoded)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Payload is not valid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise ValueError("Payload must be a JSON object")
    return payload


def resolve_options(args: argparse.Namespace) -> tuple[Path, Path, Optional[str]]:
    try:
        payload = decode_payload(getattr(args, "payload_base64", None))
    except ValueError as exc:
        exit_with_error(f"Failed to decode payload: {exc}")

    def override_str(key: str, current: str) -> str:
        if key not in payload or payload[key] is None:
            return current
        value = payload[key]
        if not isinstance(value, str) or not value:
            exit_with_error(f"Payload value for {key} must be a non-empty string")
        return value

    corpus_dir = Path(override_str("corpus_dir", args.corpus_dir))
    database_path = Path(override_str("database", args.database))

    embedding_hook = payload.get("embedding_hook", args.embedding_hook)
    if embedding_hook is not None and (not isinstance(embedding_hook, str) or not embedding_hook):
        exit_with_error("Payload value for embedding_hook must be a non-empty string")

    return corpus_dir, database_path, embedding_hook


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    corpus_dir, database_path, embedding_hook_spec = resolve_options(args)
    hook = load_embedding_hook(embedding_hook_spec)
    ndjson_files = find_ndjson_files(corpus_dir)
    ingest(ndjson_files, database_path, hook)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
