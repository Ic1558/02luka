#!/usr/bin/env python3
"""
Kim Gateway Proxy Endpoint
R&D Experiment for 02luka Track C - Exploration & R&D

This module provides a proxy interface to the Kim Gateway search service
running on http://localhost:5340/search

Features:
- HTTP proxy to Kim Gateway
- Request/response logging
- Error handling and retry logic
- Async/sync interface support
- Response caching (optional)
"""

import os
import json
import logging
import time
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta

try:
    import requests  # type: ignore[import-untyped]
    from requests.adapters import HTTPAdapter  # type: ignore[import-untyped]
    # Try multiple import paths for Retry (compatible with different urllib3 versions)
    try:
        from urllib3.util.retry import Retry  # type: ignore[import-untyped]
    except ImportError:
        # Fallback: use requests' bundled urllib3 (guaranteed to work if requests is installed)
        from requests.packages.urllib3.util.retry import Retry  # type: ignore[import-untyped]
except ImportError as e:
    import sys
    print(f"Error: Missing dependencies. Install with: pip install requests", file=sys.stderr)
    print(f"ImportError: {e}", file=sys.stderr)
    sys.exit(1)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class SearchRequest:
    """Kim Gateway search request"""
    query: str
    limit: int = 10
    filters: Optional[Dict[str, Any]] = None
    options: Optional[Dict[str, Any]] = None


@dataclass
class SearchResult:
    """Kim Gateway search result"""
    id: str
    score: float
    content: str
    metadata: Optional[Dict[str, Any]] = None


@dataclass
class SearchResponse:
    """Kim Gateway search response"""
    query: str
    results: List[SearchResult]
    total: int
    took_ms: float
    timestamp: str


class KimGatewayProxy:
    """
    Proxy client for Kim Gateway search service.

    Provides a Python interface to the Kim Gateway running on localhost:5340
    with built-in retry logic, error handling, and optional caching.
    """

    def __init__(
        self,
        base_url: str = "http://localhost:5340",
        timeout: int = 30,
        max_retries: int = 3,
        cache_enabled: bool = False,
        cache_ttl: int = 300  # 5 minutes
    ):
        """
        Initialize Kim Gateway proxy client.

        Args:
            base_url: Base URL of Kim Gateway service
            timeout: Request timeout in seconds
            max_retries: Number of retry attempts
            cache_enabled: Enable response caching
            cache_ttl: Cache TTL in seconds
        """
        self.base_url = base_url.rstrip('/')
        self.search_endpoint = f"{self.base_url}/search"
        self.timeout = timeout

        # Setup session with retry logic
        self.session = requests.Session()
        retry_strategy = Retry(
            total=max_retries,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "POST"]
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)

        # Cache setup
        self.cache_enabled = cache_enabled
        self.cache_ttl = cache_ttl
        self._cache: Dict[str, tuple[SearchResponse, datetime]] = {}

        logger.info(f"Initialized KimGatewayProxy: {self.base_url}")

    def _get_cache_key(self, request: SearchRequest) -> str:
        """Generate cache key from request"""
        return json.dumps(asdict(request), sort_keys=True)

    def _get_from_cache(self, key: str) -> Optional[SearchResponse]:
        """Retrieve from cache if valid"""
        if not self.cache_enabled or key not in self._cache:
            return None

        response, timestamp = self._cache[key]
        if datetime.now() - timestamp > timedelta(seconds=self.cache_ttl):
            del self._cache[key]
            return None

        logger.debug(f"Cache hit for query: {key[:50]}...")
        return response

    def _put_in_cache(self, key: str, response: SearchResponse):
        """Store in cache"""
        if self.cache_enabled:
            self._cache[key] = (response, datetime.now())

    def search(
        self,
        query: str,
        limit: int = 10,
        filters: Optional[Dict[str, Any]] = None,
        options: Optional[Dict[str, Any]] = None
    ) -> SearchResponse:
        """
        Execute search query via Kim Gateway.

        Args:
            query: Search query string
            limit: Maximum number of results
            filters: Optional search filters
            options: Optional search options

        Returns:
            SearchResponse object

        Raises:
            requests.RequestException: On request failure
        """
        request = SearchRequest(
            query=query,
            limit=limit,
            filters=filters,
            options=options
        )

        # Check cache
        cache_key = self._get_cache_key(request)
        cached = self._get_from_cache(cache_key)
        if cached:
            return cached

        # Prepare request
        start_time = time.time()
        payload = asdict(request)

        logger.info(f"Searching Kim Gateway: '{query}' (limit={limit})")

        try:
            # Execute request
            response = self.session.post(
                self.search_endpoint,
                json=payload,
                timeout=self.timeout,
                headers={'Content-Type': 'application/json'}
            )
            response.raise_for_status()

            # Parse response
            data = response.json()
            took_ms = (time.time() - start_time) * 1000

            # Build SearchResponse
            results = [
                SearchResult(
                    id=item.get('id', ''),
                    score=item.get('score', 0.0),
                    content=item.get('content', ''),
                    metadata=item.get('metadata')
                )
                for item in data.get('results', [])
            ]

            search_response = SearchResponse(
                query=query,
                results=results,
                total=data.get('total', len(results)),
                took_ms=took_ms,
                timestamp=datetime.now().isoformat()
            )

            # Cache result
            self._put_in_cache(cache_key, search_response)

            logger.info(
                f"Search completed: {len(results)} results in {took_ms:.2f}ms"
            )

            return search_response

        except requests.exceptions.ConnectionError as e:
            logger.error(f"Failed to connect to Kim Gateway at {self.base_url}: {e}")
            raise
        except requests.exceptions.Timeout as e:
            logger.error(f"Request to Kim Gateway timed out after {self.timeout}s: {e}")
            raise
        except requests.exceptions.RequestException as e:
            logger.error(f"Kim Gateway request failed: {e}")
            raise
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse Kim Gateway response: {e}")
            raise

    def health_check(self) -> Dict[str, Any]:
        """
        Check Kim Gateway service health.

        Returns:
            Health status dictionary
        """
        health_endpoint = f"{self.base_url}/health"

        try:
            response = self.session.get(health_endpoint, timeout=5)
            response.raise_for_status()

            return {
                'status': 'healthy',
                'endpoint': self.base_url,
                'response_time_ms': response.elapsed.total_seconds() * 1000,
                'details': response.json() if response.content else {}
            }
        except requests.exceptions.RequestException as e:
            logger.warning(f"Health check failed: {e}")
            return {
                'status': 'unhealthy',
                'endpoint': self.base_url,
                'error': str(e)
            }

    def get_stats(self) -> Dict[str, Any]:
        """Get proxy statistics"""
        return {
            'endpoint': self.search_endpoint,
            'cache_enabled': self.cache_enabled,
            'cache_size': len(self._cache) if self.cache_enabled else 0,
            'timeout': self.timeout
        }

    def clear_cache(self):
        """Clear response cache"""
        if self.cache_enabled:
            cache_size = len(self._cache)
            self._cache.clear()
            logger.info(f"Cleared cache ({cache_size} entries)")


def demo():
    """Demo usage of Kim Gateway proxy"""
    logger.info("=== Kim Gateway Proxy Demo ===")

    # Initialize proxy
    proxy = KimGatewayProxy(
        base_url="http://localhost:5340",
        cache_enabled=True
    )

    # Health check
    health = proxy.health_check()
    logger.info(f"Health check: {json.dumps(health, indent=2)}")

    # If service is not available, show example
    if health['status'] != 'healthy':
        logger.warning("Kim Gateway is not available at localhost:5340")
        logger.info("\nExample usage:")
        logger.info("""
        # Search example
        response = proxy.search(
            query="artificial intelligence",
            limit=5,
            filters={"category": "technology"}
        )

        for result in response.results:
            print(f"[{result.score:.3f}] {result.id}: {result.content[:100]}")
        """)
        return

    # Example searches
    queries = [
        "machine learning algorithms",
        "vector database search",
        "python programming"
    ]

    for query in queries:
        try:
            logger.info(f"\n--- Searching: '{query}' ---")
            response = proxy.search(query, limit=5)

            logger.info(f"Found {response.total} results in {response.took_ms:.2f}ms")
            for i, result in enumerate(response.results, 1):
                logger.info(
                    f"  {i}. [{result.score:.3f}] {result.id}: "
                    f"{result.content[:60]}..."
                )

        except Exception as e:
            logger.error(f"Search failed: {e}")

    # Show stats
    stats = proxy.get_stats()
    logger.info(f"\nProxy stats: {json.dumps(stats, indent=2)}")


if __name__ == '__main__':
    demo()
