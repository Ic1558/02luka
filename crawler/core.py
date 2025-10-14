import asyncio
import hashlib
import json
import os
import sqlite3
import threading
import time
import unicodedata
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple
from urllib import request, robotparser
from urllib.parse import (
    ParseResult,
    parse_qsl,
    quote,
    unquote,
    urljoin,
    urlsplit,
    urlunsplit,
    urlencode,
)

ALLOWED_SCHEMES = {"http", "https"}
MAX_RETRIES = 3
BACKOFF_BASE_SECONDS = 1.5
ROBOTS_TTL_SECONDS = 600
DEFAULT_CONCURRENCY = 10
GLOBAL_RATE_LIMIT = 10  # requests per second
PER_DOMAIN_RATE_LIMIT = 2  # requests per second


@dataclass
class CrawlConfig:
    max_pages: int = 100
    per_domain: int = 20
    enable_embeddings: bool = False
    accept_language: str = "en"
    user_agent: str = "PromptEPlusCrawler/1.0"


@dataclass
class Document:
    url: str
    canonical_url: str
    fetched_at: str
    status: int
    title: Optional[str]
    h1: Optional[str]
    time_values: List[str]
    content: str
    sha256: str
    simhash: int
    language: str


class RateLimiter:
    def __init__(self, rate_per_second: float):
        self._rate = rate_per_second
        self._lock = asyncio.Lock()
        self._next_available = 0.0

    async def acquire(self):
        async with self._lock:
            now = time.monotonic()
            wait_time = max(0.0, self._next_available - now)
            if wait_time > 0:
                await asyncio.sleep(wait_time)
                now = time.monotonic()
            self._next_available = now + 1.0 / self._rate


class RobotsCache:
    def __init__(self, user_agent: str):
        self.user_agent = user_agent
        self._lock = threading.Lock()
        self._cache: Dict[str, Tuple[float, robotparser.RobotFileParser]] = {}

    def _fetch_robots(self, base_url: ParseResult) -> robotparser.RobotFileParser:
        robots_url = urlunsplit((base_url.scheme, base_url.netloc, "/robots.txt", "", ""))
        parser = robotparser.RobotFileParser()
        parser.set_url(robots_url)
        try:
            req = request.Request(robots_url, headers={"User-Agent": self.user_agent})
            with request.urlopen(req, timeout=15) as resp:
                data = resp.read().decode("utf-8", errors="ignore")
            parser.parse(data.splitlines())
        except Exception:
            parser.parse(["User-agent: *", "Disallow: /"])
        return parser

    def allowed(self, url: str) -> bool:
        parts = urlsplit(url)
        if parts.scheme not in ALLOWED_SCHEMES:
            return False
        cache_key = f"{parts.scheme}://{parts.netloc}"
        now = time.time()
        with self._lock:
            entry = self._cache.get(cache_key)
            if entry is None or now - entry[0] > ROBOTS_TTL_SECONDS:
                parser = self._fetch_robots(parts)
                self._cache[cache_key] = (now, parser)
            else:
                parser = entry[1]
        try:
            return parser.can_fetch(self.user_agent, url)
        except Exception:
            return False


class HTMLNormalizer(HTMLParser):
    SKIP_TAGS = {"script", "style", "noscript", "footer", "header", "nav", "aside", "form"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.text_parts: List[str] = []
        self.current_title: List[str] = []
        self.current_h1: List[str] = []
        self.h1_done = False
        self.time_values: List[str] = []
        self.links: List[str] = []
        self.meta_robots: List[str] = []
        self._skip_depth = 0
        self._tag_stack: List[str] = []
        self._collect_title = False
        self._collect_h1 = False
        self._collect_time = False

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        self._tag_stack.append(tag)
        if self._skip_depth > 0:
            if tag in self.SKIP_TAGS:
                self._skip_depth += 1
            return
        if tag in self.SKIP_TAGS:
            self._skip_depth = 1
            return
        if tag == "title":
            self._collect_title = True
            self.current_title.clear()
        elif tag == "h1" and not self.h1_done:
            self._collect_h1 = True
            self.current_h1.clear()
        elif tag == "time":
            self._collect_time = True
            value = attrs_dict.get("datetime")
            if value:
                self.time_values.append(value.strip())
        elif tag == "a":
            href = attrs_dict.get("href")
            if href:
                self.links.append(href)
        elif tag == "meta":
            name = attrs_dict.get("name", "").lower()
            if name == "robots":
                content = attrs_dict.get("content", "")
                self.meta_robots.append(content.lower())

    def handle_endtag(self, tag):
        if self._skip_depth > 0:
            if tag in self.SKIP_TAGS:
                self._skip_depth -= 1
            if self._tag_stack:
                self._tag_stack.pop()
            return
        if tag == "title":
            self._collect_title = False
        elif tag == "h1" and self._collect_h1:
            self._collect_h1 = False
            if self.current_h1:
                self.h1_done = True
        elif tag == "time":
            self._collect_time = False
        if self._tag_stack:
            self._tag_stack.pop()

    def handle_data(self, data):
        if self._skip_depth > 0:
            return
        text = data.strip()
        if not text:
            return
        if self._collect_title:
            self.current_title.append(text)
        elif self._collect_h1:
            self.current_h1.append(text)
        elif self._collect_time:
            self.time_values.append(text)
        else:
            self.text_parts.append(text)

    @property
    def title(self) -> Optional[str]:
        if self.current_title:
            return " ".join(self.current_title)
        return None

    @property
    def h1(self) -> Optional[str]:
        if self.current_h1:
            return " ".join(self.current_h1)
        return None

    def normalized_text(self) -> str:
        text = "\n".join(self.text_parts)
        text = unicodedata.normalize("NFKC", text)
        text = text.casefold()
        text = "\n".join(line.strip() for line in text.splitlines() if line.strip())
        return text

    def _robots_directives(self) -> Set[str]:
        directives: Set[str] = set()
        for entry in self.meta_robots:
            tokens = {
                token.strip()
                for token in entry.replace(";", ",").split(",")
                if token.strip()
            }
            directives.update(tokens)
        return directives

    def should_nofollow(self) -> bool:
        return "nofollow" in self._robots_directives()

    def should_noindex(self) -> bool:
        return "noindex" in self._robots_directives()


@dataclass
class DomainState:
    queue: asyncio.Queue
    scheduled: bool = False


class CrawlRuntime:
    def __init__(self, seeds: Iterable[str], config: CrawlConfig):
        self.config = config
        self.seeds = list(seeds)
        self.domain_states: Dict[str, DomainState] = {}
        self.ready_domains: asyncio.Queue = asyncio.Queue()
        self.global_limiter = RateLimiter(GLOBAL_RATE_LIMIT)
        self.robots = RobotsCache(config.user_agent)
        self.session_headers = {
            "User-Agent": config.user_agent,
            "Accept-Language": config.accept_language,
            "Accept": "text/html,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7",
        }
        self.max_pages = config.max_pages
        self.per_domain_limit = config.per_domain
        self.pages_scheduled = 0
        self.pages_completed = 0
        self.results: List[Document] = []
        self.canonical_seen: Set[str] = set()
        self.hash_seen: Set[str] = set()
        self.simhash_seen: List[int] = []
        self.stop_event = asyncio.Event()
        self.inflight = 0
        self.domain_counts: Dict[str, int] = defaultdict(int)
        self.log_lock = asyncio.Lock()
        self.workers: List[asyncio.Task] = []
        self.domain_limiters: Dict[str, RateLimiter] = {}

    async def run(self):
        for url in self.seeds:
            self._enqueue_url(url)
        worker_count = DEFAULT_CONCURRENCY
        for _ in range(worker_count):
            self.workers.append(asyncio.create_task(self._worker()))
        await self.stop_event.wait()
        for _ in self.workers:
            await self.ready_domains.put(None)
        await asyncio.gather(*self.workers, return_exceptions=True)

    def _enqueue_url(self, url: str):
        canonical = canonicalize_url(url)
        if canonical is None or canonical in self.canonical_seen:
            return
        domain = urlsplit(canonical).netloc
        if self.per_domain_limit and self.domain_counts[domain] >= self.per_domain_limit:
            return
        if self.max_pages and self.pages_scheduled >= self.max_pages:
            return
        self.canonical_seen.add(canonical)
        self.domain_counts[domain] += 1
        self.pages_scheduled += 1
        state = self.domain_states.get(domain)
        if state is None:
            state = DomainState(queue=asyncio.Queue())
            self.domain_states[domain] = state
        state.queue.put_nowait(canonical)
        if not state.scheduled:
            state.scheduled = True
            self.ready_domains.put_nowait(domain)

    async def _worker(self):
        while True:
            domain = await self.ready_domains.get()
            if domain is None:
                break
            state = self.domain_states.get(domain)
            if state is None:
                continue
            try:
                url = await state.queue.get()
            except asyncio.CancelledError:
                break
            state.scheduled = False
            limiter = self.domain_limiters.get(domain)
            if limiter is None:
                limiter = RateLimiter(PER_DOMAIN_RATE_LIMIT)
                self.domain_limiters[domain] = limiter
            if self.max_pages and self.pages_completed >= self.max_pages:
                state.queue.task_done()
                self._check_idle()
                continue
            await limiter.acquire()
            await self.global_limiter.acquire()
            self.inflight += 1
            try:
                await self._fetch_and_process(url)
            finally:
                self.inflight -= 1
                state.queue.task_done()
                if self.max_pages and self.pages_completed >= self.max_pages:
                    while not state.queue.empty():
                        try:
                            state.queue.get_nowait()
                        except asyncio.QueueEmpty:
                            break
                if not state.queue.empty():
                    state.scheduled = True
                    self.ready_domains.put_nowait(domain)
                self._check_idle()

    async def _fetch_and_process(self, url: str):
        start = time.monotonic()
        status: Optional[int] = None
        content: Optional[bytes] = None
        reason = ""
        dedup_state = "none"
        allowed = await asyncio.to_thread(self.robots.allowed, url)
        if not allowed:
            reason = "robots"
            await self._log_page(url, status, 0, int((time.monotonic() - start) * 1000), dedup_state, reason)
            self.pages_completed += 1
            return
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                status, content, headers = await asyncio.to_thread(self._blocking_fetch, url)
                break
            except Exception as exc:
                status = None
                reason = type(exc).__name__
                if attempt == MAX_RETRIES:
                    await self._log_page(url, status, 0, int((time.monotonic() - start) * 1000), dedup_state, reason)
                    self.pages_completed += 1
                    return
                await asyncio.sleep(self._backoff_delay(url, attempt))
        if status != 200 or content is None:
            reason = f"http_{status}" if status is not None else reason or "fetch_failed"
            await self._log_page(url, status, len(content or b""), int((time.monotonic() - start) * 1000), dedup_state, reason)
            self.pages_completed += 1
            return
        html_text = content.decode("utf-8", errors="replace")
        parser = HTMLNormalizer()
        parser.feed(html_text)
        parser.close()
        normalized_text = parser.normalized_text()
        if not normalized_text.strip():
            reason = "empty"
            await self._log_page(url, status, len(content), int((time.monotonic() - start) * 1000), dedup_state, reason)
            self.pages_completed += 1
            return
        sha256_hash = hashlib.sha256(normalized_text.encode("utf-8")).hexdigest()
        if sha256_hash in self.hash_seen:
            dedup_state = "hash"
            reason = "duplicate"
            await self._log_page(url, status, len(content), int((time.monotonic() - start) * 1000), dedup_state, reason)
            self.pages_completed += 1
            return
        simhash_value = compute_simhash(normalized_text)
        if self._is_near_duplicate(simhash_value):
            dedup_state = "simhash"
            reason = "near_duplicate"
            await self._log_page(url, status, len(content), int((time.monotonic() - start) * 1000), dedup_state, reason)
            self.pages_completed += 1
            return
        if parser.should_noindex():
            reason = "noindex"
            await self._log_page(url, status, len(content), int((time.monotonic() - start) * 1000), dedup_state, reason)
            self.pages_completed += 1
            if not parser.should_nofollow():
                base = url
                for link in parser.links:
                    absolute = urljoin(base, link)
                    canonical = canonicalize_url(absolute)
                    if canonical:
                        self._enqueue_url(canonical)
            return
        title = parser.title
        h1 = parser.h1
        time_values = parser.time_values[:5]
        language = self.config.accept_language
        fetched_at = datetime.utcnow().isoformat() + "Z"
        doc = Document(
            url=url,
            canonical_url=url,
            fetched_at=fetched_at,
            status=status,
            title=title,
            h1=h1,
            time_values=time_values,
            content=normalized_text,
            sha256=sha256_hash,
            simhash=simhash_value,
            language=language,
        )
        self.results.append(doc)
        self.hash_seen.add(sha256_hash)
        self.simhash_seen.append(simhash_value)
        await self._log_page(url, status, len(content), int((time.monotonic() - start) * 1000), dedup_state, "ok")
        self.pages_completed += 1
        if not parser.should_nofollow():
            base = url
            for link in parser.links:
                absolute = urljoin(base, link)
                canonical = canonicalize_url(absolute)
                if canonical:
                    self._enqueue_url(canonical)

    def _blocking_fetch(self, url: str):
        headers = self.session_headers.copy()
        req = request.Request(url, headers=headers)
        with request.urlopen(req, timeout=20) as resp:
            status = resp.getcode()
            data = resp.read()
            return status, data, resp.headers

    def _backoff_delay(self, url: str, attempt: int) -> float:
        jitter_seed = hashlib.sha256(f"{url}-{attempt}".encode("utf-8")).digest()
        jitter = int.from_bytes(jitter_seed[:2], "big") / 65535.0
        base = BACKOFF_BASE_SECONDS ** (attempt - 1)
        return base + jitter * 0.5

    def _is_near_duplicate(self, simhash_value: int) -> bool:
        for existing in self.simhash_seen:
            if hamming_distance(existing, simhash_value) <= 3:
                return True
        return False

    async def _log_page(self, url: str, status: Optional[int], byte_count: int, duration_ms: int, dedup: str, reason: str):
        log_entry = {
            "url": url,
            "status": status,
            "bytes": byte_count,
            "ms": duration_ms,
            "dedup": dedup,
            "reason": reason,
        }
        async with self.log_lock:
            print(json.dumps(log_entry, ensure_ascii=False), flush=True)

    def _check_idle(self):
        if self.inflight > 0:
            return
        if any(not state.queue.empty() for state in self.domain_states.values()):
            return
        if self.max_pages and self.pages_completed < min(self.pages_scheduled, self.max_pages):
            return
        if not self.stop_event.is_set():
            self.stop_event.set()


def canonicalize_url(url: str) -> Optional[str]:
    try:
        parts = urlsplit(url)
    except Exception:
        return None
    if parts.scheme.lower() not in ALLOWED_SCHEMES:
        return None
    scheme = parts.scheme.lower()
    hostname = parts.hostname.lower() if parts.hostname else ""
    port = parts.port
    if port:
        if (scheme == "http" and port == 80) or (scheme == "https" and port == 443):
            netloc = hostname
        else:
            netloc = f"{hostname}:{port}"
    else:
        netloc = hostname
    path = quote(unquote(parts.path or "/"), safe="/-._~")
    query_pairs = [(k, v) for k, v in sorted(parse_qsl(parts.query, keep_blank_values=True))]
    query = urlencode(query_pairs)
    fragment = ""
    canonical = urlunsplit((scheme, netloc, path, query, fragment))
    return canonical


def compute_simhash(text: str, bits: int = 64) -> int:
    weights = [0] * bits
    tokens = text.split()
    if not tokens:
        return 0
    for token in tokens:
        digest = hashlib.md5(token.encode("utf-8")).digest()
        value = int.from_bytes(digest[:8], "big")
        for bit in range(bits):
            if value & (1 << bit):
                weights[bit] += 1
            else:
                weights[bit] -= 1
    fingerprint = 0
    for bit, weight in enumerate(weights):
        if weight >= 0:
            fingerprint |= 1 << bit
    return fingerprint


def hamming_distance(a: int, b: int) -> int:
    return (a ^ b).bit_count()


async def run_crawler(seeds: Iterable[str], config: CrawlConfig):
    runtime = CrawlRuntime(seeds, config)
    await runtime.run()
    write_outputs(runtime.results, config)


def write_outputs(documents: List[Document], config: CrawlConfig):
    date_str = datetime.utcnow().strftime("%Y%m%d")
    corpus_dir = Path("g/data/corpus") / date_str
    corpus_dir.mkdir(parents=True, exist_ok=True)
    ndjson_path = corpus_dir / "docs.ndjson"
    sorted_docs = sorted(documents, key=lambda d: d.canonical_url)
    with ndjson_path.open("w", encoding="utf-8") as handle:
        for doc in sorted_docs:
            record = {
                "url": doc.url,
                "canonical_url": doc.canonical_url,
                "fetched_at": doc.fetched_at,
                "status": doc.status,
                "title": doc.title,
                "h1": doc.h1,
                "time": doc.time_values,
                "content": doc.content,
                "sha256": doc.sha256,
                "simhash": doc.simhash,
                "lang": doc.language,
            }
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")
    db_path = Path("g/data/corpus.db")
    build_sqlite(db_path, sorted_docs, config)


def build_sqlite(db_path: Path, documents: List[Document], config: CrawlConfig):
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS docs (
            id INTEGER PRIMARY KEY,
            url TEXT UNIQUE,
            canonical_url TEXT,
            fetched_at TEXT,
            status INTEGER,
            title TEXT,
            h1 TEXT,
            time TEXT,
            content TEXT,
            sha256 TEXT,
            simhash INTEGER,
            lang TEXT
        )
        """
    )
    conn.execute("DROP TABLE IF EXISTS docs_fts")
    conn.execute(
        """
        CREATE VIRTUAL TABLE docs_fts USING fts5(
            title, content, url UNINDEXED, canonical_url UNINDEXED, lang UNINDEXED
        )
        """
    )
    conn.execute("DELETE FROM docs")
    for doc in documents:
        cursor = conn.execute(
            "INSERT INTO docs (url, canonical_url, fetched_at, status, title, h1, time, content, sha256, simhash, lang) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                doc.url,
                doc.canonical_url,
                doc.fetched_at,
                doc.status,
                doc.title,
                doc.h1,
                json.dumps(doc.time_values, ensure_ascii=False),
                doc.content,
                doc.sha256,
                doc.simhash,
                doc.language,
            ),
        )
        doc_id = cursor.lastrowid
        conn.execute(
            "INSERT INTO docs_fts (rowid, title, content, url, canonical_url, lang) VALUES (?, ?, ?, ?, ?, ?)",
            (
                doc_id,
                doc.title or "",
                doc.content,
                doc.url,
                doc.canonical_url,
                doc.language,
            ),
        )
    if config.enable_embeddings and os.environ.get("ENABLE_EMBED", "").lower() == "true":
        try:
            conn.enable_load_extension(True)
            conn.load_extension("vss0")
            conn.execute("DROP TABLE IF EXISTS doc_embeddings")
            conn.execute("CREATE VIRTUAL TABLE doc_embeddings USING vss0(embedding(8))")
            conn.execute("DELETE FROM doc_embeddings")
            conn.commit()
        except sqlite3.OperationalError:
            pass
        finally:
            try:
                conn.enable_load_extension(False)
            except sqlite3.OperationalError:
                pass
    conn.commit()
    conn.close()
