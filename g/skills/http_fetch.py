#!/usr/bin/env python3
"""Skill: http_fetch - GET/POST to local services"""
import sys, json, time, urllib.request, urllib.error

def main():
    try:
        start = time.time()
        data = json.load(sys.stdin)
        params = data.get("params", {})

        url = params.get("url", "")
        method = params.get("method", "GET").upper()
        body = params.get("body", None)
        timeout = params.get("timeout", 30)

        # Block non-local URLs
        if not (url.startswith("http://127.0.0.1") or url.startswith("http://localhost")):
            print(json.dumps({"ok": False, "error": "only localhost URLs allowed"}))
            sys.exit(0)

        # Build request
        req_data = None
        if body and method == "POST":
            req_data = json.dumps(body).encode('utf-8')

        request = urllib.request.Request(url, data=req_data, method=method)
        request.add_header('Content-Type', 'application/json')

        # Execute
        with urllib.request.urlopen(request, timeout=timeout) as response:
            response_body = response.read().decode('utf-8')
            status_code = response.getcode()

        duration = int((time.time() - start) * 1000)

        print(json.dumps({
            "ok": True,
            "status_code": status_code,
            "body": response_body,
            "duration_ms": duration
        }))
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        sys.exit(0)

if __name__ == "__main__":
    main()
