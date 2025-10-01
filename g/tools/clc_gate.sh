#!/usr/bin/env bash
set -euo pipefail

SCOPE="precommit"

for arg in "$@"; do
  case "$arg" in
    --scope=*)
      SCOPE="${arg#--scope=}"
      ;;
    *)
      echo "Usage: $(basename "$0") [--scope=<precommit|security|all>]" >&2
      exit 2
      ;;
  esac

done

echo "[clc_gate] scope=${SCOPE}"
echo "[clc_gate] Validation passed (stub)."
