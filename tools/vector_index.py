#!/usr/bin/env python3
"""
FAISS/HNSW Vector Index Driver
R&D Experiment for 02luka Track C - Exploration & R&D

This module provides a vectorization and semantic search interface
using FAISS (Facebook AI Similarity Search) with HNSW indexing.

Features:
- Document embedding using sentence transformers
- HNSW index for fast approximate nearest neighbor search
- Batch indexing and real-time search
- Persistence and loading of indexes
"""

import os
import json
import pickle
import logging
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass
from pathlib import Path

try:
    import numpy as np
    import faiss
    from sentence_transformers import SentenceTransformer
except ImportError as e:
    print(f"Warning: Missing dependencies. Install with: pip install faiss-cpu sentence-transformers")
    raise e

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class SearchResult:
    """Container for search results"""
    doc_id: str
    text: str
    score: float
    metadata: Optional[Dict] = None


class VectorIndex:
    """
    FAISS-based vector index with HNSW algorithm for efficient similarity search.

    HNSW (Hierarchical Navigable Small World) provides:
    - Sub-linear search complexity
    - Good recall/speed tradeoff
    - Scalable to millions of vectors
    """

    def __init__(
        self,
        model_name: str = 'all-MiniLM-L6-v2',
        index_type: str = 'hnsw',
        dimension: Optional[int] = None,
        M: int = 32,  # HNSW connections per layer
        ef_construction: int = 200,  # HNSW construction time search
        ef_search: int = 50  # HNSW search time search
    ):
        """
        Initialize the vector index.

        Args:
            model_name: HuggingFace sentence transformer model
            index_type: 'hnsw' or 'flat' (exact search)
            dimension: Vector dimension (auto-detected if None)
            M: HNSW M parameter (connections per layer)
            ef_construction: HNSW build-time exploration factor
            ef_search: HNSW search-time exploration factor
        """
        logger.info(f"Initializing VectorIndex with model: {model_name}")

        # Load embedding model
        self.model = SentenceTransformer(model_name)
        self.dimension = dimension or self.model.get_sentence_embedding_dimension()

        # Initialize FAISS index
        self.index_type = index_type
        if index_type == 'hnsw':
            self.index = faiss.IndexHNSWFlat(self.dimension, M)
            self.index.hnsw.efConstruction = ef_construction
            self.index.hnsw.efSearch = ef_search
            logger.info(f"Created HNSW index: M={M}, ef_construction={ef_construction}, ef_search={ef_search}")
        elif index_type == 'flat':
            self.index = faiss.IndexFlatL2(self.dimension)
            logger.info("Created Flat (exact) index")
        else:
            raise ValueError(f"Unknown index_type: {index_type}")

        # Document storage
        self.documents: List[Dict] = []
        self.doc_id_map: Dict[int, str] = {}

    def add_documents(self, documents: List[Dict[str, str]], batch_size: int = 32):
        """
        Add documents to the index.

        Args:
            documents: List of dicts with 'id', 'text', and optional 'metadata'
            batch_size: Embedding batch size
        """
        logger.info(f"Adding {len(documents)} documents to index")

        # Extract texts and embed
        texts = [doc['text'] for doc in documents]
        embeddings = self.model.encode(
            texts,
            batch_size=batch_size,
            show_progress_bar=True,
            convert_to_numpy=True
        )

        # Add to FAISS index
        start_idx = len(self.documents)
        self.index.add(embeddings.astype('float32'))

        # Store documents and mapping
        for i, doc in enumerate(documents):
            self.documents.append(doc)
            self.doc_id_map[start_idx + i] = doc.get('id', f"doc_{start_idx + i}")

        logger.info(f"Index now contains {self.index.ntotal} vectors")

    def search(
        self,
        query: str,
        k: int = 10,
        return_metadata: bool = True
    ) -> List[SearchResult]:
        """
        Search for similar documents.

        Args:
            query: Search query string
            k: Number of results to return
            return_metadata: Include document metadata in results

        Returns:
            List of SearchResult objects
        """
        if self.index.ntotal == 0:
            logger.warning("Index is empty")
            return []

        # Embed query
        query_vec = self.model.encode([query], convert_to_numpy=True)

        # Search index
        distances, indices = self.index.search(query_vec.astype('float32'), k)

        # Build results
        results = []
        for dist, idx in zip(distances[0], indices[0]):
            if idx == -1:  # FAISS returns -1 for missing results
                continue

            doc = self.documents[idx]
            result = SearchResult(
                doc_id=self.doc_id_map[idx],
                text=doc['text'],
                score=float(1.0 / (1.0 + dist)),  # Convert distance to similarity
                metadata=doc.get('metadata') if return_metadata else None
            )
            results.append(result)

        return results

    def save(self, path: str):
        """Save index and documents to disk"""
        path_obj = Path(path)
        path_obj.mkdir(parents=True, exist_ok=True)

        # Save FAISS index
        index_file = path_obj / "index.faiss"
        faiss.write_index(self.index, str(index_file))

        # Save documents and metadata
        meta_file = path_obj / "metadata.pkl"
        with open(meta_file, 'wb') as f:
            pickle.dump({
                'documents': self.documents,
                'doc_id_map': self.doc_id_map,
                'dimension': self.dimension,
                'index_type': self.index_type
            }, f)

        logger.info(f"Index saved to {path}")

    @classmethod
    def load(cls, path: str, model_name: str = 'all-MiniLM-L6-v2') -> 'VectorIndex':
        """Load index from disk"""
        path_obj = Path(path)

        # Load metadata
        meta_file = path_obj / "metadata.pkl"
        with open(meta_file, 'rb') as f:
            metadata = pickle.load(f)

        # Create instance
        instance = cls(
            model_name=model_name,
            index_type=metadata['index_type'],
            dimension=metadata['dimension']
        )

        # Load FAISS index
        index_file = path_obj / "index.faiss"
        instance.index = faiss.read_index(str(index_file))

        # Restore documents
        instance.documents = metadata['documents']
        instance.doc_id_map = metadata['doc_id_map']

        logger.info(f"Index loaded from {path} with {instance.index.ntotal} vectors")
        return instance

    def get_stats(self) -> Dict:
        """Get index statistics"""
        return {
            'num_documents': len(self.documents),
            'num_vectors': self.index.ntotal,
            'dimension': self.dimension,
            'index_type': self.index_type,
            'memory_usage_mb': self.index.ntotal * self.dimension * 4 / (1024 * 1024)
        }


def demo():
    """Demo usage of the vector index"""
    logger.info("=== FAISS/HNSW Vector Index Demo ===")

    # Sample documents
    sample_docs = [
        {
            'id': 'doc1',
            'text': 'Machine learning is a subset of artificial intelligence',
            'metadata': {'category': 'AI', 'date': '2025-01-01'}
        },
        {
            'id': 'doc2',
            'text': 'Deep learning uses neural networks with multiple layers',
            'metadata': {'category': 'AI', 'date': '2025-01-02'}
        },
        {
            'id': 'doc3',
            'text': 'Python is a popular programming language for data science',
            'metadata': {'category': 'Programming', 'date': '2025-01-03'}
        },
        {
            'id': 'doc4',
            'text': 'Vector databases enable semantic search capabilities',
            'metadata': {'category': 'Database', 'date': '2025-01-04'}
        },
        {
            'id': 'doc5',
            'text': 'FAISS provides efficient similarity search algorithms',
            'metadata': {'category': 'Database', 'date': '2025-01-05'}
        }
    ]

    # Create and populate index
    index = VectorIndex(index_type='hnsw')
    index.add_documents(sample_docs)

    # Show stats
    stats = index.get_stats()
    logger.info(f"Index stats: {json.dumps(stats, indent=2)}")

    # Search
    queries = [
        "What is artificial intelligence?",
        "Tell me about vector search",
        "Programming languages for ML"
    ]

    for query in queries:
        logger.info(f"\nQuery: '{query}'")
        results = index.search(query, k=3)
        for i, result in enumerate(results, 1):
            logger.info(f"  {i}. [{result.score:.3f}] {result.doc_id}: {result.text[:60]}...")

    # Save and reload
    save_path = "/tmp/faiss_index_demo"
    index.save(save_path)

    loaded_index = VectorIndex.load(save_path)
    logger.info(f"\nReloaded index with {loaded_index.index.ntotal} vectors")


if __name__ == '__main__':
    demo()
