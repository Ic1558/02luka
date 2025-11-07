#!/usr/bin/env zsh
# Guard: Enforce pinned faiss-cpu version
# Fails CI if faiss-cpu is not pinned (uses >= instead of ==)

set -eo pipefail

if grep -RInE 'faiss-cpu[^#\n]*>=' requirements.txt 2>/dev/null; then
  echo "[FAIL] faiss-cpu must be pinned (==). Found a lower-bound (>=) in requirements.txt" >&2
  exit 1
fi

if ! grep -RInE '^faiss-cpu==[0-9]+\.[0-9]+\.[0-9]+' requirements.txt >/dev/null 2>&1; then
  echo "[FAIL] faiss-cpu missing or not pinned in requirements.txt" >&2
  exit 1
fi

echo "[OK] faiss-cpu pinned correctly."

