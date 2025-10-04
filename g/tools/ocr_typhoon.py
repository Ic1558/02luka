#!/usr/bin/env python3
"""Thin wrapper for local OCR using Typhoon-compatible tooling or fallbacks."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Optional, Tuple


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run OCR on an image file using local tooling.")
    parser.add_argument("image", nargs="?", help="Image file to OCR")
    parser.add_argument("--format", choices=["json", "markdown"], default="json")
    parser.add_argument("--ping", action="store_true", help="Health check mode")
    return parser.parse_args()


def try_pytesseract(image_path: Path) -> Optional[Tuple[str, str]]:
    try:
        from PIL import Image  # type: ignore
        import pytesseract  # type: ignore
    except Exception:
        return None

    try:
        image = Image.open(str(image_path))
    except Exception:
        return None

    try:
        text = pytesseract.image_to_string(image)
    except Exception:
        return None
    finally:
        try:
            image.close()
        except Exception:
            pass
    return text.strip(), "pytesseract"


def try_text_file(image_path: Path) -> Optional[Tuple[str, str]]:
    try:
        data = image_path.read_text(encoding="utf-8")
        return data.strip(), "text"
    except Exception:
        return None


def run_ocr(image_path: Path) -> Tuple[str, str]:
    for candidate in (try_pytesseract, try_text_file):
        result = candidate(image_path)
        if result and result[0]:
            return result
    return ("", "unavailable")


def emit_markdown(text: str, backend: str, image_path: Path) -> str:
    summary = text.splitlines()
    snippet = "\n".join(summary[:10])
    return "\n".join(
        [
            "## OCR Result",
            "",
            f"**Backend**: {backend}",
            f"**Source**: `{image_path}`",
            "",
            "```text",
            snippet,
            "```",
        ]
    )


def main() -> int:
    args = parse_args()
    if args.ping:
        payload = {"ok": True, "backend": "typhoon-stub"}
        sys.stdout.write(json.dumps(payload))
        return 0

    if not args.image:
        sys.stderr.write("An image path is required.\n")
        return 2

    image_path = Path(args.image).expanduser().resolve()
    if not image_path.exists():
        payload = {"ok": False, "error": "Image not found", "path": str(image_path)}
        sys.stdout.write(json.dumps(payload))
        return 0

    text, backend = run_ocr(image_path)
    payload = {
        "ok": bool(text),
        "backend": backend,
        "text": text,
        "path": str(image_path),
    }

    if args.format == "markdown":
        payload["markdown"] = emit_markdown(text, backend, image_path)

    sys.stdout.write(json.dumps(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
