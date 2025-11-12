#!/usr/bin/env python3
"""
Paula Data Crawler - Fetch OHLC market data from CSV or HTTP endpoint
"""
import os
import sys
import json
import csv
import time
import logging
from datetime import datetime, timezone
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
log = logging.getLogger("paula_data_crawler")

try:
    import requests  # optional
except ImportError:
    requests = None
    log.warning("requests library not available - HTTP endpoint fetching disabled")

SOT = Path(os.environ.get("LUKA_SOT", "/Users/icmini/02luka")).expanduser()
DATA_DIR = SOT / "data" / "market"
OUT_DIR = SOT / "mls" / "paula" / "intel"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def read_local_csv(symbol: str):
    """Read OHLC data from local CSV files."""
    rows = []
    # Prefer symbol-specific files, fallback to any CSV
    files = sorted((DATA_DIR).glob(f"{symbol}*.csv"))
    if not files:
        files = sorted((DATA_DIR).glob("*.csv"))
    
    for f in files[-3:]:  # Read last 3 files to keep light
        try:
            with f.open('r', encoding='utf-8') as fh:
                reader = csv.DictReader(fh)
                line_num = 0
                for line_num, row in enumerate(reader, start=2):  # Start at 2 (header is line 1)
                    try:
                        rows.append({
                            "timestamp": row.get("timestamp") or row.get("time") or row.get("date"),
                            "open": float(row.get("open", 0) or 0),
                            "high": float(row.get("high", 0) or 0),
                            "low": float(row.get("low", 0) or 0),
                            "close": float(row.get("close", 0) or 0),
                            "volume": float(row.get("volume", 0) or 0)
                        })
                    except (ValueError, KeyError) as e:
                        log.warning(f"CSV decode error in {f.name} line {line_num}: {e}")
                        continue
        except UnicodeDecodeError as e:
            log.error(f"CSV encoding error in {f.name}: {e}")
            continue
        except Exception as e:
            log.error(f"Error reading {f.name}: {e}")
            continue
    
    return rows


def fetch_http(endpoint: str, symbol: str):
    """Fetch OHLC data from HTTP endpoint."""
    if not requests:
        log.warning("requests library not available - skipping HTTP fetch")
        return []
    
    try:
        params = {"symbol": symbol} if "?" not in endpoint else None
        resp = requests.get(endpoint, params=params, timeout=15)
        resp.raise_for_status()
        data = resp.json()
        
        rows = []
        for idx, d in enumerate(data[-500:], start=1):  # Keep last 500 records
            try:
                rows.append({
                    "timestamp": d.get("timestamp") or d.get("time") or d.get("date"),
                    "open": float(d.get("open", 0) or 0),
                    "high": float(d.get("high", 0) or 0),
                    "low": float(d.get("low", 0) or 0),
                    "close": float(d.get("close", 0) or 0),
                    "volume": float(d.get("volume", 0) or 0)
                })
            except (ValueError, KeyError, TypeError) as e:
                log.warning(f"HTTP data decode error at index {idx}: {e}")
                continue
        
        return rows
    except Exception as e:
        log.warning(f"HTTP fetch failed for {endpoint}: {e}")
        return []


def combine_and_sort(rows):
    """Combine and deduplicate rows by timestamp + close price."""
    uniq = {}
    for r in rows:
        if r.get("timestamp") and r.get("close"):
            key = (r["timestamp"], r["close"])
            if key not in uniq:
                uniq[key] = r
    
    out = list(uniq.values())
    out.sort(key=lambda x: x.get("timestamp", ""))
    return out


def main():
    symbol = os.environ.get("PAULA_SYMBOL", "SET50Z25")
    endpoint = os.environ.get("PAULA_PRICE_ENDPOINT", "").strip()
    
    rows = []
    
    # Try HTTP endpoint first (if provided)
    if endpoint:
        log.info(f"Fetching from HTTP endpoint: {endpoint}")
        rows += fetch_http(endpoint, symbol)
    
    # Always try local CSV
    log.info(f"Reading local CSV files for symbol: {symbol}")
    rows += read_local_csv(symbol)
    
    if not rows:
        log.error("No data found from CSV or HTTP endpoint")
        sys.exit(1)
    
    # Combine and deduplicate
    rows = combine_and_sort(rows)
    
    # Keep last 100 for downstream processing
    rows = rows[-100:]
    
    ts = datetime.now(timezone.utc).astimezone().isoformat()
    out = {
        "timestamp": ts,
        "symbol": symbol,
        "records": len(rows),
        "ohlc": rows
    }
    
    out_file = OUT_DIR / f"crawler_{symbol}_{datetime.now().strftime('%Y%m%d')}.json"
    out_file.write_text(json.dumps(out, ensure_ascii=False, indent=2))
    
    log.info(f"✅ Crawled {len(rows)} records, saved to {out_file}")
    print(str(out_file))


if __name__ == "__main__":
    main()
