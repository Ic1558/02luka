#!/usr/bin/env zsh
set -euo pipefail

# --- locate repo root ---
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "ERROR: not inside a git repo. cd into the repo and re-run."
  exit 1
fi
cd "${REPO_ROOT}"

mkdir -p tools tools/_tmp

# --- (A) tools/catalog_lookup.zsh ---
cat > tools/catalog_lookup.zsh <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

# Usage:
#   zsh tools/catalog_lookup.zsh <alias> [--catalog <path>]
#
# Output:
#   prints the script path from tools/CATALOG.md that matches the alias.

alias_name="${1:-}"
shift || true

catalog_path="tools/CATALOG.md"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --catalog)
      catalog_path="${2:-}"
      shift 2
      ;;
    *)
      echo "ERROR: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${alias_name}" ]]; then
  echo "ERROR: alias required" >&2
  exit 2
fi

if [[ ! -f "${catalog_path}" ]]; then
  echo "ERROR: catalog not found: ${catalog_path}" >&2
  exit 2
fi

# Parse markdown tables:
# - Find rows like: | alias | ... | tools/something.zsh |
# - Accept the first cell as alias, and the first cell that looks like tools/* as script path.
# - Skip header separator lines.
found_path="$(
  awk -v want="${alias_name}" '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    BEGIN{ IGNORECASE=1 }
    /^\|/ {
      line=$0
      # skip separator rows like | --- | --- |
      if (line ~ /^\|[[:space:]]*[-:]+[[:space:]]*\|/) next

      # split by |
      n=split(line, a, "|")
      # a[1] is empty (before first |)
      # a[2] is first cell
      alias=trim(a[2])
      if (tolower(alias) != tolower(want)) next

      # find a cell that looks like a path under tools/
      for (i=3; i<=n; i++) {
        cell=trim(a[i])
        if (cell ~ /^tools\/[A-Za-z0-9._\/-]+$/) { print cell; exit 0 }
      }

      # fallback: maybe second cell is the path
      for (i=2; i<=n; i++) {
        cell=trim(a[i])
        if (cell ~ /^tools\/[A-Za-z0-9._\/-]+$/) { print cell; exit 0 }
      }
    }
  ' "${catalog_path}"
)"

if [[ -z "${found_path}" ]]; then
  echo "ERROR: alias not found in catalog: ${alias_name}" >&2
  exit 3
fi

print -r -- "${found_path}"
EOF
chmod +x tools/catalog_lookup.zsh

# --- (B) tools/run_tool.zsh ---
cat > tools/run_tool.zsh <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

# Single mandatory entry point
# Usage: zsh tools/run_tool.zsh <alias> [args...]

alias_name="${1:-}"
shift || true

if [[ -z "${alias_name}" ]]; then
  echo "Usage: zsh tools/run_tool.zsh <alias> [args...]" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
export REPO_ROOT
export AGENT_ID="gmx"
export RUN_TOOL_DISPATCH=1

catalog="tools/CATALOG.md"
lookup="tools/catalog_lookup.zsh"
if [[ ! -x "${lookup}" ]]; then
  echo "ERROR: missing lookup tool: ${lookup}" >&2
  exit 2
fi
if [[ ! -f "${catalog}" ]]; then
  echo "ERROR: missing catalog: ${catalog}" >&2
  exit 2
fi

tool_rel="$(zsh "${lookup}" "${alias_name}" --catalog "${catalog}")"
tool_abs="${REPO_ROOT}/${tool_rel}"

if [[ ! -f "${tool_abs}" ]]; then
  echo "ERROR: tool path resolved but file missing: ${tool_rel}" >&2
  exit 2
fi
if [[ ! -x "${tool_abs}" ]]; then
  echo "ERROR: tool exists but not executable: ${tool_rel}" >&2
  echo "Hint: chmod +x ${tool_rel}" >&2
  exit 2
fi

log_dir="${REPO_ROOT}/logs/tool_runs"
mkdir -p "${log_dir}"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="${log_dir}/${ts}__${AGENT_ID}__${alias_name}.log"

{
  echo "utc_ts=${ts}"
  echo "agent_id=${AGENT_ID}"
  echo "repo_root=${REPO_ROOT}"
  echo "alias=${alias_name}"
  echo "tool=${tool_rel}"
  echo "args=$*"
} > "${log_file}"

exec "${tool_abs}" "$@"
EOF
chmod +x tools/run_tool.zsh

# --- (C) Promote truth sync script to canonical tools/sync_truth.zsh ---
if [[ -f "tools/_tmp/wo_fix_02luka_truth_sync.zsh" ]]; then
  cp -f "tools/_tmp/wo_fix_02luka_truth_sync.zsh" "tools/sync_truth.zsh"
  chmod +x "tools/sync_truth.zsh"
else
  # Fail-closed stub: save should NOT silently skip truth sync.
  cat > tools/sync_truth.zsh <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail
echo "ERROR: tools/sync_truth.zsh is a stub because tools/_tmp/wo_fix_02luka_truth_sync.zsh was not found." >&2
echo "Fix: place the real truth sync implementation at tools/sync_truth.zsh (executable) and re-run save." >&2
exit 2
EOF
  chmod +x tools/sync_truth.zsh
fi

# --- (D) Patch tools/save.sh to run sync_truth.zsh ---
if [[ -f "tools/save.sh" ]]; then
  # Make a backup once (idempotent-ish)
  if [[ ! -f "tools/save.sh.phase11.bak" ]]; then
    cp -f "tools/save.sh" "tools/save.sh.phase11.bak"
  fi

  # Insert a Truth Sync call after initial strict mode / before main backend execution.
  # We do a conservative append if no marker is found.
  if ! grep -q "sync_truth.zsh" "tools/save.sh"; then
    tmp="$(mktemp)"
    awk '
      BEGIN{inserted=0}
      {
        print $0
        if (!inserted && ($0 ~ /^set -e/ || $0 ~ /^set -euo/ || $0 ~ /^set -eu/)) {
          print ""
          print "# Phase 11: SSOT Truth Sync (default ON). Use --no-truth-sync to bypass."
          print "NO_TRUTH_SYNC=0"
          print "for arg in \"$@\"; do"
          print "  [[ \"$arg\" == \"--no-truth-sync\" ]] && NO_TRUTH_SYNC=1"
          print "done"
          print "if [[ \"$NO_TRUTH_SYNC\" -eq 0 ]]; then"
          print "  RR=\"${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}\""
          print "  if [[ -x \"$RR/tools/sync_truth.zsh\" ]]; then"
          print "    zsh \"$RR/tools/sync_truth.zsh\""
          print "  else"
          print "    echo \"ERROR: tools/sync_truth.zsh missing or not executable\" >&2"
          print "    exit 2"
          print "  fi"
          print "fi"
          inserted=1
        }
      }
      END{
        if (!inserted) {
          print ""
          print "# Phase 11: SSOT Truth Sync (fallback insert)."
          print "if [[ -x \"tools/sync_truth.zsh\" ]]; then zsh tools/sync_truth.zsh; else echo \"ERROR: tools/sync_truth.zsh missing\" >&2; exit 2; fi"
        }
      }
    ' tools/save.sh > "${tmp}"
    mv -f "${tmp}" tools/save.sh
    chmod +x tools/save.sh
  fi
else
  echo "WARN: tools/save.sh not found; skipped patch."
fi

# --- (E) Ensure tools/CATALOG.md has entries for run_tool and sync_truth (append if missing) ---
if [[ -f "tools/CATALOG.md" ]]; then
  if ! grep -qE '^\|\s*run-tool\s*\|' tools/CATALOG.md; then
    cat >> tools/CATALOG.md <<'EOF'

| run-tool | Single entry dispatcher (mandatory) | tools/run_tool.zsh |
EOF
  fi
  if ! grep -qE '^\|\s*sync-truth\s*\|' tools/CATALOG.md; then
    cat >> tools/CATALOG.md <<'EOF'
| sync-truth | Refresh SSOT truth + context stubs | tools/sync_truth.zsh |
EOF
  fi
  if ! grep -qE '^\|\s*save\s*\|' tools/CATALOG.md; then
    # only append if missing; do NOT guess path
    echo "NOTE: alias 'save' not found in tools/CATALOG.md — add it to enforce lookup." >&2
  fi
else
  echo "WARN: tools/CATALOG.md not found; cannot enforce catalog lookup yet."
fi

# --- (F) Append Phase 11 note to task.md if present ---
if [[ -f "task.md" ]]; then
  if ! grep -q "Phase 11" task.md; then
    cat >> task.md <<'EOF'

## Phase 11 — Workflow Enforcement
- Mandatory entrypoint: `tools/run_tool.zsh`
- Catalog-based lookup (no guessing): `tools/catalog_lookup.zsh` reads `tools/CATALOG.md`
- Standard identity: `AGENT_ID=gmx`
- Logging: `logs/tool_runs/*.log`
- SSOT Truth Sync integrated into save: `tools/save.sh` calls `tools/sync_truth.zsh` by default (opt-out: `--no-truth-sync`)
EOF
  fi
fi

echo "OK: Phase 11 applied."
echo "Next: verify with:"
echo "  zsh tools/run_tool.zsh sync-truth"
echo "  zsh tools/run_tool.zsh save --dry-run"