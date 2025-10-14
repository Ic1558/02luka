#!/usr/bin/env zsh
set -euo pipefail
name="${1:?usage: new_report 'Short Title'}"
project="${PROJECT:-general}"
tags="${TAGS:-ops}"
slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')
ts=$(date +%y%m%d_%H%M)
out="g/reports/${ts}_${slug}.md"
mkdir -p g/reports
cat > "$out" <<EOF
---
project: $project
tags: [${tags}]
---
# $name

- Created: $(date -Iseconds)

EOF
echo "$out"
