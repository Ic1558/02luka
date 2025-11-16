#!/usr/bin/env python3
"""Skill: report_markdown - Compile markdown reports"""
import sys, json, os, time
from datetime import datetime

def main():
    try:
        start = time.time()
        data = json.load(sys.stdin)
        params = data.get("params", {})

        title = params.get("title", "Report")
        content = params.get("content", "")
        filename = params.get("filename", f"{datetime.now().strftime('%y%m%d_%H%M%S')}_report.md")

        # Reports directory
        reports_dir = os.path.expanduser("~/02luka/logs/reports")
        os.makedirs(reports_dir, exist_ok=True)

        filepath = os.path.join(reports_dir, filename)

        # Generate markdown
        markdown = f"# {title}\n\n"
        markdown += f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
        markdown += "---\n\n"
        markdown += content

        # Write file
        with open(filepath, 'w') as f:
            f.write(markdown)

        duration = int((time.time() - start) * 1000)

        print(json.dumps({
            "ok": True,
            "filepath": filepath,
            "size_bytes": len(markdown),
            "duration_ms": duration
        }))
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        sys.exit(0)

if __name__ == "__main__":
    main()
