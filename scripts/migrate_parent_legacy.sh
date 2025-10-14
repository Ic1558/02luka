#!/usr/bin/env bash
set -euo pipefail

PARENT="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka"
REPO="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"
TS="$(date +%y%m%d_%H%M)"
REPORT="$REPO/g/reports/${TS}_parent_migration_audit.md"

echo "== Preflight =="
[ -d "$PARENT" ] && [ -d "$REPO" ] || { echo "Paths not found"; exit 1; }

# 1) ปลายทางสำหรับ mirror (ไม่ทับ SOT)
mkdir -p "$REPO/boss/legacy_parent" \
         "$REPO/g/legacy_parent" \
         "$REPO/docs/legacy_parent" \
         "$REPO/config/legacy_parent" \
         "$REPO/.trash/parent_backups_${TS}"

# 2) สร้าง manifests (รายการไฟล์ + checksum) เพื่อเทียบภายหลัง
mkdir -p "$REPO/g/reports/proof"
( cd "$PARENT" && find boss g docs -type f 2>/dev/null | sort ) > "$REPO/g/reports/proof/${TS}_parent_files.txt" || true
( cd "$REPO"   && find boss g docs -type f 2>/dev/null | sort ) > "$REPO/g/reports/proof/${TS}_repo_files.txt" || true
( cd "$PARENT" && find boss g docs -type f -maxdepth 1 -print0 2>/dev/null | xargs -0 -I{} sh -c 'shasum -a 256 "{}" || true' ) \
  > "$REPO/g/reports/proof/${TS}_parent_sha256.txt" || true

# 3) Mapping ปลอดภัย (copy-only, --ignore-existing)
echo "== Mirroring parent content =="

# 3.1 boss/*
echo "  boss/ → boss/legacy_parent/"
mkdir -p "$REPO/boss/legacy_parent"
rsync -a --ignore-existing "$PARENT/boss/" "$REPO/boss/legacy_parent/" || true

# 3.2 g/*
# - สำเนา backups → .trash (กักกัน)
if [ -d "$PARENT/g/backups" ]; then
  echo "  g/backups/ → .trash/parent_backups_${TS}/"
  mkdir -p "$REPO/.trash/parent_backups_${TS}"
  rsync -a "$PARENT/g/backups/" "$REPO/.trash/parent_backups_${TS}/" || true
fi
# - ส่วนอื่น ๆ → g/legacy_parent
echo "  g/ → g/legacy_parent/ (excluding backups)"
mkdir -p "$REPO/g/legacy_parent"
rsync -a --ignore-existing \
  --exclude "backups/" \
  "$PARENT/g/" "$REPO/g/legacy_parent/" || true

# 3.3 docs/*
echo "  docs/ → docs/legacy_parent/"
mkdir -p "$REPO/docs/legacy_parent"
rsync -a --ignore-existing "$PARENT/docs/" "$REPO/docs/legacy_parent/" || true

# 3.4 agents/mary (ถ้ามี)
if [ -d "$PARENT/agents/mary" ]; then
  echo "  agents/mary/ → agents/mary/"
  mkdir -p "$REPO/agents/mary"
  rsync -a --ignore-existing "$PARENT/agents/mary/" "$REPO/agents/mary/" || true
fi

# 3.5 memory/autosave (ถ้ามี)
if [ -d "$PARENT/memory/autosave" ]; then
  echo "  memory/autosave/ → memory/autosave/"
  mkdir -p "$REPO/memory/autosave"
  rsync -a --ignore-existing "$PARENT/memory/autosave/" "$REPO/memory/autosave/" || true
fi

# 3.6 ไฟล์พิเศษ
if [ -f "$PARENT/boss/routing.rules.yml" ]; then
  echo "  boss/routing.rules.yml → config/legacy_parent/"
  rsync -a "$PARENT/boss/routing.rules.yml" "$REPO/config/legacy_parent/" || true
fi

# 4) สแกนการอ้างอิงสคริปต์/เอเจนต์ที่ยังชี้ไป parent (ทำรายงาน)
echo "== Scanning references to parent paths =="
PLIST_SCAN="$(mktemp)"; SCRIPT_SCAN="$(mktemp)"
grep -RInE "/My Drive/02luka/(boss|g|docs)" "$HOME/Library/LaunchAgents" 2>/dev/null > "$PLIST_SCAN" || true
grep -RInE "/My Drive/02luka/(boss|g|docs)" "$HOME/Library/02luka_runtime" 2>/dev/null > "$SCRIPT_SCAN" || true

# Count stats
PARENT_BOSS_COUNT=$([ -d "$PARENT/boss" ] && find "$PARENT/boss" -type f 2>/dev/null | wc -l | tr -d ' ' || echo 0)
PARENT_G_COUNT=$([ -d "$PARENT/g" ] && find "$PARENT/g" -type f 2>/dev/null | wc -l | tr -d ' ' || echo 0)
PARENT_DOCS_COUNT=$([ -d "$PARENT/docs" ] && find "$PARENT/docs" -type f 2>/dev/null | wc -l | tr -d ' ' || echo 0)

# 5) สร้างรายงาน
echo "== Generating audit report =="
mkdir -p "$(dirname "$REPORT")"
cat > "$REPORT" <<EOF
---
project: system-stabilization
tags: [ops,migration,audit]
---

# Parent→Repo Safe Mirror — Audit ($TS)

## Summary
- Mirrored **parent → repo** into legacy buckets (no overwrite).
- Created file manifests & checksums.
- Quarantined \`g/backups/\` into \`.trash/parent_backups_${TS}/\`.
- Collected references to parent paths in LaunchAgents & runtime.

## Counts (pre)
- Parent boss:  $PARENT_BOSS_COUNT files
- Parent g:     $PARENT_G_COUNT files
- Parent docs:  $PARENT_DOCS_COUNT files

## Destinations
- boss → \`boss/legacy_parent/\`
- g     → \`g/legacy_parent/\` (except backups → \`.trash/parent_backups_${TS}/\`)
- docs  → \`docs/legacy_parent/\`
- routing.rules.yml → \`config/legacy_parent/\`
- agents/mary → \`agents/mary/\` (if present)
- memory/autosave → \`memory/autosave/\` (if present)

## Artifacts
- Manifests: \`g/reports/proof/${TS}_parent_files.txt\`, \`${TS}_repo_files.txt\`
- Parent SHA256: \`g/reports/proof/${TS}_parent_sha256.txt\`

## Next (Phase B — Cutover Checklist)
1. Update LaunchAgents & runtime scripts to **repo paths** (see appendix).
2. Re-run: \`make boss && make proof\` → verify catalogs & KPIs pass.
3. When zero references to parent remain → convert parent folders to symlink.

## Appendix — References still pointing to parent
### LaunchAgents
\`\`\`
$(cat "$PLIST_SCAN" | sed 's/^/  /')
\`\`\`

### Runtime scripts
\`\`\`
$(cat "$SCRIPT_SCAN" | sed 's/^/  /')
\`\`\`
EOF

rm -f "$PLIST_SCAN" "$SCRIPT_SCAN"
echo ""
echo "✅ Mirror & audit complete → $REPORT"
echo ""
echo "Next steps:"
echo "  1. Review audit report: $REPORT"
echo "  2. Run: make boss && make proof"
echo "  3. Check for parent path references in appendix"
