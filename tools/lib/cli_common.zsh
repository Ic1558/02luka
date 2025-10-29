#!/usr/bin/env zsh
# Common helpers for CLS/CLC tooling
set -euo pipefail

# Emit a timestamp suitable for logs.
ts() {
  date "+%Y-%m-%d %H:%M:%S"
}

# Print an error message and exit with the provided status code (default 1).
die() {
  local exit_code=1
  if [[ $# -gt 1 ]]; then
    exit_code=$2
  fi
  print -u2 -- "$(ts) ERROR: $1"
  exit $exit_code
}

# Compute a SHA-256 hash for the provided file or string.
sha256() {
  if [[ $# -eq 0 ]]; then
    die "sha256 requires a file path or string argument"
  fi

  if [[ -f $1 ]]; then
    if command -v shasum >/dev/null 2>&1; then
      shasum -a 256 "$1" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
      sha256sum "$1" | awk '{print $1}'
    else
      die "No SHA-256 tool found on PATH"
    fi
  else
    if command -v shasum >/dev/null 2>&1; then
      print -- "$1" | shasum -a 256 | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
      print -- "$1" | sha256sum | awk '{print $1}'
    else
      die "No SHA-256 tool found on PATH"
    fi
  fi
}

# Ensure a required binary exists on PATH.
require_cmd() {
  local cmd=$1
  command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
}
