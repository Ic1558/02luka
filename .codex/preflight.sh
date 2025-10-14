#!/usr/bin/env bash
set -euo pipefail

# Source universal path resolver
source "$(dirname "$0")/../scripts/repo_root_resolver.sh"
ROOT="${SOT_PATH:-$REPO_ROOT}"

# 1) Generate latest system map (best-effort)
python3 "$ROOT/g/tools/render_system_map.py" 2>/dev/null || true

# 2) Validate mapping (warn only; Codex should still proceed)
if bash "$ROOT/g/tools/mapping_drift_guard.sh" --validate >/dev/null 2>&1; then
  echo "[02luka] mapping validation: OK"
else
  echo "[02luka] mapping validation: WARN (continue)"
fi

# 3) Print key namespaces to log (helps Codex reasoning)
if [ -f "$ROOT/f/ai_context/mapping.json" ]; then
  echo "[02luka] namespaces:"
  jq -r '.namespaces | to_entries[] | .key + ": " + ( .value | keys | join(",") )' "$ROOT/f/ai_context/mapping.json" || true
fi

# 4) Copy latest system reports for human mailbox visibility
REPORT_SRC="$ROOT/g/reports"
REPORT_DST="$ROOT/boss/sent"
if [ -d "$REPORT_SRC" ]; then
  REPORT_FILES=()
  while IFS= read -r -d '' report_path; do
    REPORT_FILES+=("$report_path")
  done < <(find "$REPORT_SRC" -maxdepth 1 -type f \( -name '*.md' -o -name '*.txt' -o -name '*.html' \) -print0 2>/dev/null)

  if [ "${#REPORT_FILES[@]}" -gt 0 ]; then
    mkdir -p "$REPORT_DST"
    for report_file in "${REPORT_FILES[@]}"; do
      base_name="$(basename "$report_file")"
      cp "$report_file" "$REPORT_DST/system_${base_name}" 2>/dev/null || true
    done
    echo "[02luka] synced system reports to boss/sent/."
  fi
fi

echo "[02luka] preflight ready."

# Check for duplicate clones (warn if they differ)
if [ -d "$HOME/dev/02luka-repo/.git" ]; then
  cur="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || true)"
  old="$(git -C "$HOME/dev/02luka-repo" rev-parse --short HEAD 2>/dev/null || true)"
  if [ -n "$old" ] && [ "$cur" != "$old" ]; then
    echo "[warn] Another checkout at ~/dev/02luka-repo (commit $old) differs from current (commit $cur)."
    echo "[warn] Consider updating or removing the old clone to avoid confusion."
  fi
fi

# Check master prompt presence
if [ ! -s ".codex/templates/master_prompt.md" ]; then
  echo "[preflight] WARN: .codex/templates/master_prompt.md missing or empty"
else
  echo "[preflight] master_prompt: OK"
fi
