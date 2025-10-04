#!/usr/bin/env python3
"""Utility script to generate text embeddings via BGE-M3 or a deterministic fallback."""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
import hashlib
from typing import List

MODEL_NAME = os.environ.get("EMBED_MODEL", "BAAI/bge-m3")

def load_model():
    try:
        from sentence_transformers import SentenceTransformer  # type: ignore
        model = SentenceTransformer(MODEL_NAME)
        return model, "bge-m3"
    except Exception:
        return None, "hash"

def hashed_embedding(text: str, dims: int = 384) -> List[float]:
    tokens = [token for token in text.lower().split() if token]
    if not tokens:
        return [0.0] * dims
    vector = [0.0] * dims
    for token in tokens:
        digest = hashlib.sha256(token.encode("utf-8")).digest()
        for idx in range(0, len(digest), 4):
            slot = int.from_bytes(digest[idx:idx + 4], "little") % dims
            sign = -1.0 if digest[idx] % 2 else 1.0
            vector[slot] += sign
    norm = math.sqrt(sum(value * value for value in vector)) or 1.0
    return [value / norm for value in vector]

def compute_embedding(text: str):
    model, backend = load_model()
    if model is None:
        return hashed_embedding(text), backend
    try:
        embedding = model.encode([text], normalize_embeddings=True)[0]
        return embedding.tolist(), backend
    except Exception:
        return hashed_embedding(text), "hash"

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate embeddings using a local model.")
    parser.add_argument("--json", action="store_true", help="Emit JSON output (default).")
    parser.add_argument("--text", type=str, help="Text to embed. Reads stdin if omitted.", default=None)
    parser.add_argument("--ping", action="store_true", help="Health check mode")
    return parser.parse_args()

def main() -> int:
    args = parse_args()
    if args.ping:
        payload = {"ok": True, "backend": MODEL_NAME}
        sys.stdout.write(json.dumps(payload))
        return 0

    text = args.text if args.text is not None else sys.stdin.read()
    if not text or not text.strip():
        sys.stderr.write("No text provided for embedding.\n")
        return 2

    embedding, backend = compute_embedding(text.strip())
    payload = {"embedding": embedding, "backend": backend, "model": MODEL_NAME}
    sys.stdout.write(json.dumps(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
