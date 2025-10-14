#!/usr/bin/env zsh
set -euo pipefail
agent="${1:?agent (clc|gg|gc|mary|paula|codex|boss)}"; shift
title="${*:-note}"
tags="${TAGS:-note}"
slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')
ts=$(date +%y%m%d_%H%M)
dir="memory/$agent"; mkdir -p "$dir"
out="$dir/session_${ts}_${slug}.md"
cat > "$out" <<EOF
---
agent: $agent
tags: [${tags}]
---
# $title

- Created: $(date -Iseconds)

EOF
echo "$out"
