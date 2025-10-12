#!/usr/bin/env python3
"""Asynchronous web crawler that respects robots.txt, rate limits, and outputs NDJSON."""
from __future__ import annotations

import argparse
import asyncio
import contextlib
import datetime as dt
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Iterable, Optional
from urllib.parse import urldefrag, urljoin, urlparse, urlunparse
from urllib import robotparser

import aiohttp
from bs4 import BeautifulSoup
import trafilatura


DEFAULT_USER_AGENT = "LukaCrawler/0.1"
TEXT_CONTENT_RE = re.compile(r"text/|application/(json|xml)", re.I)


class RateLimiter:
    """Co-operative rate limiter that enforces global and per-domain ceilings."""

    def __init__(self, global_rps: float, per_domain_rps: float) -> None:
        self._global_interval = 1.0 / global_rps
        self._domain_interval = 1.0 / per_domain_rps
        self._lock = asyncio.Lock()
        self._last_request: float = 0.0
        self._domain_last: dict[str, float] = {}

    async def wait(self, domain: str) -> None:
        loop = asyncio.get_running_loop()
        while True:
            async with self._lock:
                now = loop.time()
                global_ready = self._last_request + self._global_interval
                domain_ready = self._domain_last.get(domain, 0.0) + self._domain_interval
                target = max(global_ready, domain_ready, now)
                wait_for = target - now
                if wait_for <= 0:
                    self._last_request = now
                    self._domain_last[domain] = now
                    return
            await asyncio.sleep(wait_for)


class RobotsCache:
    def __init__(self, session: aiohttp.ClientSession, user_agent: str) -> None:
        self._session = session
        self._user_agent = user_agent
        self._cache: dict[str, robotparser.RobotFileParser | None] = {}
        self._locks: defaultdict[str, asyncio.Lock] = defaultdict(asyncio.Lock)

    async def allowed(self, url: str) -> bool:
        parsed = urlparse(url)
        robots_url = urlunparse((parsed.scheme, parsed.netloc, "/robots.txt", "", "", ""))
        async with self._locks[robots_url]:
            if robots_url not in self._cache:
                self._cache[robots_url] = await self._fetch(robots_url)
            parser = self._cache[robots_url]
        if parser is None:
            return True
        return parser.can_fetch(self._user_agent, url)

    async def _fetch(self, robots_url: str) -> Optional[robotparser.RobotFileParser]:
        try:
            async with self._session.get(robots_url, timeout=10) as resp:
                if resp.status >= 400:
                    return None
                text = await resp.text(errors="ignore")
        except Exception:
            return None
        parser = robotparser.RobotFileParser()
        parser.set_url(robots_url)
        parser.parse(text.splitlines())
        return parser


def normalize_url(url: str) -> str:
    url = urldefrag(url)[0]
    parsed = urlparse(url)
    scheme = parsed.scheme.lower()
    netloc = parsed.netloc.lower()
    if scheme not in {"http", "https"}:
        raise ValueError("Unsupported scheme")
    if netloc.endswith(":80") and scheme == "http":
        netloc = netloc[:-3]
    if netloc.endswith(":443") and scheme == "https":
        netloc = netloc[:-4]
    normalized = urlunparse((scheme, netloc, parsed.path or "/", parsed.params, parsed.query, ""))
    return normalized


def extract_links(html: str, base_url: str) -> Iterable[str]:
    soup = BeautifulSoup(html, "html.parser")
    for a in soup.find_all("a", href=True):
        href = a.get("href")
        if not href:
            continue
        joined = urljoin(base_url, href)
        try:
            normalized = normalize_url(joined)
        except Exception:
            continue
        yield normalized


def clean_content(html: str, url: str) -> tuple[str, str]:
    downloaded = trafilatura.extract(html, url=url, include_comments=False)
    if not downloaded:
        raise ValueError("Unable to extract")
    title = trafilatura.extract_metadata(html, url=url)
    page_title = title.title if title and title.title else ""
    return page_title.strip(), downloaded.strip()


async def crawl(
    seeds: list[str],
    output_file: Path,
    max_pages: int,
    per_domain: int,
    concurrency: int,
    user_agent: str,
) -> Counter:
    queue: asyncio.Queue[str | None] = asyncio.Queue()
    for seed in seeds:
        queue.put_nowait(seed)

    seen: set[str] = set()
    enqueued: set[str] = set(seeds)
    domain_counts: defaultdict[str, int] = defaultdict(int)
    limiter = RateLimiter(global_rps=10, per_domain_rps=2)
    stats: Counter = Counter()
    stop_event = asyncio.Event()
    file_lock = asyncio.Lock()

    timeout = aiohttp.ClientTimeout(total=30)
    headers = {"User-Agent": user_agent, "Accept": "text/html,application/xhtml+xml"}

    async with aiohttp.ClientSession(timeout=timeout, headers=headers) as session:
        robots = RobotsCache(session, user_agent=user_agent)

        async def worker() -> None:
            nonlocal stats
            while True:
                url = await queue.get()
                if url is None:
                    queue.task_done()
                    break
                if stop_event.is_set():
                    stats["pages_skipped"] += 1
                    queue.task_done()
                    continue
                try:
                    normalized = normalize_url(url)
                except ValueError:
                    stats["pages_skipped"] += 1
                    queue.task_done()
                    continue
                if normalized in seen:
                    stats["pages_skipped"] += 1
                    queue.task_done()
                    continue
                seen.add(normalized)
                domain = urlparse(normalized).netloc
                if domain_counts[domain] >= per_domain:
                    stats["pages_skipped"] += 1
                    queue.task_done()
                    continue
                if not await robots.allowed(normalized):
                    stats["robots_denied"] += 1
                    queue.task_done()
                    continue
                await limiter.wait(domain)
                try:
                    async with session.get(normalized, allow_redirects=True) as resp:
                        if resp.status != 200:
                            stats["pages_skipped"] += 1
                            queue.task_done()
                            continue
                        content_type = resp.headers.get("Content-Type", "")
                        if content_type and not TEXT_CONTENT_RE.search(content_type):
                            stats["pages_skipped"] += 1
                            queue.task_done()
                            continue
                        html = await resp.text(errors="ignore")
                except Exception:
                    stats["pages_skipped"] += 1
                    queue.task_done()
                    continue

                try:
                    title, cleaned = clean_content(html, normalized)
                except Exception:
                    stats["pages_skipped"] += 1
                    queue.task_done()
                    continue

                fetched_at = dt.datetime.utcnow().isoformat() + "Z"
                doc_id = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
                content_hash = hashlib.sha256(cleaned.encode("utf-8")).hexdigest()
                record = {
                    "doc_id": doc_id,
                    "url": normalized,
                    "title": title,
                    "text": cleaned,
                    "fetched_at": fetched_at,
                    "content_hash": content_hash,
                }
                json_line = json.dumps(record, ensure_ascii=False)
                async with file_lock:
                    output_file.parent.mkdir(parents=True, exist_ok=True)
                    with open(output_file, "a", encoding="utf-8") as fh:
                        fh.write(json_line + "\n")
                    stats["bytes"] += len(json_line.encode("utf-8"))
                stats["pages_ok"] += 1
                domain_counts[domain] += 1
                if stats["pages_ok"] >= max_pages:
                    stop_event.set()
                if not stop_event.is_set():
                    for link in extract_links(html, normalized):
                        if link not in seen and link not in enqueued:
                            enqueued.add(link)
                            await queue.put(link)
                queue.task_done()

        workers = [asyncio.create_task(worker()) for _ in range(concurrency)]
        await queue.join()
        for _ in workers:
            await queue.put(None)
        await asyncio.gather(*workers)

    return stats


def load_seeds(path: Path) -> list[str]:
    if not path.exists():
        raise FileNotFoundError(f"Seed file not found: {path}")
    seeds = []
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            try:
                seeds.append(normalize_url(line))
            except Exception:
                continue
    if not seeds:
        raise ValueError("No valid seeds provided")
    return seeds


def resolve_output_path(base_dir: Path) -> Path:
    today = dt.datetime.utcnow().strftime("%Y%m%d")
    target_dir = base_dir / today
    target_dir.mkdir(parents=True, exist_ok=True)
    return target_dir / "docs.ndjson"


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Async web crawler")
    parser.add_argument("seeds", help="Path to seed URL list")
    parser.add_argument("--max-pages", type=int, default=100, help="Maximum pages to crawl")
    parser.add_argument("--per-domain", type=int, default=20, help="Maximum pages per domain")
    parser.add_argument("--concurrency", type=int, default=10, help="Concurrent fetch workers")
    parser.add_argument(
        "--output-dir",
        default="g/data/corpus",
        help="Base directory for NDJSON corpus output",
    )
    parser.add_argument("--user-agent", default=DEFAULT_USER_AGENT)
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    seeds = load_seeds(Path(args.seeds))
    output_file = resolve_output_path(Path(args.output_dir))
    stats = asyncio.run(
        crawl(
            seeds=seeds,
            output_file=output_file,
            max_pages=args.max_pages,
            per_domain=args.per_domain,
            concurrency=args.concurrency,
            user_agent=args.user_agent,
        )
    )
    summary = (
        f"SUMMARY pages_ok={stats['pages_ok']} "
        f"pages_skipped={stats['pages_skipped']} "
        f"robots_denied={stats['robots_denied']} "
        f"bytes={stats['bytes']}"
    )
    print(summary)
    return 0


if __name__ == "__main__":
    with contextlib.suppress(KeyboardInterrupt):
        sys.exit(main())
