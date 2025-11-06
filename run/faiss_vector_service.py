#!/usr/bin/env python3
"""
FAISS/HNSW Vector Index Service
================================
Phase 15+ Enhancement - Vector Search with FAISS
Part of Issue #184: FAISS/HNSW Vector Index + Kim Proxy Gateway Integration

This service provides efficient vector similarity search using FAISS with HNSW index.
It replaces the simple text search from Phase 14.4 with semantic vector search.

Architecture:
- FAISS library for vector similarity search
- HNSW (Hierarchical Navigable Small World) algorithm
- OpenAI text-embedding-3-small for embeddings (1536 dimensions)
- Flask API for query endpoints

Endpoints:
- POST /vector_query - Semantic search with embeddings
- POST /ingest - Add documents to vector index
- GET /health - Health check
- GET /stats - Index statistics

WO-ID: WO-251107-PHASE-15-FAISS-HNSW
"""

import os
import json
import time
import hashlib
from pathlib import Path
from typing import List, Dict, Any, Optional
from datetime import datetime

import numpy as np
import faiss
from flask import Flask, request, jsonify
from openai import OpenAI

# Configuration
INDEX_DIR = Path.home() / "02luka" / "memory" / "vector_index"
INDEX_FILE = INDEX_DIR / "faiss_hnsw.index"
METADATA_FILE = INDEX_DIR / "metadata.jsonl"
TELEMETRY_FILE = Path.home() / "02luka" / "g" / "telemetry_unified" / "unified.jsonl"

EMBEDDING_MODEL = "text-embedding-3-small"
EMBEDDING_DIM = 1536
HNSW_M = 32  # Number of connections per layer
HNSW_EF_CONSTRUCTION = 200  # Exploration factor during construction
HNSW_EF_SEARCH = 100  # Exploration factor during search

PORT = 8766
HOST = "127.0.0.1"

# Initialize Flask app
app = Flask(__name__)

# Global state
faiss_index: Optional[faiss.Index] = None
metadata_store: List[Dict[str, Any]] = []
openai_client: Optional[OpenAI] = None


def emit_telemetry(event: str, data: Dict[str, Any]):
    """Emit telemetry event in Phase 14.2 unified format."""
    telemetry = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "event": event,
        "agent": "faiss_vector_service",
        "phase": "15",
        "work_order": "WO-251107-PHASE-15-FAISS-HNSW",
        "data": data,
        "__source": "faiss_vector_service",
        "__normalized": True
    }

    try:
        TELEMETRY_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(TELEMETRY_FILE, "a") as f:
            f.write(json.dumps(telemetry) + "\n")
    except Exception as e:
        print(f"Warning: Failed to emit telemetry: {e}")


def initialize_index():
    """Initialize or load FAISS index."""
    global faiss_index, metadata_store, openai_client

    # Initialize OpenAI client
    openai_client = OpenAI()

    INDEX_DIR.mkdir(parents=True, exist_ok=True)

    # Load existing index if available
    if INDEX_FILE.exists() and METADATA_FILE.exists():
        try:
            faiss_index = faiss.read_index(str(INDEX_FILE))

            # Load metadata
            metadata_store = []
            with open(METADATA_FILE, "r") as f:
                for line in f:
                    metadata_store.append(json.loads(line.strip()))

            emit_telemetry("faiss.index.loaded", {
                "index_file": str(INDEX_FILE),
                "num_vectors": faiss_index.ntotal,
                "num_metadata": len(metadata_store)
            })
            print(f"Loaded FAISS index with {faiss_index.ntotal} vectors")
            return
        except Exception as e:
            print(f"Warning: Failed to load index: {e}. Creating new index.")

    # Create new HNSW index
    # Using HNSW (Hierarchical Navigable Small World) for fast approximate search
    faiss_index = faiss.IndexHNSWFlat(EMBEDDING_DIM, HNSW_M)
    faiss_index.hnsw.efConstruction = HNSW_EF_CONSTRUCTION
    faiss_index.hnsw.efSearch = HNSW_EF_SEARCH

    metadata_store = []

    emit_telemetry("faiss.index.created", {
        "embedding_dim": EMBEDDING_DIM,
        "hnsw_m": HNSW_M,
        "ef_construction": HNSW_EF_CONSTRUCTION,
        "ef_search": HNSW_EF_SEARCH
    })
    print("Created new FAISS HNSW index")


def save_index():
    """Save FAISS index and metadata to disk."""
    try:
        faiss.write_index(faiss_index, str(INDEX_FILE))

        with open(METADATA_FILE, "w") as f:
            for meta in metadata_store:
                f.write(json.dumps(meta) + "\n")

        emit_telemetry("faiss.index.saved", {
            "index_file": str(INDEX_FILE),
            "num_vectors": faiss_index.ntotal
        })
        return True
    except Exception as e:
        emit_telemetry("faiss.index.save_failed", {"error": str(e)})
        return False


def get_embedding(text: str) -> np.ndarray:
    """Get embedding vector for text using OpenAI API."""
    try:
        response = openai_client.embeddings.create(
            model=EMBEDDING_MODEL,
            input=text
        )
        embedding = np.array(response.data[0].embedding, dtype=np.float32)
        return embedding
    except Exception as e:
        emit_telemetry("embedding.error", {"error": str(e), "text_preview": text[:100]})
        raise


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint."""
    return jsonify({
        "status": "healthy",
        "service": "faiss_vector_service",
        "index_size": faiss_index.ntotal if faiss_index else 0,
        "embedding_model": EMBEDDING_MODEL,
        "embedding_dim": EMBEDDING_DIM
    })


@app.route("/stats", methods=["GET"])
def get_stats():
    """Get index statistics."""
    return jsonify({
        "num_vectors": faiss_index.ntotal if faiss_index else 0,
        "num_metadata": len(metadata_store),
        "embedding_dim": EMBEDDING_DIM,
        "index_type": "HNSW",
        "hnsw_m": HNSW_M,
        "ef_construction": HNSW_EF_CONSTRUCTION,
        "ef_search": HNSW_EF_SEARCH
    })


@app.route("/vector_query", methods=["POST"])
def vector_query():
    """
    Perform semantic vector search.

    Request:
    {
        "query": "search text",
        "top_k": 5,
        "min_score": 0.7
    }

    Response:
    {
        "query": "search text",
        "results": [
            {
                "score": 0.95,
                "text": "matched text",
                "metadata": {...}
            }
        ],
        "latency_ms": 15
    }
    """
    start_time = time.time()

    try:
        data = request.json
        query_text = data.get("query", "")
        top_k = data.get("top_k", 5)
        min_score = data.get("min_score", 0.7)

        if not query_text:
            return jsonify({"error": "Missing query"}), 400

        # Get query embedding
        query_embedding = get_embedding(query_text)
        query_embedding = query_embedding.reshape(1, -1)

        # Search FAISS index
        if faiss_index.ntotal == 0:
            emit_telemetry("vector_query.empty_index", {"query": query_text})
            return jsonify({
                "query": query_text,
                "results": [],
                "latency_ms": int((time.time() - start_time) * 1000)
            })

        distances, indices = faiss_index.search(query_embedding, min(top_k, faiss_index.ntotal))

        # Process results
        results = []
        for distance, idx in zip(distances[0], indices[0]):
            if idx >= 0 and idx < len(metadata_store):
                # Convert distance to similarity score (0-1 range)
                # FAISS uses L2 distance, convert to cosine similarity
                score = 1 / (1 + distance)

                if score >= min_score:
                    meta = metadata_store[idx]
                    results.append({
                        "score": float(score),
                        "text": meta.get("text", ""),
                        "source": meta.get("source", ""),
                        "metadata": meta
                    })

        latency_ms = int((time.time() - start_time) * 1000)

        emit_telemetry("vector_query.completed", {
            "query": query_text,
            "num_results": len(results),
            "latency_ms": latency_ms,
            "top_k": top_k
        })

        return jsonify({
            "query": query_text,
            "results": results,
            "latency_ms": latency_ms
        })

    except Exception as e:
        emit_telemetry("vector_query.error", {"error": str(e)})
        return jsonify({"error": str(e)}), 500


@app.route("/ingest", methods=["POST"])
def ingest_documents():
    """
    Ingest documents into vector index.

    Request:
    {
        "documents": [
            {
                "text": "document text",
                "source": "file.md",
                "metadata": {...}
            }
        ]
    }

    Response:
    {
        "ingested": 10,
        "skipped": 0,
        "total_vectors": 100
    }
    """
    try:
        data = request.json
        documents = data.get("documents", [])

        if not documents:
            return jsonify({"error": "No documents provided"}), 400

        ingested = 0
        skipped = 0

        embeddings_to_add = []
        metadata_to_add = []

        for doc in documents:
            text = doc.get("text", "")
            if not text:
                skipped += 1
                continue

            # Generate embedding
            try:
                embedding = get_embedding(text)
                embeddings_to_add.append(embedding)

                # Store metadata
                doc_meta = {
                    "text": text,
                    "source": doc.get("source", "unknown"),
                    "metadata": doc.get("metadata", {}),
                    "ingested_at": datetime.utcnow().isoformat() + "Z",
                    "doc_hash": hashlib.sha256(text.encode()).hexdigest()[:16]
                }
                metadata_to_add.append(doc_meta)
                ingested += 1

            except Exception as e:
                print(f"Failed to process document: {e}")
                skipped += 1

        # Add to FAISS index
        if embeddings_to_add:
            embeddings_matrix = np.array(embeddings_to_add, dtype=np.float32)
            faiss_index.add(embeddings_matrix)
            metadata_store.extend(metadata_to_add)

            # Save index
            save_index()

        emit_telemetry("ingest.completed", {
            "ingested": ingested,
            "skipped": skipped,
            "total_vectors": faiss_index.ntotal
        })

        return jsonify({
            "ingested": ingested,
            "skipped": skipped,
            "total_vectors": faiss_index.ntotal
        })

    except Exception as e:
        emit_telemetry("ingest.error", {"error": str(e)})
        return jsonify({"error": str(e)}), 500


def main():
    """Main entry point."""
    print("=" * 60)
    print("FAISS/HNSW Vector Index Service")
    print("=" * 60)
    print(f"Embedding Model: {EMBEDDING_MODEL}")
    print(f"Embedding Dimension: {EMBEDDING_DIM}")
    print(f"HNSW M: {HNSW_M}")
    print(f"HNSW EF Construction: {HNSW_EF_CONSTRUCTION}")
    print(f"HNSW EF Search: {HNSW_EF_SEARCH}")
    print(f"Index Directory: {INDEX_DIR}")
    print(f"Server: http://{HOST}:{PORT}")
    print("=" * 60)

    # Initialize index
    initialize_index()

    emit_telemetry("service.started", {
        "host": HOST,
        "port": PORT,
        "index_size": faiss_index.ntotal
    })

    # Start Flask server
    app.run(host=HOST, port=PORT, debug=False)


if __name__ == "__main__":
    main()
