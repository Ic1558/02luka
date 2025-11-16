import os, sys, glob, json, hashlib, sqlite3, time, re, yaml
from pathlib import Path
from typing import List, Dict, Any
from fastapi import FastAPI
from pydantic import BaseModel
from dotenv import load_dotenv
from rapidfuzz import fuzz
try:
    from sentence_transformers import CrossEncoder
    RERANK_OK = True
except Exception:
    CrossEncoder = None
    RERANK_OK = False

load_dotenv(os.path.expanduser("~/.config/02luka/rag.env"))
CFG_PATH = os.path.expanduser("~/02luka/g/rag/rag.config.yaml")
STORE_DIR = os.path.expanduser("~/02luka/g/rag/store")
DB_PATH = os.path.expanduser("~/02luka/g/rag/store/fts.db")

app = FastAPI(title="02LUKA RAG API")

def read_cfg() -> Dict[str, Any]:
    with open(CFG_PATH, "r") as f:
        return yaml.safe_load(f)

def ensure_db():
    Path(STORE_DIR).mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    con.execute("CREATE VIRTUAL TABLE IF NOT EXISTS docs USING fts5(path, chunk, hash, tokenize='porter')")
    con.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, val TEXT)")
    con.commit()
    return con

def sha1(b: bytes)->str: return hashlib.sha1(b).hexdigest()

def split_chunks(text: str, size: int, overlap: int):
    out, i = [], 0
    n = len(text)
    while i < n:
        out.append(text[i:i+size])
        i += max(1, size-overlap)
    return out

def should_skip(path: str, excludes: List[str]) -> bool:
    from fnmatch import fnmatch
    for g in excludes:
        if fnmatch(path, g) or fnmatch(os.path.basename(path), g):
            return True
    return False

def load_text(p: Path) -> str:
    try:
        return p.read_text(errors="ignore")
    except Exception:
        return ""

def refresh_index(cfg: Dict[str,Any]) -> Dict[str,Any]:
    con = ensure_db()
    cur = con.cursor()
    size, overlap = cfg["chunks"]["size"], cfg["chunks"]["overlap"]
    excludes = cfg.get("exclude_globs", [])
    added, updated, skipped = 0, 0, 0
    for src in cfg["sources"]:
        root = os.path.expanduser(src["path"])
        if not os.path.exists(root):
            continue
        for p in Path(root).rglob("*"):
            if not p.is_file(): continue
            if should_skip(str(p), excludes): 
                continue
            if p.suffix.lower() not in (".md",".txt",".rtf",".py",".js",".ts",".json",".html",".csv",".yaml",".yml",".sh",".zsh"):
                continue
            text = load_text(p)
            if not text.strip(): 
                continue
            h = sha1(text.encode("utf-8"))
            cur.execute("SELECT rowid, hash FROM docs WHERE path=? LIMIT 1", (str(p),))
            row = cur.fetchone()
            if row and row[1]==h:
                skipped += 1
                continue
            if row:
                cur.execute("DELETE FROM docs WHERE path=?", (str(p),))
            chunks = split_chunks(text, size, overlap)
            for ck in chunks:
                cur.execute("INSERT INTO docs(path,chunk,hash) VALUES(?,?,?)",(str(p),ck,h))
            con.commit()
            if row: updated += 1
            else: added += 1
    cur.execute("REINDEX docs"); con.commit()
    return {"added":added,"updated":updated,"skipped":skipped}

def fts_query(q: str, k: int)->List[Dict[str,Any]]:
    con = ensure_db()
    cur = con.cursor()
    cur.execute("SELECT path, chunk FROM docs WHERE docs MATCH ? LIMIT ?", (q, max(20,k*4)))
    rows = cur.fetchall()
    res = [{"path":r[0], "text":r[1]} for r in rows]
    if res:
        if RERANK_OK:
            try:
                ce = CrossEncoder("BAAI/bge-reranker-v2-m3")
                scores = ce.predict([[q, r["text"]] for r in res])
                paired = list(zip(scores, res))
                paired.sort(key=lambda x: x[0], reverse=True)
                res = [r for _, r in paired[:k]]
                return res
            except Exception:
                pass
        res.sort(key=lambda r: fuzz.partial_ratio(q, r["text"]), reverse=True)
        return res[:k]
    return res

class Query(BaseModel):
    query: str
    top_k: int | None = None

class Feedback(BaseModel):
    query: str
    expected: str
    actual: str

@app.get("/health")
def health():
    return {"ok": True, "db": os.path.exists(DB_PATH)}

@app.post("/refresh")
def api_refresh():
    cfg = read_cfg()
    return refresh_index(cfg)

@app.post("/rag_query")
def rag_query(q: Query):
    k = q.top_k or read_cfg().get("top_k", 8)
    hits = fts_query(q.query, k)
    return {"query": q.query, "top_k": k, "hits": hits}

@app.post("/feedback")
def feedback(fb: Feedback):
    Path(STORE_DIR).mkdir(parents=True, exist_ok=True)
    p = Path(STORE_DIR)/"feedback.jsonl"
    with p.open("a") as w:
        w.write(json.dumps(fb.dict(), ensure_ascii=False)+"\n")
    return {"status":"ok"}

@app.get("/stats")
def stats():
    con = ensure_db()
    cur = con.cursor()
    cur.execute("SELECT COUNT(*) FROM docs")
    total_chunks = cur.fetchone()[0]
    cur.execute("SELECT COUNT(DISTINCT path) FROM docs")
    total_files = cur.fetchone()[0]
    return {"total_chunks": total_chunks, "total_files": total_files}
