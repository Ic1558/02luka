#!/usr/bin/env zsh
# install_clc_cli.zsh — One-time installer for CLC local controller
# Sets up symlinks, LaunchAgent, and required directories
set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="${0:A:h}"  # Directory of this script
REPO_ROOT="${SCRIPT_DIR}/../.."
CLC_SCRIPT="${REPO_ROOT}/tools/cli/clc.zsh"
PLIST_SOURCE="${REPO_ROOT}/LaunchAgents/com.02luka.clc.local.plist"

SYMLINK_TARGET="$HOME/bin/clc.zsh"
PLIST_INSTALL="$HOME/Library/LaunchAgents/com.02luka.clc.local.plist"
LOGS_DIR="$HOME/02luka/logs"

# --- Helpers ---
ok(){ print "[OK]  $*"; }
info(){ print "[..] $*"; }
err(){ print -u2 "[ERR] $*"; }
die(){ err "$*"; exit 1; }

banner(){ print "\n==== $1 ====\n"; }

# --- Pre-checks ---
banner "Pre-flight Checks"

[[ -f "$CLC_SCRIPT" ]] || die "clc.zsh not found at: $CLC_SCRIPT"
[[ -f "$PLIST_SOURCE" ]] || die "LaunchAgent plist not found at: $PLIST_SOURCE"

ok "Found clc.zsh: $CLC_SCRIPT"
ok "Found plist: $PLIST_SOURCE"

# --- Step 1: Create directories ---
banner "Creating Directories"

mkdir -p "$HOME/bin"
ok "Created ~/bin/"

mkdir -p "$LOGS_DIR"
ok "Created $LOGS_DIR/"

# --- Step 2: Create symlink ---
banner "Creating Symlink"

if [[ -L "$SYMLINK_TARGET" ]]; then
  existing=$(readlink "$SYMLINK_TARGET")
  if [[ "$existing" == "$CLC_SCRIPT" ]]; then
    ok "Symlink already correct: $SYMLINK_TARGET → $CLC_SCRIPT"
  else
    info "Removing old symlink: $SYMLINK_TARGET → $existing"
    rm "$SYMLINK_TARGET"
    ln -s "$CLC_SCRIPT" "$SYMLINK_TARGET"
    ok "Updated symlink: $SYMLINK_TARGET → $CLC_SCRIPT"
  fi
elif [[ -e "$SYMLINK_TARGET" ]]; then
  err "$SYMLINK_TARGET exists but is not a symlink - please remove it manually"
  exit 1
else
  ln -s "$CLC_SCRIPT" "$SYMLINK_TARGET"
  ok "Created symlink: $SYMLINK_TARGET → $CLC_SCRIPT"
fi

# --- Step 3: Install LaunchAgent ---
banner "Installing LaunchAgent"

# Unload existing if loaded
if launchctl list | grep -q com.02luka.clc.local 2>/dev/null; then
  info "Unloading existing LaunchAgent"
  launchctl unload "$PLIST_INSTALL" 2>/dev/null || true
fi

# Copy plist
cp "$PLIST_SOURCE" "$PLIST_INSTALL"
ok "Installed: $PLIST_INSTALL"

# Load LaunchAgent
launchctl load "$PLIST_INSTALL"
ok "Loaded LaunchAgent: com.02luka.clc.local"

# --- Step 4: Verify setup ---
banner "Verification"

if [[ -x "$SYMLINK_TARGET" ]]; then
  ok "Symlink is executable: $SYMLINK_TARGET"
else
  err "Symlink not executable - check permissions"
fi

if launchctl list | grep -q com.02luka.clc.local; then
  ok "LaunchAgent is loaded"
else
  err "LaunchAgent failed to load - check logs"
fi

# Test the CLI
if "$SYMLINK_TARGET" status >/dev/null 2>&1; then
  ok "clc.zsh status command works"
else
  info "clc.zsh status returned non-zero (may be expected if tmux session doesn't exist yet)"
fi

# --- Step 5: Final instructions ---
banner "Installation Complete!"

cat <<'FINAL'
✅ CLC Local Controller installed successfully!

Quick Start:
  clc status           # Check status
  clc start            # Start CLC with Happy Coder
  clc attach           # Attach to tmux session (Ctrl-B D to detach)
  clc logs             # Watch logs in real-time
  clc stop             # Stop CLC
  clc restart          # Restart CLC

PATH Setup (optional):
  If ~/bin is not in your PATH, add this to ~/.zshrc:
    export PATH="$HOME/bin:$PATH"

  Or create an alias:
    alias clc="~/bin/clc.zsh"

LaunchAgent:
  Auto-starts on login (already loaded)
  To disable: launchctl unload ~/Library/LaunchAgents/com.02luka.clc.local.plist
  To enable:  launchctl load ~/Library/LaunchAgents/com.02luka.clc.local.plist

Logs:
  CLC output: ~/02luka/logs/clc_local.log
  LaunchAgent stdout: ~/02luka/logs/clc_local.out
  LaunchAgent stderr: ~/02luka/logs/clc_local.err

Mobile Control:
  Via Tailscale + SSH:
    ssh your-mac "~/bin/clc.zsh status"
    ssh your-mac "~/bin/clc.zsh restart"

For more info: cat tools/cli/README.md
FINAL

print "\n"
