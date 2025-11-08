#!/usr/bin/env bash
#
# CI Validation Script
# Simple wrapper for CI environments
#
# Runs the standard validation with CI-friendly options

set -euo pipefail

# Use the simple, reliable validation wrapper
exec "$(dirname "$0")/../validate.sh" "$@"
