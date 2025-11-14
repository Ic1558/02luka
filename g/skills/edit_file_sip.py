#!/usr/bin/env python3
"""Skill: edit_file_sip - Safe Idempotent Patch (anchor-based edits)"""
import sys, json, os, time, re

def main():
    try:
        start = time.time()
        data = json.load(sys.stdin)
        params = data.get("params", {})

        filepath = os.path.expanduser(params.get("file", ""))
        anchor = params.get("anchor", "")  # Text to find
        content = params.get("content", "")  # Content to insert
        mode = params.get("mode", "replace")  # replace|insert_after|insert_before

        # Block CloudStorage paths
        if "Library/CloudStorage" in filepath or "My Drive/02luka" in filepath:
            print(json.dumps({"ok": False, "error": "CloudStorage paths not allowed"}))
            sys.exit(0)

        if not os.path.exists(filepath):
            print(json.dumps({"ok": False, "error": f"file not found: {filepath}"}))
            sys.exit(0)

        # Read file
        with open(filepath, 'r') as f:
            lines = f.readlines()

        # Find anchor
        anchor_index = -1
        for i, line in enumerate(lines):
            if anchor in line:
                anchor_index = i
                break

        if anchor_index == -1:
            print(json.dumps({"ok": False, "error": f"anchor not found: {anchor}"}))
            sys.exit(0)

        # Apply edit
        if mode == "replace":
            lines[anchor_index] = content + "\n"
        elif mode == "insert_after":
            lines.insert(anchor_index + 1, content + "\n")
        elif mode == "insert_before":
            lines.insert(anchor_index, content + "\n")
        else:
            print(json.dumps({"ok": False, "error": f"unknown mode: {mode}"}))
            sys.exit(0)

        # Write file
        with open(filepath, 'w') as f:
            f.writelines(lines)

        duration = int((time.time() - start) * 1000)

        print(json.dumps({
            "ok": True,
            "filepath": filepath,
            "mode": mode,
            "anchor_line": anchor_index + 1,
            "duration_ms": duration
        }))
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        sys.exit(0)

if __name__ == "__main__":
    main()
