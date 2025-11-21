#!/usr/bin/env zsh
#
# Central path configuration for 02luka system
# Source this file in all scripts to get standardized paths
#
# Usage:
#   source "${0:A:h}/../lib/path_config.zsh"
#   echo "Working in: ${SOT}"
#

# ═══════════════════════════════════════════════════════════
# Primary Paths
# ═══════════════════════════════════════════════════════════

export SOT="${HOME}/02luka"
export SOT_CORE="${SOT}/g"

# ═══════════════════════════════════════════════════════════
# Runtime Paths
# ═══════════════════════════════════════════════════════════

export SOT_AGENTS="${SOT}/agents"
export SOT_BRIDGE="${SOT}/bridge"
export SOT_TOOLS="${SOT}/tools"

# ═══════════════════════════════════════════════════════════
# Data Paths
# ═══════════════════════════════════════════════════════════

export SOT_MEMORY="${SOT}/memory"
export SOT_TELEMETRY="${SOT}/telemetry"
export SOT_LOGS="${SOT_CORE}/data/logs"

# Knowledge & Learning
export SOT_KNOWLEDGE="${SOT_CORE}/knowledge"
export SOT_MLS="${SOT_KNOWLEDGE}/mls_lessons.jsonl"

# ═══════════════════════════════════════════════════════════
# Documentation Paths
# ═══════════════════════════════════════════════════════════

export SOT_DOCS="${SOT_CORE}/docs"
export SOT_REPORTS="${SOT_DOCS}/reports"
export SOT_MANUALS="${SOT_DOCS}/manuals"
export SOT_GUIDES="${SOT_DOCS}/guides"

# ═══════════════════════════════════════════════════════════
# Configuration Paths
# ═══════════════════════════════════════════════════════════

export SOT_CONFIG="${SOT_CORE}/config"
export SOT_SCHEMAS="${SOT_CONFIG}/schemas"
export SOT_TEMPLATES="${SOT_CONFIG}/templates"

# ═══════════════════════════════════════════════════════════
# Archive Paths
# ═══════════════════════════════════════════════════════════

export SOT_ARCHIVE="${SOT}/_archive"
export SOT_CORE_ARCHIVE="${SOT_CORE}/.archive"

# ═══════════════════════════════════════════════════════════
# Work Order Paths
# ═══════════════════════════════════════════════════════════

export SOT_BRIDGE_INBOX="${SOT_BRIDGE}/inbox"
export SOT_BRIDGE_OUTBOX="${SOT_BRIDGE}/outbox"
export SOT_BRIDGE_GEMINI_INBOX="${SOT_BRIDGE_INBOX}/GEMINI"
export SOT_BRIDGE_GEMINI_OUTBOX="${SOT_BRIDGE_OUTBOX}/GEMINI"

# ═══════════════════════════════════════════════════════════
# Validation Functions
# ═══════════════════════════════════════════════════════════

# Validate a path for common anti-patterns
validate_sot_path() {
  local path="$1"
  local errors=0

  # Check for nested /g/g
  if [[ "$path" =~ "/g/g" ]]; then
    echo "❌ ERROR: Nested /g/g detected in path: $path" >&2
    echo "   This creates recursive directory structures" >&2
    ((errors++))
  fi

  # Check for literal tilde
  if [[ "$path" =~ "~/" ]] || [[ "$path" == "~"* ]]; then
    echo "❌ ERROR: Literal tilde (~) in path: $path" >&2
    echo "   Use \$HOME or \$SOT instead" >&2
    echo "   Example: \${SOT}/g/reports" >&2
    ((errors++))
  fi

  # Check for hardcoded user (but allow if it matches current user's $HOME)
  if [[ "$path" =~ "/Users/[^/]+/" ]] && [[ "$path" != "${HOME}"* ]]; then
    echo "❌ ERROR: Hardcoded user path detected: $path" >&2
    echo "   Use \$HOME or \$SOT instead" >&2
    ((errors++))
  fi

  # Check for double slashes
  if [[ "$path" =~ "//" ]]; then
    echo "⚠️  WARNING: Double slash (//) in path: $path" >&2
    echo "   This may indicate a path construction error" >&2
  fi

  # Check for multiple /g/ occurrences (using zsh/bash string manipulation)
  local temp_path="${path//[^\/]/}"  # Keep only slashes
  local g_search="${path}"
  local g_count=0
  while [[ "$g_search" == */g/* ]]; do
    ((g_count++))
    g_search="${g_search#*/g/}"
  done

  if [[ $g_count -gt 1 ]]; then
    echo "⚠️  WARNING: Multiple /g/ in path: $path" >&2
    echo "   Found $g_count occurrences - verify this is intentional" >&2
  fi

  return $errors
}

# Create a timestamped archive directory
create_archive() {
  local operation_name="${1:-migration}"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local archive_dir="${SOT_ARCHIVE}/${operation_name}_${timestamp}"

  mkdir -p "${archive_dir}/metadata"
  echo "${archive_dir}"
}

# Log migration metadata
log_migration() {
  local archive_dir="$1"
  local source="$2"
  local destination="$3"

  {
    echo "Operation: Migration"
    echo "Date: $(date)"
    echo "User: ${USER}"
    echo "Source: ${source}"
    echo "Destination: ${destination}"
    echo ""
    echo "=== Source Details ==="
    du -sh "${source}" 2>/dev/null || echo "N/A"
    find "${source}" -type f 2>/dev/null | wc -l | xargs echo "Files:"
    find "${source}" -type d 2>/dev/null | wc -l | xargs echo "Directories:"
  } > "${archive_dir}/metadata/migration_log.txt"
}

# Export functions for use in other scripts
if [[ -n "${ZSH_VERSION}" ]]; then
  # zsh
  export -f validate_sot_path create_archive log_migration 2>/dev/null || true
else
  # bash
  export -f validate_sot_path create_archive log_migration
fi

# ═══════════════════════════════════════════════════════════
# Verification (Optional)
# ═══════════════════════════════════════════════════════════

# Verify SOT exists
if [[ ! -d "${SOT}" ]]; then
  echo "⚠️  WARNING: SOT directory does not exist: ${SOT}" >&2
  echo "   Some paths may not be accessible" >&2
fi

# Mark configuration as loaded
export SOT_PATH_CONFIG_LOADED=1
