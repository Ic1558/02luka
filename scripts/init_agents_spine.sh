#!/usr/bin/env bash
set -euo pipefail
agents=(clc gg gc mary paula codex boss)
mkdir -p agents
for a in "${agents[@]}"; do
  dir="agents/$a"; mkdir -p "$dir"
  [ -f "$dir/README.md" ] && continue
  cat > "$dir/README.md" <<EOF
# Agent: $a

**Memory:** [memory/$a/](../../memory/$a/)
**Owner:** $a

## Scope
- (fill key responsibilities)

## Commands
- Create memo: \`make mem agent=$a title="Note"\`
- Search boss: \`make boss-find q="…"\`
EOF
done

cat > agents/index.md <<'MD'
# Agents Overview
- [clc](clc/README.md) — human ops & reports
- [gg](gg/README.md) — research
- [gc](gc/README.md) — calendar/orchestrator
- [mary](mary/README.md)
- [paula](paula/README.md)
- [codex](codex/README.md) — code & automation
- [boss](boss/README.md)
MD
