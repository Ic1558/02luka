#!/usr/bin/env zsh
#
# Script: [SCRIPT_NAME].zsh
# Purpose: [Brief description of what this script does]
# Usage: [SCRIPT_NAME].zsh [args]
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════
# Load Central Configuration
# ═══════════════════════════════════════════════════════════

# Get script directory (works in both bash and zsh)
if [[ -n "${ZSH_VERSION}" ]]; then
  SCRIPT_DIR="${0:A:h}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Source path configuration
if [[ -f "${SCRIPT_DIR}/../lib/path_config.zsh" ]]; then
  source "${SCRIPT_DIR}/../lib/path_config.zsh"
else
  echo "❌ ERROR: Cannot find path_config.zsh" >&2
  echo "   Expected: ${SCRIPT_DIR}/../lib/path_config.zsh" >&2
  exit 1
fi

# ═══════════════════════════════════════════════════════════
# Script Configuration
# ═══════════════════════════════════════════════════════════

SCRIPT_NAME="$(basename "$0")"
LOG_FILE="${SOT_LOGS}/${SCRIPT_NAME%.zsh}.log"

# ═══════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

error() {
  echo "❌ ERROR: $*" >&2
  log "ERROR: $*"
  exit 1
}

# ═══════════════════════════════════════════════════════════
# Validation
# ═══════════════════════════════════════════════════════════

# Validate SOT path
validate_sot_path "${SOT}" || error "Invalid SOT path"

# Validate required directories exist
[[ -d "${SOT}" ]] || error "SOT directory not found: ${SOT}"

# ═══════════════════════════════════════════════════════════
# Main Logic
# ═══════════════════════════════════════════════════════════

main() {
  log "Starting ${SCRIPT_NAME}"

  # Your script logic here
  echo "Working in: ${SOT}"
  echo "Reports will be saved to: ${SOT_REPORTS}"

  # Example: Create a report
  # local report_file="${SOT_REPORTS}/my_report_$(date +%Y%m%d).md"
  # cat << 'EOF' > "${report_file}"
  # # My Report
  # Content here
  # EOF

  log "Completed ${SCRIPT_NAME}"
}

# ═══════════════════════════════════════════════════════════
# Entry Point
# ═══════════════════════════════════════════════════════════

main "$@"
