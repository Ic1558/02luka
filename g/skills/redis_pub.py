#!/usr/bin/env python3
"""Skill: redis_pub - Publish JSON to Redis channels"""
import sys, json, os, redis, time

def main():
    try:
        start = time.time()
        data = json.load(sys.stdin)
        params = data.get("params", {})

        channel = params.get("channel", "gg:nlp")
        message = params.get("message", "")

        # Connect to Redis
        host = os.getenv("REDIS_HOST", "localhost")
        port = int(os.getenv("REDIS_PORT", "6379"))
        password = os.getenv("REDIS_PASSWORD", "")

        if password:
            r = redis.Redis(host=host, port=port, password=password, decode_responses=True)
        else:
            r = redis.Redis(host=host, port=port, decode_responses=True)

        # Publish
        count = r.publish(channel, message)
        duration = int((time.time() - start) * 1000)

        print(json.dumps({
            "ok": True,
            "channel": channel,
            "subscribers": count,
            "duration_ms": duration
        }))
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        sys.exit(0)

if __name__ == "__main__":
    main()
