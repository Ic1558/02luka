#!/usr/bin/env zsh
set -euo pipefail

# Ensure a sane PATH even in constrained shells (Cursor/launchd/etc.)
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

REPO="${HOME}/02luka"
WS="${HOME}/02luka_ws"
LOCAL="${HOME}/02luka_local"

# --- sanity
if [[ ! -d "$REPO/.git" ]]; then
  echo "ERROR: $REPO is not a git repo (missing .git)" >&2
  exit 1
fi

/bin/mkdir -p "$WS" "$LOCAL"

# --- workspace dirs (never in git)
/bin/mkdir -p \
  "$WS/g/data" \
  "$WS/g/telemetry" \
  "$WS/g/followup" \
  "$WS/mls/ledger" \
  "$WS/bridge/processed"

# --- local dirs (never in git)
/bin/mkdir -p \
  "$LOCAL/.claude" \
  "$LOCAL/.cursor" \
  "$LOCAL/.vscode" \
  "$LOCAL/Library/LaunchAgents"

# Helper: migrate existing directory to workspace
migrate_to_workspace() {
  local source="$1"
  local target="$2"
  
  # If source doesn't exist or is already symlink, skip
  if [[ ! -e "$source" ]] || [[ -L "$source" ]]; then
    return 0
  fi
  
  # If target already has content, merge (rsync)
  if [[ -d "$target" ]] && [[ "$(ls -A "$target" 2>/dev/null)" ]]; then
    echo "WARN: Target $target already has content. Merging from $source..."
    rsync -av "$source/" "$target/" || {
      echo "ERROR: Failed to merge $source -> $target" >&2
      exit 1
    }
  else
    # Target is empty or doesn't exist, move everything
    echo "MIGRATE: Moving $source -> $target"
    /bin/mkdir -p "$(/usr/bin/dirname "$target")"
    /bin/mv "$source" "$target" || {
      echo "ERROR: Failed to move $source -> $target" >&2
      exit 1
    }
  fi
}

# Helper: create symlink safely
link_to() {
  local target="$1"
  local linkpath="$2"

  # If link exists and is correct symlink -> ok
  if [[ -L "$linkpath" ]]; then
    local cur
    cur="$(readlink "$linkpath")"
    if [[ "$cur" == "$target" ]]; then
      echo "OK  symlink: $linkpath -> $target"
      return 0
    fi
    echo "WARN symlink differs: $linkpath -> $cur (expected $target). Replacing."
    /bin/rm -f "$linkpath"
  fi

  # If path exists as real dir/file -> migrate first, then create symlink
  if [[ -e "$linkpath" ]] && [[ ! -L "$linkpath" ]]; then
    echo "MIGRATE: Found real directory at $linkpath, migrating to workspace..."
    migrate_to_workspace "$linkpath" "$target"
    /bin/rm -rf "$linkpath"
  fi

  /bin/ln -s "$target" "$linkpath"
  echo "NEW symlink: $linkpath -> $target"
}

echo "== Linking workspace paths into repo =="
link_to "$WS/g/data"          "$REPO/g/data"
link_to "$WS/g/telemetry"     "$REPO/g/telemetry"
link_to "$WS/g/followup"      "$REPO/g/followup"
link_to "$WS/mls/ledger"      "$REPO/mls/ledger"
link_to "$WS/bridge/processed" "$REPO/bridge/processed"

echo "== Optional: link local tool/config dirs into repo =="
# Uncomment if you want these to live outside repo:
# link_to "$LOCAL/.claude" "$REPO/.claude"
# link_to "$LOCAL/.cursor" "$REPO/.cursor"
# link_to "$LOCAL/.vscode" "$REPO/.vscode"
# link_to "$LOCAL/.env.local" "$REPO/.env.local"

echo "== Guard: verify tracked paths are symlinks (if tracked) =="
cd "$REPO"
bad_tracked=0
for p in \
  "g/data" \
  "g/telemetry" \
  "g/followup" \
  "mls/ledger" \
  "bridge/processed"
do
  if git ls-files --error-unmatch "$p" >/dev/null 2>&1; then
    # Path is tracked - verify it's a symlink
    if [[ -L "$REPO/$p" ]]; then
      echo "OK  tracked symlink: $p (allowed)"
    else
      echo "ERROR: git is tracking '$p' but it's a real dir/file (must be symlink)." >&2
      echo "FIX: Remove from git, then re-run bootstrap:" >&2
      echo "     git rm -r --cached $p  (then commit)" >&2
      echo "     zsh tools/bootstrap_workspace.zsh" >&2
      bad_tracked=1
    fi
  else
    # Not tracked - that's fine
    echo "OK  not tracked: $p"
  fi
done
if [[ "$bad_tracked" -ne 0 ]]; then
  exit 1
fi

echo "== Guard: verify linked paths are symlinks =="
must_be_symlink=0
for p in \
  "$REPO/g/data" \
  "$REPO/g/telemetry" \
  "$REPO/g/followup" \
  "$REPO/mls/ledger" \
  "$REPO/bridge/processed"
do
  if [[ ! -L "$p" ]]; then
    echo "ERROR: expected symlink but got real path: $p" >&2
    must_be_symlink=1
  fi
done
if [[ "$must_be_symlink" -ne 0 ]]; then
  exit 1
fi

echo ""
echo "✅ Workspace split bootstrap complete."
echo "Repo : $REPO"
echo "WS   : $WS"
echo "LOCAL: $LOCAL"
echo ""
echo "Safety note:"
echo "- You may git reset/clean inside repo; workspace data stays safe outside."
