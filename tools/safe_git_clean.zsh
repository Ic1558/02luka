#!/usr/bin/env zsh
set -euo pipefail

# Safe Git Clean - Only removes ignored files (never untracked workspace)
# Usage: safe_git_clean.zsh [options]
# Options: -f (force), -d (directories), -X (only ignored), -n (dry-run)

REPO="${HOME}/02luka"

if [[ ! -d "$REPO/.git" ]]; then
  echo "ERROR: $REPO is not a git repo" >&2
  exit 1
fi

cd "$REPO"

# Run guard first (fail if workspace is broken)
echo "== Pre-clean guard check =="
if ! zsh tools/guard_workspace_inside_repo.zsh; then
  echo "ERROR: Workspace guard failed. Aborting clean to protect workspace data." >&2
  exit 1
fi

echo ""
echo "== Safe git clean (only ignored files) =="
echo "Using: git clean -fdX (removes only ignored files/dirs)"
echo ""

# Default to dry-run unless -f is provided
DRY_RUN=1
FORCE=0
DIRS=0
ONLY_IGNORED=1

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)
      FORCE=1
      DRY_RUN=0
      shift
      ;;
    -d|--dirs)
      DIRS=1
      shift
      ;;
    -X|--ignored-only)
      ONLY_IGNORED=1
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [-f] [-d] [-X] [-n]" >&2
      exit 1
      ;;
  esac
done

# Build git clean command
CLEAN_OPTS=""
[[ "$DIRS" -eq 1 ]] && CLEAN_OPTS="${CLEAN_OPTS}d"
[[ "$ONLY_IGNORED" -eq 1 ]] && CLEAN_OPTS="${CLEAN_OPTS}X"
[[ "$DRY_RUN" -eq 1 ]] && CLEAN_OPTS="${CLEAN_OPTS}n"
[[ "$FORCE" -eq 1 ]] && CLEAN_OPTS="${CLEAN_OPTS}f"

if [[ -z "$CLEAN_OPTS" ]]; then
  CLEAN_OPTS="n"  # Default to dry-run
fi

echo "Command: git clean -${CLEAN_OPTS}"
echo ""

# Execute git clean
git clean -${CLEAN_OPTS}

echo ""
echo "✅ Safe clean complete"
echo ""
echo "Note: This only removes files matching .gitignore patterns."
echo "      Workspace data in ~/02luka_ws/ is never touched."
