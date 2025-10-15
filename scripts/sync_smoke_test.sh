#!/usr/bin/env bash
# Sync smoke test helper – exercises rsync flows with guardrails against hangs
set -euo pipefail

PASS=0
WARN=0
FAIL=0

DEFAULT_TIMEOUT=20
TIMEOUT=$DEFAULT_TIMEOUT
SOURCE_PATH=""
TARGET_PATH=""
KEEP_TMP=0
VERBOSE=0
DRY_RUN_ONLY=0
RSYNC_ARGS=()
CONFIG_PATH=""
LIST_GROUPS=0
DISABLE_CONFIG=0
SELECTED_GROUPS=()

usage() {
  cat <<'USAGE'
Sync smoke test helper

Usage: scripts/sync_smoke_test.sh [options]

Options:
  --source <path>       Source file or directory to validate
  --target <path>       Target file or directory representing sync destination
  --timeout <seconds>   Timeout per command (0 to disable, default: 20)
  --rsync-arg <arg>     Extra argument forwarded to rsync (repeatable)
  --dry-run-only        Skip full sync to temp workspace (only dry-run real destination)
  --keep-tmp            Do not delete the temporary workspace (for debugging)
  --config <file>       YAML config describing sync groups (default: g/bridges/memory_index.yml)
  --group <name>        Only run the named sync group (repeatable)
  --list-groups         List available sync groups from the config and exit
  --no-config           Force manual mode even if a config file exists
  --verbose, -v         Print command output even on success
  --help                Show this help and exit

Examples:
  # Manual mode with defaults (Cursor ↔︎ CLC memory)
  scripts/sync_smoke_test.sh

  # Run every sync group defined in memory_index.yml
  scripts/sync_smoke_test.sh --config g/bridges/memory_index.yml

  # Target a single group from config
  scripts/sync_smoke_test.sh --group active_memory_sources
USAGE
}

report() {
  local status="$1"; shift
  local message="$1"; shift
  case "$status" in
    PASS)
      PASS=$((PASS + 1))
      printf '✅ %s\n' "$message"
      ;;
    WARN)
      WARN=$((WARN + 1))
      printf '⚠️  %s\n' "$message"
      ;;
    FAIL)
      FAIL=$((FAIL + 1))
      printf '❌ %s\n' "$message"
      ;;
  esac
}

while (( "$#" )); do
  case "$1" in
    --source)
      SOURCE_PATH="$2"; shift 2 ;;
    --target)
      TARGET_PATH="$2"; shift 2 ;;
    --timeout)
      if [[ "$2" =~ ^[0-9]+$ ]]; then
        TIMEOUT="$2"
      else
        echo "Invalid timeout: $2" >&2
        exit 1
      fi
      shift 2 ;;
    --rsync-arg)
      RSYNC_ARGS+=("$2"); shift 2 ;;
    --dry-run-only)
      DRY_RUN_ONLY=1; shift ;;
    --keep-tmp)
      KEEP_TMP=1; shift ;;
    --config)
      CONFIG_PATH="$2"; shift 2 ;;
    --group)
      SELECTED_GROUPS+=("$2"); shift 2 ;;
    --list-groups)
      LIST_GROUPS=1; shift ;;
    --no-config)
      DISABLE_CONFIG=1; shift ;;
    --verbose|-v)
      VERBOSE=1; shift ;;
    --help)
      usage
      exit 0 ;;
    --)
      shift
      break ;;
    -*|--*)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
    *)
      break ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -f "$REPO_ROOT/.git" ]]; then
  REPO_ROOT="$(cd "$REPO_ROOT" && git rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT")"
fi

pretty_path() {
  local path="$1"
  if [[ -z "$path" ]]; then
    echo "(none)"
    return
  fi
  if [[ "$path" == "$REPO_ROOT" ]]; then
    echo "."
    return
  fi
  if [[ "$path" == "$REPO_ROOT"/* ]]; then
    printf './%s\n' "${path#"$REPO_ROOT"/}"
  else
    printf '%s\n' "$path"
  fi
}

abspath() {
  python3 - "$1" <<'PY'
import os, sys
print(os.path.abspath(sys.argv[1]))
PY
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    report FAIL "Missing required command: $1"
    echo "Install $1 to run the sync smoke test." >&2
    exit 1
  fi
}

require_cmd rsync
require_cmd python3
require_cmd diff

if ! python3 -c "import yaml" >/dev/null 2>&1; then
  echo "Missing required Python module: PyYAML (import yaml)." >&2
  echo "Install with: pip install --user PyYAML" >&2
  exit 1
fi

if [[ -n "$CONFIG_PATH" ]]; then
  CONFIG_PATH="$(abspath "$CONFIG_PATH")"
fi

manual_mode=0
if [[ -n "$SOURCE_PATH" || -n "$TARGET_PATH" ]]; then
  manual_mode=1
fi

if (( DISABLE_CONFIG == 0 )) && (( manual_mode == 0 )) && [[ -z "$CONFIG_PATH" ]]; then
  if [[ -f "$REPO_ROOT/g/bridges/memory_index.yml" ]]; then
    CONFIG_PATH="$REPO_ROOT/g/bridges/memory_index.yml"
  fi
fi

if (( LIST_GROUPS == 1 )); then
  if [[ -z "$CONFIG_PATH" ]]; then
    echo "No config file available to list groups." >&2
    exit 1
  fi
  python3 - "$REPO_ROOT" "$CONFIG_PATH" "${SELECTED_GROUPS[@]}" <<'PY'
import os, sys, yaml
repo = sys.argv[1]
config = sys.argv[2]
selected = sys.argv[3:]
if not os.path.exists(config):
    print(f"Config not found: {config}", file=sys.stderr)
    sys.exit(1)
with open(config, 'r', encoding='utf-8') as fh:
    data = yaml.safe_load(fh) or {}

groups = [
    key for key, value in data.items()
    if key.endswith('_sources') and isinstance(value, list)
]
if selected:
    missing = [name for name in selected if name not in groups]
    if missing:
        print(f"Unknown group(s): {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)
    groups = [name for name in groups if name in selected]
if not groups:
    print("No sync groups defined in config.")
    sys.exit(0)
print("Available sync groups:")
for name in groups:
    print(f"  - {name}")
PY
  exit 0
fi

if (( manual_mode == 1 )) || [[ -z "$CONFIG_PATH" ]]; then
  manual_mode=1
  if [[ -z "$SOURCE_PATH" ]]; then
    SOURCE_PATH="$REPO_ROOT/.codex/hybrid_memory_system.md"
  fi
  if [[ -z "$TARGET_PATH" ]]; then
    TARGET_PATH="$REPO_ROOT/a/section/clc/memory/active_memory.md"
  fi
  SOURCE_PATH="$(abspath "$SOURCE_PATH")"
  TARGET_PATH="$(abspath "$TARGET_PATH")"
else
  CONFIG_PATH="$(abspath "$CONFIG_PATH")"
fi

TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="$(command -v timeout)"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="$(command -v gtimeout)"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sync-smoke.XXXXXX")"
cleanup() {
  if (( KEEP_TMP == 0 )) && [[ -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  else
    [[ -d "$TMP_DIR" ]] && echo "Temporary workspace preserved at: $TMP_DIR"
  fi
}
trap cleanup EXIT

STEP_INDEX=0
PAIR_INDEX=0
LAST_LOG_FILE=""
LAST_RC=0
LAST_TIMED_OUT=0
CHILD_PIDS=()

remove_child_pid() {
  local target="$1"
  local updated=()
  for pid in "${CHILD_PIDS[@]:-}"; do
    if [[ "$pid" != "$target" ]]; then
      updated+=("$pid")
    fi
  done
  CHILD_PIDS=("${updated[@]:-}")
}

with_timeout() {
  STEP_INDEX=$((STEP_INDEX + 1))
  local log_file="$TMP_DIR/step_${STEP_INDEX}.log"
  local timed_out=0
  local rc=0

  if [[ "$TIMEOUT" -eq 0 ]]; then
    set +e
    "$@" >"$log_file" 2>&1
    rc=$?
    set -e
  elif [[ -n "$TIMEOUT_BIN" ]]; then
    set +e
    "$TIMEOUT_BIN" --preserve-status "$TIMEOUT" "$@" >"$log_file" 2>&1
    rc=$?
    set -e
    if [[ $rc -eq 124 ]]; then
      timed_out=1
    fi
  else
    set +e
    "$@" >"$log_file" 2>&1 &
    local cmd_pid=$!
    CHILD_PIDS+=("$cmd_pid")
    local start_ts=$(date +%s)
    while kill -0 "$cmd_pid" >/dev/null 2>&1; do
      sleep 1
      local now=$(date +%s)
      if (( now - start_ts >= TIMEOUT )); then
        timed_out=1
        kill -TERM "$cmd_pid" >/dev/null 2>&1 || true
        sleep 1
        kill -KILL "$cmd_pid" >/dev/null 2>&1 || true
        wait "$cmd_pid" >/dev/null 2>&1 || true
        rc=124
        break
      fi
    done
    if (( timed_out == 0 )); then
      wait "$cmd_pid"
      rc=$?
    fi
    remove_child_pid "$cmd_pid"
    set -e
  fi

  LAST_LOG_FILE="$log_file"
  LAST_RC=$rc
  LAST_TIMED_OUT=$timed_out
}

print_log_if_needed() {
  local reason="$1"
  if [[ $VERBOSE -eq 1 || "$reason" != "pass" ]]; then
    if [[ -s "$LAST_LOG_FILE" ]]; then
      sed 's/^/      /' "$LAST_LOG_FILE"
    fi
  fi
}

run_step() {
  local label="$1"; shift
  local severity="$1"; shift
  with_timeout "$@"
  local rc=$LAST_RC
  local timed_out=$LAST_TIMED_OUT
  local message

  if (( rc == 0 )); then
    report PASS "$label"
    print_log_if_needed pass
    return 0
  fi

  if (( timed_out == 1 )); then
    message="$label (timed out after ${TIMEOUT}s)"
  else
    message="$label (exit $rc)"
  fi

  if [[ "$severity" == "warn" ]]; then
    report WARN "$message"
  else
    report FAIL "$message"
  fi
  print_log_if_needed fail
  return $rc
}

path_kind() {
  local path="$1"
  if [[ -d "$path" ]]; then
    echo "dir"
  elif [[ -f "$path" ]]; then
    echo "file"
  else
    echo "missing"
  fi
}

path_display() {
  local kind="$1"
  case "$kind" in
    dir) echo "directory" ;;
    file) echo "file" ;;
    missing) echo "missing" ;;
  esac
}

compare_entities() {
  local context="$1"
  local source="$2"
  local target="$3"
  local source_kind="$4"
  local target_kind="$5"

  if [[ "$target_kind" == "missing" ]]; then
    return
  fi

  if [[ "$source_kind" == "dir" && "$target_kind" == "dir" ]]; then
    with_timeout diff -qr "$source" "$target"
    if [[ $LAST_TIMED_OUT -eq 1 ]]; then
      report WARN "$context Directory comparison timed out after ${TIMEOUT}s"
      print_log_if_needed fail
    else
      case $LAST_RC in
        0)
          report PASS "$context Source and target directories already in sync"
          ;;
        1)
          report WARN "$context Source and target directories differ"
          head -n 40 "$LAST_LOG_FILE" | sed 's/^/      /'
          ;;
        *)
          report FAIL "$context Directory comparison failed (exit $LAST_RC)"
          print_log_if_needed fail
          ;;
      esac
    fi
  elif [[ "$source_kind" == "file" && "$target_kind" == "file" ]]; then
    with_timeout cmp "$source" "$target"
    if [[ $LAST_TIMED_OUT -eq 1 ]]; then
      report WARN "$context File comparison timed out after ${TIMEOUT}s"
      print_log_if_needed fail
    else
      case $LAST_RC in
        0)
          report PASS "$context Source and target files match"
          ;;
        1)
          report WARN "$context Source and target files differ"
          print_log_if_needed fail
          ;;
        *)
          report FAIL "$context File comparison failed (exit $LAST_RC)"
          print_log_if_needed fail
          ;;
      esac
    fi
  else
    report WARN "$context Source/target type mismatch ($source_kind vs $target_kind); skipping diff"
  fi
}

run_sync_suite() {
  local group_label="$1"
  local strategy="$2"
  local source_label="$3"
  local source_path="$4"
  local target_label="$5"
  local target_path="$6"
  local resolution_note="$7"
  local target_origin="$8"

  PAIR_INDEX=$((PAIR_INDEX + 1))
  local context="[$group_label][$source_label→$target_label]"

  printf '\n--- %s %s → %s ---\n' "[$group_label]" "$source_label" "$target_label"
  echo "Source:    $(pretty_path "$source_path")"
  if [[ -n "$target_origin" && "$target_origin" != "$target_path" ]]; then
    echo "Target:    $(pretty_path "$target_origin")"
    echo "Resolved:  $(pretty_path "$target_path") (${resolution_note:-direct})"
  else
    echo "Target:    $(pretty_path "$target_path")"
    if [[ -n "$resolution_note" && "$resolution_note" != "direct" ]]; then
      echo "Note:      $resolution_note"
    fi
  fi
  if [[ -n "$strategy" ]]; then
    echo "Strategy:  $strategy"
  fi

  local source_kind="$(path_kind "$source_path")"
  local target_kind="$(path_kind "$target_path")"

  if [[ "$source_kind" == "missing" ]]; then
    report FAIL "$context Source missing: $(pretty_path "$source_path")"
    return
  else
    report PASS "$context Source detected as $(path_display "$source_kind")"
  fi

  if [[ "$target_kind" == "missing" ]]; then
    if [[ -n "$target_path" ]]; then
      report WARN "$context Target missing: $(pretty_path "$target_path")"
    else
      report WARN "$context Target path not provided"
    fi
  else
    report PASS "$context Target detected as $(path_display "$target_kind")"
  fi

  if [[ -n "$target_origin" && "$target_origin" != "$target_path" ]]; then
    report PASS "$context Target auto-resolved to $(pretty_path "$target_path")"
  fi

  compare_entities "$context" "$source_path" "$target_path" "$source_kind" "$target_kind"

  local dest_parent=""
  if [[ "$target_kind" == "dir" ]]; then
    dest_parent="$target_path"
  else
    dest_parent="$(dirname "$target_path")"
  fi

  if [[ -d "$dest_parent" ]]; then
    local label="$context rsync dry-run → $(pretty_path "$dest_parent")"
    if [[ "$source_kind" == "dir" ]]; then
      run_step "$label" fail rsync -a --dry-run "${RSYNC_ARGS[@]}" "$source_path/" "$dest_parent/"
    else
      run_step "$label" fail rsync -a --dry-run "${RSYNC_ARGS[@]}" "$source_path" "$dest_parent/"
    fi
  else
    report WARN "$context Destination directory missing for dry-run: $(pretty_path "$dest_parent")"
  fi

  if (( DRY_RUN_ONLY == 0 )) && [[ "$source_kind" != "missing" ]]; then
    local pair_tmp="$TMP_DIR/pair_${PAIR_INDEX}"
    local tmp_dest="$pair_tmp/dest"
    mkdir -p "$tmp_dest"

    if [[ "$source_kind" == "dir" ]]; then
      local base="$(basename "$source_path")"
      mkdir -p "$tmp_dest/$base"
      run_step "$context rsync to temp workspace" fail rsync -a "${RSYNC_ARGS[@]}" "$source_path/" "$tmp_dest/$base/"
      with_timeout diff -qr "$source_path" "$tmp_dest/$base"
      if [[ $LAST_TIMED_OUT -eq 1 ]]; then
        report WARN "$context Temp verification timed out after ${TIMEOUT}s"
        print_log_if_needed fail
      else
        case $LAST_RC in
          0)
            report PASS "$context Temp copy matches source directory"
            ;;
          1)
            report FAIL "$context Temp copy differs from source directory"
            print_log_if_needed fail
            ;;
          *)
            report FAIL "$context Temp verification failed (exit $LAST_RC)"
            print_log_if_needed fail
            ;;
        esac
      fi
    else
      run_step "$context rsync to temp workspace" fail rsync -a "${RSYNC_ARGS[@]}" "$source_path" "$tmp_dest/"
      local tmp_file="$tmp_dest/$(basename "$source_path")"
      with_timeout cmp "$source_path" "$tmp_file"
      if [[ $LAST_TIMED_OUT -eq 1 ]]; then
        report WARN "$context Temp cmp timed out after ${TIMEOUT}s"
        print_log_if_needed fail
      else
        case $LAST_RC in
          0)
            report PASS "$context Temp copy matches source file"
            ;;
          1)
            report FAIL "$context Temp copy differs from source file"
            print_log_if_needed fail
            ;;
          *)
            report FAIL "$context Temp verification failed (exit $LAST_RC)"
            print_log_if_needed fail
            ;;
        esac
      fi
    fi
  fi
}

load_pairs_from_config() {
  python3 - "$REPO_ROOT" "$CONFIG_PATH" "${SELECTED_GROUPS[@]}" <<'PY'
import json, os, sys, yaml
repo = sys.argv[1]
config = sys.argv[2]
selected = sys.argv[3:]
if not os.path.exists(config):
    print(f"Config not found: {config}", file=sys.stderr)
    sys.exit(1)
with open(config, 'r', encoding='utf-8') as fh:
    data = yaml.safe_load(fh) or {}

groups = {
    key: value for key, value in data.items()
    if key.endswith('_sources') and isinstance(value, list)
}
if not groups:
    print("No sync groups defined in config.", file=sys.stderr)
    sys.exit(1)
if selected:
    missing = [name for name in selected if name not in groups]
    if missing:
        print(f"Unknown group(s): {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)
    items = {name: groups[name] for name in selected}
else:
    items = groups
strategy = data.get('sync_strategy', '')

def normalize(entry, idx):
    if isinstance(entry, str):
        entry = {"path": entry}
    elif not isinstance(entry, dict):
        entry = {}
    entry.setdefault('path', '')
    entry.setdefault('type', f'entry_{idx}')
    entry['index'] = idx
    return entry

def prepare(entry):
    rel = entry.get('path', '')
    abs_path = os.path.abspath(os.path.join(repo, rel)) if rel else ''
    kind = 'missing'
    if abs_path:
        if os.path.isdir(abs_path):
            kind = 'dir'
        elif os.path.isfile(abs_path):
            kind = 'file'
    exists = os.path.exists(abs_path)
    label = entry.get('label') or entry.get('type') or (os.path.basename(rel) if rel else f"entry_{entry.get('index', 0)}")
    return {
        'label': label,
        'rel_path': rel,
        'abs_path': abs_path,
        'kind': kind,
        'exists': exists,
        'type': entry.get('type', '')
    }

for group_name, entries in items.items():
    if not entries:
        continue
    canon = normalize(entries[0], 0)
    source = prepare(canon)
    print(f"GROUP|{group_name}|{strategy}|{source['label']}|{source['abs_path']}|{source['kind']}|{int(source['exists'])}")
    for idx, raw in enumerate(entries[1:], start=1):
        entry = prepare(normalize(raw, idx))
        resolved_path = entry['abs_path']
        resolved_kind = entry['kind']
        note = 'direct'
        if entry['kind'] == 'dir' and entry['exists']:
            candidates = []
            source_base = os.path.basename(source['abs_path']) if source['abs_path'] else ''
            if source_base:
                candidates.append(source_base)
            candidates.extend([
                'active_memory.md',
                'active_memory.yml',
                'active_memory.yaml',
                'memory.md'
            ])
            found = ''
            for candidate in candidates:
                candidate_path = os.path.join(entry['abs_path'], candidate)
                if os.path.isfile(candidate_path):
                    found = candidate_path
                    note = f"auto:{candidate}"
                    break
            if not found:
                try:
                    files = [name for name in os.listdir(entry['abs_path']) if os.path.isfile(os.path.join(entry['abs_path'], name))]
                except OSError:
                    files = []
                if len(files) == 1:
                    found = os.path.join(entry['abs_path'], files[0])
                    note = f"auto:{files[0]}"
            if found:
                resolved_path = os.path.abspath(found)
                resolved_kind = 'file'
        print(
            "PAIR|{group}|{label}|{path}|{kind}|{exists}|{resolved}|{resolved_kind}|{note}".format(
                group=group_name,
                label=entry['label'],
                path=entry['abs_path'],
                kind=entry['kind'],
                exists=int(entry['exists']),
                resolved=resolved_path,
                resolved_kind=resolved_kind,
                note=note
            )
        )
PY
}

cat <<HEADER
=== Sync Smoke Test ===
Repo root: $(pretty_path "$REPO_ROOT")
Timeout:   ${TIMEOUT}s per command
Dry-run:   $([[ $DRY_RUN_ONLY -eq 1 ]] && echo yes || echo no)
HEADER

if (( manual_mode == 1 )); then
  echo "Mode:     manual"
else
  echo "Mode:     config"
  echo "Config:   $(pretty_path "$CONFIG_PATH")"
  if ((${#SELECTED_GROUPS[@]} > 0)); then
    printf 'Groups:   %s\n' "${SELECTED_GROUPS[*]}"
  fi
fi

if (( manual_mode == 1 )); then
  local_source_label="$(basename "$SOURCE_PATH")"
  local_target_label="$(basename "$TARGET_PATH")"
  run_sync_suite "manual" "manual" "$local_source_label" "$SOURCE_PATH" "$local_target_label" "$TARGET_PATH" "direct" "$TARGET_PATH"
else
  mapfile -t CONFIG_LINES < <(load_pairs_from_config)
  if ((${#CONFIG_LINES[@]} == 0)); then
    echo "No sync groups found to execute." >&2
    exit 1
  fi
  current_group=""
  current_strategy=""
  current_source_label=""
  current_source_path=""
  current_source_kind=""
  for line in "${CONFIG_LINES[@]}"; do
    IFS='|' read -r kind group strategy source_label path kind_or target_exists rest <<<"$line"
    if [[ "$kind" == "GROUP" ]]; then
      current_group="$group"
      current_strategy="$strategy"
      current_source_label="$source_label"
      current_source_path="$path"
      current_source_kind="$kind_or"
      echo
      echo "=== Group: $group (strategy: ${strategy:-n/a}) ==="
    elif [[ "$kind" == "PAIR" ]]; then
      IFS='|' read -r _ group_name target_label target_path target_kind target_exists resolved_path resolved_kind note <<<"$line"
      if [[ -z "$current_group" ]]; then
        current_group="$group_name"
      fi
      local_origin="$target_path"
      run_sync_suite "$current_group" "$current_strategy" "$current_source_label" "$current_source_path" "$target_label" "$resolved_path" "$note" "$local_origin"
    fi
  done
fi

printf '\n=== Summary ===\n'
printf 'PASS: %d\n' "$PASS"
printf 'WARN: %d\n' "$WARN"
printf 'FAIL: %d\n' "$FAIL"

if [[ $FAIL -eq 0 ]]; then
  if [[ $WARN -eq 0 ]]; then
    printf '\n🎉 Sync smoke test completed without issues.\n'
  else
    printf '\n⚠️  Sync smoke test completed with warnings.\n'
  fi
  exit 0
else
  printf '\n💥 Sync smoke test detected failures.\n'
  exit 1
fi
