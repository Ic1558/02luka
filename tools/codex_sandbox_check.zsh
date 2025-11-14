#!/usr/bin/env zsh
# Codex Sandbox Checker — scans repo for banned command vocabulary.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEMA_FILE="$REPO_ROOT/schemas/codex_disallowed_commands.yaml"
LIST_ONLY=0

if [[ "${1:-}" == "--list-only" ]]; then
  LIST_ONLY=1
fi

if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "❌ codex_sandbox_check: schema not found at $SCHEMA_FILE" >&2
  exit 2
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "❌ codex_sandbox_check: ripgrep (rg) is required." >&2
  exit 2
fi

PYTHON_BIN="python3"
if ! command -v python3 >/dev/null 2>&1 && command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
fi

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "❌ codex_sandbox_check: python is required to read $SCHEMA_FILE" >&2
  exit 2
fi

pattern_lines="$("$PYTHON_BIN" -c 'import json, sys, pathlib
schema = pathlib.Path(sys.argv[1])
data = json.loads(schema.read_text(encoding="utf-8"))
for item in data.get("patterns", []):
    pattern_id = item.get("id", "")
    desc = item.get("description", "")
    regex = item.get("regex", "")
    print(f"{pattern_id}\\t{desc}\\t{regex}")' "$SCHEMA_FILE")"

if [[ -z "$pattern_lines" ]]; then
  echo "❌ codex_sandbox_check: no patterns defined in $SCHEMA_FILE" >&2
  exit 2
fi

VIOLATIONS=()
EXCLUDES=(
  "--hidden"
  "--glob" "!.git"
  "--glob" "!g/.git"
  "--glob" "!.backup/**"
  "--glob" "!g/.backup/**"
  "--glob" "!node_modules"
  "--glob" "!g/node_modules"
  "--glob" "!__pycache__"
  "--glob" "!g/__pycache__"
  "--glob" "!dist"
  "--glob" "!build"
  "--glob" "!logs"
  "--glob" "!g/logs"
  "--glob" "!__artifacts__/**"
  "--glob" "!g/__artifacts__/**"
  "--glob" "!_memory/**"
  "--glob" "!g/_memory/**"
  "--glob" "!g/g/**"
)

INCLUDES=(
  "--glob" "docs/**"
  "--glob" "manuals/**"
  "--glob" "reports/**"
  "--glob" "g/docs/**"
  "--glob" "g/manuals/**"
  "--glob" "g/reports/**"
  "--glob" "config/**"
  "--glob" "g/config/**"
  "--glob" "tools/**"
  "--glob" "g/tools/**"
  "--glob" "scripts/**"
  "--glob" "g/scripts/**"
  "--glob" "run/**"
  "--glob" "g/run/**"
  "--glob" "bridge/**"
  "--glob" "g/bridge/**"
  "--glob" "LaunchAgents/**"
  "--glob" "g/LaunchAgents/**"
  "--glob" ".github/workflows/**"
  "--glob" "g/.github/workflows/**"
  "--glob" "*.md"
  "--glob" "*.yaml"
  "--glob" "*.yml"
  "--glob" "*.zsh"
  "--glob" "*.sh"
  "--glob" "*.py"
  "--glob" "Makefile"
  "--glob" "g/Makefile"
)

while IFS=$'\t' read -r pattern_id pattern_desc pattern_regex; do
  [[ -z "$pattern_id" ]] && continue
  matches="$(rg --line-number --no-heading --color=never --pcre2 "${INCLUDES[@]}" "${EXCLUDES[@]}" -e "$pattern_regex" "$REPO_ROOT" || true)"
  if [[ -n "$matches" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      VIOLATIONS+=("$pattern_id|$pattern_desc|$line")
    done <<< "$matches"
  fi
done <<< "$pattern_lines"

if (( ${#VIOLATIONS[@]} == 0 )); then
  echo "✅ Codex sandbox check passed (0 violations)"
  exit 0
fi

printf '❌ Codex sandbox check failed – %d violation(s) found:\n' "${#VIOLATIONS[@]}" >&2
for violation in "${VIOLATIONS[@]}"; do
  IFS='|' read -r vid vdesc vline <<< "$violation"
  printf '  [%s] %s → %s\n' "$vid" "$vdesc" "$vline" >&2
done

if [[ "$LIST_ONLY" == "1" ]]; then
  exit 0
fi

exit 1
