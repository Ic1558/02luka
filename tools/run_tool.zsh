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
} >> "${log_file}"

exec "${tool_abs}" "$@"
