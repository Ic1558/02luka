#!/usr/bin/env zsh
# LAC background runner - triggers maintenance tasks via scheduler entrypoint.

set -e

SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:A}/../..

cd "$REPO_ROOT"

export LAC_BASE_DIR=${LAC_BASE_DIR:-$REPO_ROOT}

python g/maintenance/scheduler_entrypoint.py
