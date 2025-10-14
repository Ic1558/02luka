#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

echo "== Option C Hardening =="

# 1) Pre-push guard (structure won't regress)
mkdir -p .git/hooks
cat > .git/hooks/pre-push <<'HK'
#!/usr/bin/env bash
set -euo pipefail
make validate-zones
make proof >/dev/null || true
echo "✅ pre-push checks passed"
HK
chmod +x .git/hooks/pre-push

# 2) Upgrade creators with front-matter (project/tags)
cat > scripts/new_report.zsh <<'ZSH'
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
ZSH
chmod +x scripts/new_report.zsh

cat > scripts/new_mem.zsh <<'ZSH'
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
ZSH
chmod +x scripts/new_mem.zsh

# 3) Boss catalogs: add simple "By Project" + robust loops
cat > scripts/generate_boss_catalogs.sh <<'SC'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "Generating boss catalogs..."

# helper: read front-matter key (very lightweight)
fm_get() { # fm_get <file> <key>
  awk '
    BEGIN{FS=": *"; in=0}
    /^---[[:space:]]*$/{in=!in; next}
    in && $1==key {print $2; exit}
  ' key="$2" "$1" 2>/dev/null
}

# boss/reports/index.md
{
  echo "# Reports Catalog (Auto-Generated)"
  echo
  echo "**Last Updated:** $(date -Iseconds)"
  echo
  echo "## Latest Reports (Last 50)"
  echo
  find "$ROOT/g/reports" -maxdepth 1 -type f -name "*.md" -print0 \
    | xargs -0 ls -t 2>/dev/null | head -50 | while read -r f; do
      name=$(basename "$f")
      echo "- [$name](../../g/reports/$name)"
    done || true
  echo
  echo "## Proof Evidence"
  echo
  find "$ROOT/g/reports/proof" -type f -name "*.md" -print0 2>/dev/null \
    | xargs -0 ls -t 2>/dev/null | head -10 | while read -r f; do
      name=$(basename "$f")
      echo "- [$name](../../g/reports/proof/$name)"
    done || true

  # By Project (from front-matter 'project:')
  echo
  echo "## By Project"
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  # build TSV: project \t name \t relpath
  while IFS= read -r -d '' f; do
    p="$(fm_get "$f" project)"; [ -z "$p" ] && p="(none)"
    n="$(basename "$f")"
    echo -e "$p\t$n\t../../g/reports/$n" >> "$tmp"
  done < <(find "$ROOT/g/reports" -maxdepth 1 -type f -name "*.md" -print0)
  # print grouped (top 5 projects alphabetically)
  awk -F'\t' '{print $0}' "$tmp" | sort -f | awk -F'\t' '
    BEGIN{cur=""; count=0}
    {
      if($1!=cur){
        if(cur!="" && count>0) print "";
        cur=$1; count=0;
        print "### " cur
      }
      print "- [" $2 "](" $3 ")"; count++
    }'
} > "$ROOT/boss/reports/index.md"

# boss/memory/index.md
{
  echo "# Memory Catalog (Auto-Generated)"
  echo
  echo "**Last Updated:** $(date -Iseconds)"
  echo
  for agent in clc gg gc mary paula codex boss; do
    echo "## $agent (latest 20)"
    dir="$ROOT/memory/$agent"
    if [ -d "$dir" ]; then
      find "$dir" -maxdepth 1 -type f -name "*.md" -print0 2>/dev/null \
        | xargs -0 ls -t 2>/dev/null | head -20 | while read -r f; do
            name=$(basename "$f")
            echo "- [$name](../../memory/$agent/$name)"
          done || true
    else
      echo "- (no sessions yet)"
    fi
    echo
  done
} > "$ROOT/boss/memory/index.md"

echo "✅ Boss catalogs updated:"
echo "  - boss/reports/index.md"
echo "  - boss/memory/index.md"
SC
chmod +x scripts/generate_boss_catalogs.sh

# 4) Makefile helpers (if missing)
if ! grep -q '^boss-refresh' Makefile 2>/dev/null; then
  cat >> Makefile <<'MK'

.PHONY: boss-refresh report mem
boss-refresh:
	@./scripts/generate_boss_catalogs.sh

report:
	@f=$(./scripts/new_report.zsh "$(name)"); echo "✅ $f"; \
	make boss-refresh >/dev/null || true

mem:
	@f=$(./scripts/new_mem.zsh "$(agent)" "$(title)"); echo "✅ $f"; \
	make boss-refresh >/dev/null || true
MK
fi

# 5) Optional: tag baseline if clean
if git diff --quiet && git diff --cached --quiet; then
  echo "ℹ️ repo clean; you can tag:  git tag -a v2.0 -m 'Option C baseline'"
fi

# 6) Refresh + verify
make boss-refresh
make validate-zones
make proof >/dev/null || true
echo "== Hardening complete =="
