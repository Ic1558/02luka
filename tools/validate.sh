#!/usr/bin/env bash
#
# Global Validation Runner
# Simple wrapper around existing validation with optional enhancements
#
# Usage:
#   validate.sh              # Run standard validation
#   validate.sh --json       # Output JSON for CI
#   validate.sh --metrics    # Save metrics
#   validate.sh --quiet      # Minimal output
#
# Design: Keep it simple. Enhance the existing smoke.sh, don't replace it.

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Options
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

JSON_OUTPUT=false
SAVE_METRICS=false
QUIET=false

while (( $# )); do
  case "$1" in
    --json) JSON_OUTPUT=true ;;
    --metrics) SAVE_METRICS=true ;;
    --quiet) QUIET=true ;;
    --help|-h)
      grep '^#' "$0" | grep -v '#!/' | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Run Validation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

START_TIME=$(date +%s)

# Respect CI environment
[[ "${CI_QUIET:-}" == "1" ]] && QUIET=true
[[ "${SKIP_BOSS_API:-}" == "1" ]] && export SKIP_BOSS=1

# Run the existing, working smoke tests
if [[ "$QUIET" == "true" ]]; then
  OUTPUT=$(bash scripts/smoke.sh 2>&1)
  EXIT_CODE=$?
else
  bash scripts/smoke.sh
  EXIT_CODE=$?
  OUTPUT=""
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Optional Outputs
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# JSON output for CI consumption
if [[ "$JSON_OUTPUT" == "true" ]]; then
  cat <<EOF
{
  "passed": $([ $EXIT_CODE -eq 0 ] && echo "true" || echo "false"),
  "duration_seconds": $DURATION,
  "timestamp": "$(date -Iseconds)",
  "exit_code": $EXIT_CODE
}
EOF
fi

# Metrics for tracking
if [[ "$SAVE_METRICS" == "true" ]]; then
  METRICS_FILE="/tmp/validation-metrics.json"
  cat > "$METRICS_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "duration_seconds": $DURATION,
  "passed": $([ $EXIT_CODE -eq 0 ] && echo "true" || echo "false"),
  "exit_code": $EXIT_CODE
}
EOF
  [[ "$QUIET" != "true" ]] && echo "Metrics saved to: $METRICS_FILE"
fi

exit $EXIT_CODE
