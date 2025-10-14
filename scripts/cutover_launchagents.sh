#!/usr/bin/env bash
set -euo pipefail

# Source universal path resolver
source "$(dirname "$0")/repo_root_resolver.sh"

# Derive PARENT from REPO_ROOT (removes /02luka-repo suffix)
# Example: .../My Drive/02luka/02luka-repo → .../My Drive/02luka
PARENT="${REPO_ROOT%/02luka-repo}"
REPO="$REPO_ROOT"
LOGDIR="$HOME/Library/Logs/02luka"
TS="$(date +%y%m%d_%H%M%S)"

# Accept labels as arguments, fallback to default 5
labels=("$@")
: "${labels:=com.02luka.localworker.bg com.02luka.gci.topic.reports com.02luka.mcp.server.fs_local com.02luka.disk_monitor com.docker.autohealing}"
labels=($labels)

mkdir -p "$LOGDIR"

fix_plist() {
  local label="$1"
  local p="$HOME/Library/LaunchAgents/${label}.plist"
  [ -f "$p" ] || { echo "↷ skip (no plist): $label"; return 0; }

  # backup + normalize xml
  cp -p "$p" "${p}.__bak_${TS}"
  # Fix XML escaping issues (&&, ||, etc.) before plutil
  sed -i.sedtmp 's/ && / \&amp;\&amp; /g; s/ || / \&amp;\&amp; /g' "$p" && rm -f "${p}.sedtmp"
  /usr/bin/plutil -convert xml1 "$p" 2>/dev/null || true

  # replace any occurrence of parent path → repo path (safe for Program/ProgramArguments/Env)
  # Handle multiple path variations
  PARENT_PATH="$PARENT" REPO_PATH="$REPO" /usr/bin/perl -0777 -pe '
    s/\Q$ENV{PARENT_PATH}\E/$ENV{REPO_PATH}/g;
    s|\$HOME/My Drive/02luka(?!/02luka-repo)|\$HOME/Library/CloudStorage/GoogleDrive-ittipong.c\@gmail.com/My Drive/02luka/02luka-repo|g;
    s|/Users/icmini/My Drive/02luka(?!/02luka-repo)|/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c\@gmail.com/My Drive/02luka/02luka-repo|g;
  ' -i "$p"

  # ensure logs to local (safe for Stream Mode)
  /usr/libexec/PlistBuddy -c "Set :StandardOutPath $LOGDIR/${label}.out"  "$p" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :StandardOutPath string $LOGDIR/${label}.out" "$p"
  /usr/libexec/PlistBuddy -c "Set :StandardErrorPath $LOGDIR/${label}.err" "$p" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :StandardErrorPath string $LOGDIR/${label}.err" "$p"

  # basic sanity
  /usr/bin/plutil -lint "$p" >/dev/null

  # reload agent (best-effort)
  launchctl bootout gui/$UID "$p" 2>/dev/null || true
  launchctl bootstrap gui/$UID "$p"
  launchctl kickstart -k gui/$UID/"$label" || true

  echo "✅ cutover: $label  (backup: ${p}.__bak_${TS})"
}

echo "== Cutover parent → repo =="
echo "PARENT: $PARENT"
echo "REPO:   $REPO"
for lb in "${labels[@]}"; do fix_plist "$lb"; done

echo "== Post-check =="
# re-scan any leftover references in LaunchAgents
SCAN="$PWD/g/reports/proof/${TS}_post_cutover_launchagents_refs.txt"
mkdir -p "$(dirname "$SCAN")"
grep -RInE "/My Drive/02luka/(boss|g|docs)" "$HOME/Library/LaunchAgents" > "$SCAN" 2>/dev/null || true
echo "Refs file: ${SCAN##$PWD/}"

echo "Done."
