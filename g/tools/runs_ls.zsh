#!/usr/bin/env zsh
# List LaunchAgent Self-Recovery Check workflow runs
# Usage: runs_ls.zsh [LIMIT]
# Example: runs_ls.zsh 10

set -euo pipefail

LIMIT="${1:-10}"

gh run list --workflow "launchd-selfcheck.yml" -L "$LIMIT" \
  --json databaseId,headSha,displayTitle,status,conclusion,createdAt,event | \
  jq -r '.[] | [.databaseId, .status, .conclusion, .headSha[0:7], .displayTitle] | @tsv'
