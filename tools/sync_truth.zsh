#!/usr/bin/env zsh
set -euo pipefail

ROOT="/Users/icmini/02luka"
MD="$ROOT/02luka.md"
AICTX_DIR="$ROOT/f/ai_context"
AI_ENTRY="$ROOT/ai_context_entry.md"

echo "== 02LUKA Truth Sync (local) =="
date -u +"UTC now: %Y-%m-%dT%H:%M:%SZ"
echo

# 0) Preconditions
if [[ ! -f "$MD" ]]; then
  echo "ERROR: Missing $MD"
  exit 1
fi

mkdir -p "$AICTX_DIR"

# 1) Snapshot backup (timestamped) - no deletes
TS="$(date -u +%Y%m%dT%H%M%SZ)"
BK="$MD.bak.$TS"
cp -a "$MD" "$BK"
echo "Backup: $BK"

# 2) Update / insert Last Updated header line in 02luka.md
#    - If a line containing "Last Updated:" exists, replace it
#    - Else insert near top (within first 20 lines) after first heading if present
python3 - <<PY
import re, pathlib, datetime
md = pathlib.Path("$MD")
s = md.read_text(encoding="utf-8")

now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
line = f"> **Last Updated:** {now}"

lines = s.splitlines()
found = False
for i,l in enumerate(lines):
    if re.search(r"\\bLast Updated\\b\\s*:", l):
        lines[i] = line
        found = True
        break

if not found:
    # insert within first 20 lines after first markdown heading if present
    insert_at = 0
    for i in range(min(20, len(lines))):
        if lines[i].startswith("#"):
            insert_at = i+1
            break
    lines.insert(insert_at, line)

md.write_text("\\n".join(lines) + "\\n", encoding="utf-8")
print("02luka.md header updated to:", now)
PY

# 3) Ensure ai_context_entry.md exists (minimal but valid) OR keep references consistent
if [[ ! -f "$AI_ENTRY" ]]; then
  cat > "$AI_ENTRY" <<EOF
# AI Context Entry (Local Canonical)

This file is the **local** entrypoint for AI agents.

## Canonical Paths
- 02LUKA SSOT: \`$MD\`
- AI context artifacts dir: \`$AICTX_DIR\`

## Notes
- If Google Drive paths are referenced in SSOT, agents must map them to local equivalents under \`$ROOT\`.
- This file is intentionally small; the SSOT remains \`02luka.md\`.
EOF
  echo "Created: $AI_ENTRY"
else
  echo "Exists: $AI_ENTRY"
fi

# 4) Create minimal ai_context artifacts if missing (do NOT overwrite if present)
#    These are stubs to stop routing from breaking.
for f in "01_current_work.json" "03_system_health.json" "ai_daily.json" "ai_read_min.v2.json" "system_map.json"; do
  P="$AICTX_DIR/$f"
  if [[ ! -f "$P" ]]; then
    case "$f" in
      01_current_work.json)
        cat > "$P" <<'EOF'
{"current_work":[],"notes":"stub generated to prevent routing failures"}
EOF
        ;;
      03_system_health.json)
        cat > "$P" <<'EOF'
{"health":"unknown","notes":"stub generated; wire real health generator later"}
EOF
        ;;
      ai_daily.json)
        cat > "$P" <<'EOF'
{"date_utc":null,"daily":[],"notes":"stub generated; expected to be replaced by daily generator"}
EOF
        ;;
      ai_read_min.v2.json)
        cat > "$P" <<'EOF'
{"read_min":["/Users/icmini/02luka/02luka.md","/Users/icmini/02luka/ai_context_entry.md"],"notes":"stub generated"}
EOF
        ;;
      system_map.json)
        cat > "$P" <<'EOF'
{"nodes":[],"edges":[],"notes":"stub generated; replace with system discovery output"}
EOF
        ;;
    esac
    echo "Created stub: $P"
  else
    echo "Exists: $P"
  fi
done

# 5) Evidence output (no assumptions)
echo
echo "== Evidence =="
ls -la "$MD" "$AI_ENTRY" "$AICTX_DIR" | sed -n '1,120p'
echo
echo "Top of 02luka.md:"
sed -n '1,40p' "$MD"
echo
echo "Git state (if repo):"
if command -v git >/dev/null 2>&1 && [[ -d "$ROOT/.git" ]]; then
  (cd "$ROOT" && git status --porcelain && git rev-parse --abbrev-ref HEAD && git rev-parse --short HEAD) || true
else
  echo "No git repo detected at $ROOT"
fi

echo
echo "DONE"
