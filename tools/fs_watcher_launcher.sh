#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PYTHONUNBUFFERED=1
echo "Starting fs_watcher launcher at $(date)"
exec /opt/homebrew/bin/python3 /Users/icmini/02luka/tools/fs_watcher.py
