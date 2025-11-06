#!/usr/bin/env python3
"""
Phase 15 – FAISS/HNSW Vector Index Management
Supports: build, query, stats operations
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import List, Dict, Any, Optional

try:
    import faiss
    import numpy as np
    from sentence_transformers import SentenceTransformer
except ImportError as e:
    print(json.dumps({
        "error": "missing_dependency",
        "message": f"Failed to import required package: {e}",
        "install": "pip install faiss-cpu sentence-transformers"
    }), file=sys.stderr)
    sys.exit(1)


class VectorIndex:
    """FAISS vector index with HNSW support."""

    def __init__(
        self,
        model_name: str = "sentence-transformers/all-MiniLM-L6-v2",
        dim: int = 384,
        index_type: str = "hnsw"
    ):
        self.model_name = model_name
        self.dim = dim
        self.index_type = index_type
        self.model: Optional[SentenceTransformer] = None
        self.index: Optional[faiss.Index] = None
        self.mapping: List[Dict[str, Any]] = []

    def load_model(self):
        """Load sentence transformer model."""
        if self.model is None:
            self.model = SentenceTransformer(self.model_name)

    def build_index(
        self,
        documents: List[Dict[str, Any]],
        text_field: str = "content",
        id_field: str = "id",
        M: int = 32,
        ef_construction: int = 200
    ) -> Dict[str, Any]:
        """Build FAISS index from documents."""
        self.load_model()

        # Extract texts and build mapping
        texts = []
        self.mapping = []

        for doc in documents:
            if text_field not in doc:
                continue
            texts.append(doc[text_field])
            self.mapping.append({
                "id": doc.get(id_field, f"doc_{len(self.mapping)}"),
                "text": doc[text_field],
                **{k: v for k, v in doc.items() if k not in [text_field, id_field]}
            })

        if not texts:
            return {
                "status": "error",
                "message": "No documents with text field found",
                "count": 0
            }

        # Generate embeddings
        embeddings = self.model.encode(texts, show_progress_bar=True)
        embeddings = np.array(embeddings).astype('float32')

        # Normalize for cosine similarity
        faiss.normalize_L2(embeddings)

        # Build index
        if self.index_type == "hnsw":
            self.index = faiss.IndexHNSWFlat(self.dim, M)
            self.index.hnsw.efConstruction = ef_construction
        else:  # flat
            self.index = faiss.IndexFlatIP(self.dim)

        self.index.add(embeddings)

        return {
            "status": "success",
            "count": len(self.mapping),
            "dim": self.dim,
            "index_type": self.index_type,
            "model": self.model_name
        }

    def save(self, index_path: str, mapping_path: str):
        """Save index and mapping to disk."""
        if self.index is None:
            raise ValueError("No index to save")

        Path(index_path).parent.mkdir(parents=True, exist_ok=True)
        Path(mapping_path).parent.mkdir(parents=True, exist_ok=True)

        faiss.write_index(self.index, index_path)

        with open(mapping_path, 'w') as f:
            json.dump(self.mapping, f, indent=2)

    def load(self, index_path: str, mapping_path: str):
        """Load index and mapping from disk."""
        if not os.path.exists(index_path):
            raise FileNotFoundError(f"Index not found: {index_path}")
        if not os.path.exists(mapping_path):
            raise FileNotFoundError(f"Mapping not found: {mapping_path}")

        self.index = faiss.read_index(index_path)

        with open(mapping_path, 'r') as f:
            self.mapping = json.load(f)

    def query(
        self,
        query_text: str,
        top_k: int = 24,
        ef_search: Optional[int] = None,
        min_score: float = 0.0
    ) -> List[Dict[str, Any]]:
        """Query the index."""
        if self.index is None:
            raise ValueError("No index loaded")

        self.load_model()

        # Set ef_search for HNSW
        if ef_search is not None and hasattr(self.index, 'hnsw'):
            self.index.hnsw.efSearch = ef_search

        # Encode query
        query_embedding = self.model.encode([query_text])
        query_embedding = np.array(query_embedding).astype('float32')
        faiss.normalize_L2(query_embedding)

        # Search
        scores, indices = self.index.search(query_embedding, top_k)

        # Format results
        results = []
        for score, idx in zip(scores[0], indices[0]):
            if idx < 0 or idx >= len(self.mapping):
                continue
            if score < min_score:
                continue

            result = {
                "score": float(score),
                "index": int(idx),
                **self.mapping[idx]
            }
            results.append(result)

        return results

    def stats(self, index_path: str, mapping_path: str) -> Dict[str, Any]:
        """Get index statistics."""
        stats = {
            "index_exists": os.path.exists(index_path),
            "mapping_exists": os.path.exists(mapping_path)
        }

        if stats["index_exists"]:
            stats["index_size_bytes"] = os.path.getsize(index_path)
            stats["index_modified"] = time.ctime(os.path.getmtime(index_path))

            # Load index for more details
            try:
                idx = faiss.read_index(index_path)
                stats["ntotal"] = idx.ntotal
                stats["dim"] = idx.d
            except Exception as e:
                stats["load_error"] = str(e)

        if stats["mapping_exists"]:
            stats["mapping_size_bytes"] = os.path.getsize(mapping_path)
            try:
                with open(mapping_path, 'r') as f:
                    mapping = json.load(f)
                stats["mapping_count"] = len(mapping)
            except Exception as e:
                stats["mapping_load_error"] = str(e)

        return stats


def cmd_build(args):
    """Build index from JSONL source."""
    # Load documents
    documents = []
    with open(args.source, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                documents.append(json.loads(line))

    # Build index
    index = VectorIndex(
        model_name=args.model,
        dim=args.dim,
        index_type=args.index_type
    )

    result = index.build_index(
        documents,
        text_field=args.text_field,
        id_field=args.id_field,
        M=args.M,
        ef_construction=args.ef_construction
    )

    if result["status"] == "success":
        index.save(args.index, args.mapping)

    print(json.dumps(result))
    return 0 if result["status"] == "success" else 1


def cmd_query(args):
    """Query the index."""
    index = VectorIndex()
    index.load(args.index, args.mapping)

    results = index.query(
        args.query,
        top_k=args.top_k,
        ef_search=args.ef_search,
        min_score=args.min_score
    )

    # Output as JSON lines
    for result in results:
        print(json.dumps(result))

    return 0


def cmd_stats(args):
    """Get index statistics."""
    index = VectorIndex()
    stats = index.stats(args.index, args.mapping)
    print(json.dumps(stats, indent=2))
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="FAISS/HNSW Vector Index Management"
    )
    subparsers = parser.add_subparsers(dest='command', help='Command to run')

    # Build command
    build_parser = subparsers.add_parser('build', help='Build index')
    build_parser.add_argument('--source', required=True, help='JSONL source file')
    build_parser.add_argument('--index', required=True, help='Output index path')
    build_parser.add_argument('--mapping', required=True, help='Output mapping path')
    build_parser.add_argument('--model', default='sentence-transformers/all-MiniLM-L6-v2')
    build_parser.add_argument('--dim', type=int, default=384)
    build_parser.add_argument('--text-field', default='content')
    build_parser.add_argument('--id-field', default='id')
    build_parser.add_argument('--index-type', default='hnsw', choices=['hnsw', 'flat'])
    build_parser.add_argument('--M', type=int, default=32)
    build_parser.add_argument('--ef-construction', type=int, default=200)

    # Query command
    query_parser = subparsers.add_parser('query', help='Query index')
    query_parser.add_argument('--index', required=True, help='Index path')
    query_parser.add_argument('--mapping', required=True, help='Mapping path')
    query_parser.add_argument('--query', required=True, help='Query text')
    query_parser.add_argument('--top-k', type=int, default=24)
    query_parser.add_argument('--ef-search', type=int, default=50)
    query_parser.add_argument('--min-score', type=float, default=0.0)

    # Stats command
    stats_parser = subparsers.add_parser('stats', help='Get index statistics')
    stats_parser.add_argument('--index', required=True, help='Index path')
    stats_parser.add_argument('--mapping', required=True, help='Mapping path')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    if args.command == 'build':
        return cmd_build(args)
    elif args.command == 'query':
        return cmd_query(args)
    elif args.command == 'stats':
        return cmd_stats(args)
    else:
        parser.print_help()
        return 1


if __name__ == '__main__':
    sys.exit(main())
