#!/bin/bash
redis-cli -h 127.0.0.1 -p 6379 -a "changeme-02luka" ping 2>/dev/null || echo "Redis not accessible"
