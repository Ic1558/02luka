#!/usr/bin/env python3
"""
then / 02luka RAG API (stdlib-only)

Provides a minimal HTTP JSON API backed by the existing SQLite FTS5 database:
  g/rag/store/fts.db

Endpoints:
  - GET /health
  - GET /search?q=...&limit=10
"""

from __future__ import annotations

import argparse
import json
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


def repo_root() -> Path:
    # g/rag/server.py -> parents[2] = repo root
    return Path(__file__).resolve().parents[2]


def open_db(db_path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    return conn


def count_docs(conn: sqlite3.Connection) -> int:
    row = conn.execute("SELECT count(*) AS n FROM docs").fetchone()
    return int(row["n"]) if row else 0


def search_docs(conn: sqlite3.Connection, query: str, limit: int) -> list[dict[str, Any]]:
    q = query.strip()
    if not q:
        return []

    # Default to a safe phrase query to avoid FTS syntax errors on punctuation like "-" or ":".
    safe = q.replace('"', '""')
    match_q = f"\"{safe}\""

    # FTS5 best-effort:
    # - bm25(docs) lower is better
    # - snippet(docs, 1, ...) returns a short excerpt from column 1 (chunk)
    rows = conn.execute(
        """
        SELECT
          path,
          snippet(docs, 1, '', '', ' … ', 16) AS snippet,
          bm25(docs) AS score,
          hash
        FROM docs
        WHERE docs MATCH ?
        ORDER BY score
        LIMIT ?
        """,
        (match_q, int(limit)),
    ).fetchall()

    out: list[dict[str, Any]] = []
    for r in rows:
        out.append(
            {
                "path": r["path"],
                "snippet": r["snippet"],
                "score": r["score"],
                "hash": r["hash"],
            }
        )
    return out


class Handler(BaseHTTPRequestHandler):
    server_version = "02luka-rag-stdlib/0.1"

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A003
        # Keep launchd logs quieter; uncomment for verbose debugging.
        return

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"

        db_path: Path = self.server.db_path  # type: ignore[attr-defined]

        if path == "/health":
            with open_db(db_path) as conn:
                docs = count_docs(conn)
            self._send_json(
                200,
                {
                    "status": "ok",
                    "db": str(db_path),
                    "docs": docs,
                },
            )
            return

        if path == "/search":
            qs = parse_qs(parsed.query)
            q = (qs.get("q") or [""])[0]
            limit_raw = (qs.get("limit") or ["10"])[0]
            try:
                limit = max(1, min(50, int(limit_raw)))
            except Exception:
                limit = 10

            try:
                with open_db(db_path) as conn:
                    results = search_docs(conn, q, limit)
                self._send_json(200, {"q": q, "limit": limit, "results": results})
            except sqlite3.OperationalError as e:
                self._send_json(400, {"error": f"bad_query: {e}", "q": q})
            return

        self._send_json(404, {"error": "not_found"})


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--db", default="", help="Path to fts.db (default: g/rag/store/fts.db)")
    args = ap.parse_args()

    root = repo_root()
    db_path = Path(args.db).expanduser() if args.db else (root / "g" / "rag" / "store" / "fts.db")
    if not db_path.exists():
        raise SystemExit(f"fts.db not found: {db_path}")

    httpd = ThreadingHTTPServer((args.host, int(args.port)), Handler)
    httpd.db_path = db_path  # type: ignore[attr-defined]
    httpd.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
