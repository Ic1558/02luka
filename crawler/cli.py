import argparse
import asyncio
from pathlib import Path

from .core import CrawlConfig, run_crawler


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Asynchronous web crawler")
    parser.add_argument("seeds", type=Path, help="Path to seed URL list")
    parser.add_argument("--max-pages", type=int, default=100, help="Maximum number of pages to crawl")
    parser.add_argument("--per-domain", type=int, default=20, help="Maximum pages per domain")
    parser.add_argument("--enable-emb", action="store_true", help="Populate optional embedding tables")
    parser.add_argument("--lang", default="en", help="Comma separated Accept-Language header (e.g. th,en)")
    parser.add_argument("--user-agent", default="PromptEPlusCrawler/1.0", help="User-Agent string")
    return parser.parse_args(argv)


def load_seeds(path: Path):
    if not path.exists():
        raise SystemExit(f"Seed file not found: {path}")
    seeds = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            seeds.append(line)
    if not seeds:
        raise SystemExit("Seed file is empty")
    return seeds


def main(argv=None):
    args = parse_args(argv)
    seeds = load_seeds(args.seeds)
    config = CrawlConfig(
        max_pages=args.max_pages,
        per_domain=args.per_domain,
        enable_embeddings=args.enable_emb,
        accept_language=args.lang,
        user_agent=args.user_agent,
    )
    asyncio.run(run_crawler(seeds, config))


if __name__ == "__main__":
    main()
