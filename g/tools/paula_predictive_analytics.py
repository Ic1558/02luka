#!/usr/bin/env python3
"""
Paula Predictive Analytics - Calculate market bias, trend confidence, and volatility
"""
import os
import sys
import json
import logging
from statistics import mean, pstdev
from pathlib import Path
from datetime import datetime, timezone

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
log = logging.getLogger("paula_predictive")

SOT = Path(os.environ.get("LUKA_SOT", "/Users/icmini/02luka")).expanduser()
INTEL_DIR = SOT / "mls" / "paula" / "intel"
OUT_DIR = INTEL_DIR
OUT_DIR.mkdir(parents=True, exist_ok=True)


def linear_slope(y):
    """
    Simple OLS slope calculation against x = 0..n-1 (no numpy dependency).
    Returns slope value (positive = upward trend, negative = downward trend).
    """
    n = len(y)
    if n < 2:
        return 0.0
    
    x = list(range(n))
    mx = (n - 1) / 2
    my = mean(y)
    
    num = sum((xi - mx) * (yi - my) for xi, yi in zip(x, y))
    den = sum((xi - mx) ** 2 for xi in x) or 1e-9
    
    return num / den


def main():
    symbol = os.environ.get("PAULA_SYMBOL", "SET50Z25")
    
    # Find latest crawler file
    files = sorted(INTEL_DIR.glob(f"crawler_{symbol}_*.json"))
    if not files:
        log.error("NO_CRAWLED_DATA - Run paula_data_crawler.py first")
        print("NO_CRAWLED_DATA")
        sys.exit(1)
    
    # Read crawler data
    try:
        data = json.loads(files[-1].read_text())
    except Exception as e:
        log.error(f"Error reading crawler file {files[-1]}: {e}")
        print("ERROR_READING_DATA")
        sys.exit(1)
    
    # Extract close prices
    closes = [r.get("close", 0) for r in data.get("ohlc", []) if r.get("close")]
    
    if len(closes) < 20:
        log.warning(f"NOT_ENOUGH_DATA - Only {len(closes)} records, need at least 20")
        print("NOT_ENOUGH_DATA")
        sys.exit(1)
    
    # Calculate metrics
    last_close = closes[-1]
    window = closes[-20:]  # Last 20 bars
    
    slope = linear_slope(window)  # Positive → up-bias, negative → down-bias
    vol = pstdev(window) if len(window) > 1 else 0.0
    avg = mean(window)
    pct_move = (slope / avg) * 100 if avg else 0.0
    
    # Normalize to confidence 0..1 (bounded)
    conf = max(0.0, min(1.0, abs(pct_move) / 2.0))
    
    # Determine bias
    if slope > 0.001:
        bias = "long"
    elif slope < -0.001:
        bias = "short"
    else:
        bias = "flat"
    
    # Position suggestion based on confidence
    if conf >= 0.7:
        size = 0.3
        suggestion = "open 30% size"
    elif conf >= 0.4:
        size = 0.15
        suggestion = "open 15% size"
    else:
        size = 0.0
        suggestion = "wait"
    
    # Generate insight
    insight = {
        "timestamp": datetime.now().astimezone().isoformat(),
        "symbol": symbol,
        "trend_confidence": round(conf, 2),
        "predicted_move_pct": round(pct_move, 2),
        "volatility_est": round(vol / (avg or 1), 4),
        "bias": bias,
        "position_suggestion": suggestion,
        "reasons": [
            f"20-bar slope = {round(slope, 6)}",
            f"vol ~ {round(vol, 4)} (normalized)",
            "simple regression (no ML), robust & fast"
        ],
        "last_close": last_close,
        "window_size": len(window),
        "data_source": str(files[-1].name)
    }
    
    # Save bias file with symbol key for multi-symbol support
    out_file = OUT_DIR / f"paula_bias_{symbol}_{datetime.now().strftime('%Y%m%d')}.json"
    out_file.write_text(json.dumps(insight, ensure_ascii=False, indent=2))
    
    log.info(f"✅ Generated bias: {bias} (confidence: {conf:.2f})")
    print(str(out_file))
    
    # Also save to a symbol-keyed file for easy lookup
    symbol_file = OUT_DIR / f"bias_{symbol}_{datetime.now().strftime('%Y%m%d')}.json"
    symbol_file.write_text(json.dumps(insight, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
