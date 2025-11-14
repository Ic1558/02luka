#!/usr/bin/env zsh
# Codex Sandbox Checker — scans repo for banned command vocabulary.

set -euo pipefail
setopt NO_NOMATCH

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
    print(f"{pattern_id}\t{desc}\t{regex}")' "$SCHEMA_FILE")"

if [[ -z "$pattern_lines" ]]; then
  echo "❌ codex_sandbox_check: no patterns defined in $SCHEMA_FILE" >&2
  exit 2
fi

cd "$REPO_ROOT"

function add_dir_variants() {
  local target_name="$1"
  shift
  local entry
  for entry in "$@"; do
    [[ -z "$entry" ]] && continue
    eval "$target_name+=(\"\$entry\")"
    if [[ "$entry" != g/* ]]; then
      eval "$target_name+=(\"g/$entry\")"
    fi
  done
}

function path_matches_dirs() {
  local rel_path="$1"
  shift
  local dir
  for dir in "$@"; do
    [[ -z "$dir" ]] && continue
    case "$rel_path" in
      "$dir"|"$dir"/*) return 0 ;;
    esac
  done
  return 1
}

function matches_include_file_type() {
  local rel_path="$1"
  local lower="${rel_path:l}"
  case "$lower" in
    *.sh|*.zsh|*.bash|*.py|*.js|*.ts|*.yaml|*.yml) return 0 ;;
  esac
  local base="${rel_path##*/}"
  local base_lower="${base:l}"
  if [[ "$base_lower" == dockerfile* ]]; then
    return 0
  fi
  if [[ "$base" == "Makefile" ]]; then
    return 0
  fi
  return 1
}

function is_excluded_path() {
  local rel_path="$1"
  if path_matches_dirs "$rel_path" "${EXCLUDE_DIRS[@]}"; then
    return 0
  fi
  local lower="${rel_path:l}"
  case "$lower" in
    *.md|*.log|*.jsonl|*.ndjson) return 0 ;;
  esac
  return 1
}

function should_scan_file() {
  local rel_path="$1"
  if is_excluded_path "$rel_path"; then
    return 1
  fi
  if path_matches_dirs "$rel_path" "${INCLUDE_DIRS[@]}"; then
    return 0
  fi
  if matches_include_file_type "$rel_path"; then
    return 0
  fi
  return 1
}

function get_files() {
  local rel_path
  while IFS= read -r -d '' rel_path; do
    if should_scan_file "$rel_path"; then
      FILE_CANDIDATES+=("$rel_path")
    fi
  done < <(git ls-files -z)
}

function search_pattern_in_files() {
  local regex="$1"
  local chunk_size=200
  local -a chunk=()
  local chunk_matches
  local matches=""
  for file_path in "${FILE_CANDIDATES[@]}"; do
    chunk+=("$file_path")
    if (( ${#chunk[@]} == chunk_size )); then
      chunk_matches="$(rg --line-number --no-heading --color=never --pcre2 -e "$regex" "${chunk[@]}" || true)"
      if [[ -n "$chunk_matches" ]]; then
        [[ -n "$matches" ]] && matches+=$'\n'
        matches+="$chunk_matches"
      fi
      chunk=()
    fi
  done

  if (( ${#chunk[@]} )); then
    chunk_matches="$(rg --line-number --no-heading --color=never --pcre2 -e "$regex" "${chunk[@]}" || true)"
    if [[ -n "$chunk_matches" ]]; then
      [[ -n "$matches" ]] && matches+=$'\n'
      matches+="$chunk_matches"
    fi
  fi

  printf '%s' "$matches"
}

typeset -a INCLUDE_DIRS=()
typeset -a EXCLUDE_DIRS=()
typeset -a FILE_CANDIDATES=()

INCLUDE_DIR_BASE=(
  tools
  .github/workflows
  launchd
  launchagents
  LaunchAgents
  scripts
)

EXCLUDE_DIR_BASE=(
  reports
  docs
  telemetry
  analytics
)

add_dir_variants INCLUDE_DIRS "${INCLUDE_DIR_BASE[@]}"
add_dir_variants EXCLUDE_DIRS "${EXCLUDE_DIR_BASE[@]}"

get_files

if (( ${#FILE_CANDIDATES[@]} == 0 )); then
  echo "✅ Codex sandbox check passed (no eligible files to scan)"
  exit 0
fi

VIOLATIONS=()

while IFS=$'\t' read -r pattern_id pattern_desc pattern_regex; do
  [[ -z "$pattern_id" ]] && continue
  matches="$(search_pattern_in_files "$pattern_regex")"
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
