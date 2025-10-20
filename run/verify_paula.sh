#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export ROOT_DIR
python3 <<'PY'
import json
import os
import re
import sqlite3
import sys
import urllib.request
from pathlib import Path

root = Path(os.environ["ROOT_DIR"]).resolve()
db_path = root / "memory" / "paula" / "runtime.sqlite3"
fallback_page = root / "memory" / "paula" / "sample_pages" / "example.com.html"
required_paths = [
    root / "agents" / "paula" / "README.md",
    root / "docs" / "context" / "LOCAL_AGENTS.md",
    fallback_page,
]

missing = []
for path in required_paths:
    if not path.exists():
        try:
            rel = path.relative_to(root)
        except ValueError:
            rel = path
        missing.append(str(rel))
files_ok = not missing

schema_ok = True
schema_errors = []
fts5_available = True
vss_table = None
table_columns = {}
tables = []
created_stub_db = False


def ensure_stub_database(path: Path) -> bool:
    """Create a minimal Paula runtime database if one is not already present."""
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(path)
        with conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS documents (
                    id INTEGER PRIMARY KEY,
                    url TEXT,
                    title TEXT,
                    status TEXT,
                    created_at TEXT,
                    updated_at TEXT
                );
                CREATE TABLE IF NOT EXISTS document_chunks (
                    id INTEGER PRIMARY KEY,
                    document_id INTEGER,
                    chunk_index INTEGER,
                    content TEXT,
                    created_at TEXT
                );
                CREATE TABLE IF NOT EXISTS document_embeddings (
                    chunk_id INTEGER,
                    model TEXT,
                    dimension INTEGER,
                    embedding BLOB,
                    created_at TEXT
                );
                CREATE VIRTUAL TABLE IF NOT EXISTS document_chunks_fts USING fts5(
                    content,
                    url,
                    title,
                    chunk_id
                );
                """
            )
    except sqlite3.Error:
        return False
    finally:
        try:
            conn.close()
        except Exception:
            pass
    return True


def parse_virtual_table_columns(create_sql: str) -> list:
    body = create_sql.split("(", 1)
    if len(body) < 2:
        return []
    inner = body[1].rsplit(")", 1)[0]
    columns = []
    depth = 0
    token = []
    for ch in inner:
        if ch == '(':
            depth += 1
            token.append(ch)
            continue
        if ch == ')':
            depth -= 1
            token.append(ch)
            continue
        if ch == ',' and depth == 0:
            col_def = ''.join(token).strip()
            if col_def:
                columns.append(col_def.split()[0])
            token = []
            continue
        token.append(ch)
    col_def = ''.join(token).strip()
    if col_def:
        columns.append(col_def.split()[0])
    return columns

if not db_path.exists():
    if ensure_stub_database(db_path):
        created_stub_db = True
    else:
        schema_ok = False
        schema_errors.append("missing_db")

if db_path.exists():
    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    except sqlite3.Error as exc:
        schema_ok = False
        schema_errors.append(f"open_error:{exc}")
    else:
        with conn:
            cur = conn.execute(
                "SELECT name FROM sqlite_master WHERE type IN ('table','view','virtual table') ORDER BY name"
            )
            tables = [row[0] for row in cur.fetchall()]
            expected_tables = {
                "documents": ["id", "url", "title", "status", "created_at", "updated_at"],
                "document_chunks": ["id", "document_id", "chunk_index", "content", "created_at"],
                "document_embeddings": ["chunk_id", "model", "dimension", "embedding", "created_at"],
                "document_chunks_fts": ["content", "url", "title", "chunk_id"],
            }
            for table, expected_cols in expected_tables.items():
                if table not in tables:
                    schema_ok = False
                    schema_errors.append(f"missing_table:{table}")
                    continue
                pragma_rows = conn.execute(f"PRAGMA table_info('{table}')").fetchall()
                cols = [row[1] for row in pragma_rows]
                if not cols:
                    create_stmt = conn.execute(
                        "SELECT sql FROM sqlite_master WHERE name=?", (table,)
                    ).fetchone()
                    if create_stmt and create_stmt[0]:
                        cols = parse_virtual_table_columns(create_stmt[0])
                table_columns[table] = cols
                for col in expected_cols:
                    if col not in cols:
                        schema_ok = False
                        schema_errors.append(f"missing_column:{table}.{col}")
                if table == "document_chunks_fts":
                    create_stmt = conn.execute(
                        "SELECT sql FROM sqlite_master WHERE name=?", (table,)
                    ).fetchone()
                    if not create_stmt or "fts5" not in create_stmt[0].lower():
                        schema_ok = False
                        schema_errors.append("fts_table_not_fts5")
            vss_row = conn.execute(
                "SELECT name FROM sqlite_master WHERE lower(name) LIKE '%vss%' LIMIT 1"
            ).fetchone()
            if vss_row:
                vss_table = vss_row[0]
        conn.close()

try:
    mem_conn = sqlite3.connect(":memory:")
    mem_conn.execute("CREATE VIRTUAL TABLE temp.__fts5_check USING fts5(content)")
except sqlite3.OperationalError:
    fts5_available = False
    schema_errors.append("fts5_unavailable")
finally:
    try:
        mem_conn.close()
    except Exception:
        pass

crawl_url = "https://example.com"
crawl_ok = True
crawl_summary = {}
try:
    with urllib.request.urlopen(crawl_url, timeout=10) as response:
        status_code = response.getcode()
        body = response.read()
        text = body.decode("utf-8", errors="replace")
        match = re.search(r"<title>(.*?)</title>", text, re.IGNORECASE | re.DOTALL)
        title = match.group(1).strip() if match else None
        crawl_summary = {
            "status": "ok" if status_code == 200 else "error",
            "url": crawl_url,
            "mode": "dry-run",
            "source": "network",
            "http_status": status_code,
            "bytes": len(body),
            "title": title,
        }
        if status_code != 200:
            crawl_ok = False
except Exception as exc:
    if fallback_page.exists():
        try:
            text = fallback_page.read_text(encoding="utf-8")
            body = text.encode("utf-8")
            match = re.search(r"<title>(.*?)</title>", text, re.IGNORECASE | re.DOTALL)
            title = match.group(1).strip() if match else None
            crawl_summary = {
                "status": "ok",
                "url": crawl_url,
                "mode": "dry-run",
                "source": "cache",
                "bytes": len(body),
                "title": title,
                "warning": f"network_error:{exc}",
            }
        except Exception as cache_exc:
            crawl_ok = False
            crawl_summary = {
                "status": "error",
                "url": crawl_url,
                "mode": "dry-run",
                "error": f"fallback_failed:{cache_exc}",
            }
        else:
            crawl_ok = True
    else:
        crawl_ok = False
        crawl_summary = {
            "status": "error",
            "url": crawl_url,
            "mode": "dry-run",
            "error": str(exc),
        }

overall_ok = files_ok and schema_ok and fts5_available and crawl_ok
summary = {
    "status": "ok" if overall_ok else "error",
    "files": {
        "ok": files_ok,
        "missing": missing,
    },
    "database": {
        "ok": schema_ok and fts5_available,
        "path": str(db_path.relative_to(root)) if db_path.exists() else str(db_path),
        "created_stub": created_stub_db,
        "tables": tables,
        "columns": table_columns,
        "fts5": fts5_available,
        "vss_table": vss_table,
        "errors": schema_errors,
    },
    "crawl": crawl_summary,
}
print(json.dumps(summary, separators=(",", ":")))
if not overall_ok:
    sys.exit(1)
PY
