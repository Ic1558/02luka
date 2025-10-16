#!/usr/bin/env python3
"""Ingest NDJSON crawl output into a SQLite database."""
from __future__ import annotations

import argparse
import base64
import binascii
import importlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Iterable, Optional

import sqlite_utils


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
        help="Optional base64 encoded JSON payload overriding CLI arguments",
    )
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    payload = {}
    if args.payload_base64:
        try:
            decoded = base64.b64decode(args.payload_base64)
            payload = json.loads(decoded.decode("utf-8"))
        except (binascii.Error, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise SystemExit(f"Invalid payload data: {exc}")
        if not isinstance(payload, dict):
            raise SystemExit("Decoded payload must be a JSON object")

    corpus_dir = Path(payload.get("corpus_dir", args.corpus_dir))
    database_path = Path(payload.get("database", args.database))
    embedding_hook = payload.get("embedding_hook", args.embedding_hook)
    hook = load_embedding_hook(embedding_hook)
    ndjson_files = find_ndjson_files(corpus_dir)
    ingest(ndjson_files, database_path, hook)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
