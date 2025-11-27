#!/usr/bin/env python3
"""
CLS Cursor Wrapper - Bridge between Cursor and 02luka LAC/CLS V4.

Usage:
    python tools/cursor_cls_wrapper.py \
        --file-path <file> \
        --command-text "<description>" \
        [--selection-start <line>] \
        [--selection-end <line>] \
        [--base-dir <path>] \
        [--dry-run] \
        [--timeout-seconds <seconds>]
"""

import argparse
import sys
from pathlib import Path

# Add project root to path
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(PROJECT_ROOT))

from tools.cursor_cls_bridge.config import (
    get_base_dir,
    get_inbox_path,
    get_outbox_path,
    get_timeout_seconds,
    get_poll_interval,
)
from tools.cursor_cls_bridge.wo_builder import build_work_order, validate_wo_schema
from tools.cursor_cls_bridge.io_utils import (
    drop_wo_to_inbox,
    poll_for_result,
    format_result_summary,
    format_timeout_message,
    format_error_message,
)


def main():
    parser = argparse.ArgumentParser(
        description="CLS Cursor Wrapper - Send work to 02luka LAC/CLS V4"
    )
    parser.add_argument(
        "--base-dir",
        type=str,
        help="Base directory (default: from LAC_BASE_DIR env or cwd)",
    )
    parser.add_argument(
        "--file-path",
        type=str,
        help="Current file path (relative to base-dir)",
    )
    parser.add_argument(
        "--selection-start",
        type=int,
        help="Selection start line (1-indexed)",
    )
    parser.add_argument(
        "--selection-end",
        type=int,
        help="Selection end line (1-indexed)",
    )
    parser.add_argument(
        "--command-text",
        type=str,
        required=True,
        help="Command text from user (after /cls-apply)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Create WO but don't wait for result",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        help="Timeout for waiting result (default: from env or 60)",
    )
    
    args = parser.parse_args()
    
    try:
        # Get base directory
        base_dir = get_base_dir(args.base_dir)
        
        # Get paths
        inbox_path = get_inbox_path(base_dir)
        outbox_path = get_outbox_path(base_dir)
        
        # Build Work Order
        wo = build_work_order(
            command_text=args.command_text,
            base_dir=base_dir,
            file_path=args.file_path,
            selection_start=args.selection_start,
            selection_end=args.selection_end,
        )
        
        # Validate
        validate_wo_schema(wo)
        
        # Drop to inbox
        wo_file = drop_wo_to_inbox(wo, inbox_path)
        
        wo_id = wo["wo_id"]
        
        if args.dry_run:
            print(f"✅ Work Order created (dry-run): {wo_id}")
            print(f"   Location: {wo_file}")
            print(f"   Not waiting for result.")
            return 0
        
        # Wait for result
        timeout = args.timeout_seconds or get_timeout_seconds()
        poll_interval = get_poll_interval()
        
        print(f"⏳ Waiting for CLS to process WO: {wo_id}...", file=sys.stderr)
        
        result = poll_for_result(
            wo_id=wo_id,
            outbox_path=outbox_path,
            timeout_seconds=timeout,
            poll_interval=poll_interval,
        )
        
        if result is None:
            # Timeout
            message = format_timeout_message(wo_id, outbox_path)
            print(message)
            return 1
        
        # Format and print result
        summary = format_result_summary(result)
        print(summary)
        
        # Check status
        if result.get("status") != "success":
            return 1
        
        return 0
        
    except ValueError as e:
        error_msg = format_error_message("configuration error", str(e))
        print(error_msg, file=sys.stderr)
        print("Please verify base-dir and bridge paths.", file=sys.stderr)
        return 1
    except IOError as e:
        error_msg = format_error_message("I/O error", str(e))
        print(error_msg, file=sys.stderr)
        return 1
    except Exception as e:
        error_msg = format_error_message("unexpected error", str(e))
        print(error_msg, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

