#!/usr/bin/env zsh
# Remove Synology NAS from Time Machine destinations
# (Requires admin privileges — run from an elevated shell)

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Please rerun from an administrator shell (root privileges required)."
  exit 1
fi

echo "=== Remove Synology from Time Machine ==="
echo ""
echo "Current Time Machine destinations:"
tmutil destinationinfo
echo ""
echo "This will remove the Synology NAS (7A316888-DD45-43F3-96B6-037FA2BD84FA)"
echo "You'll still have:"
echo "  ✅ Local Time Machine (Backups of Mac mini 2)"
echo "  ✅ Daily rsync backups to lukadata"
echo ""
read "confirm?Continue? (y/n): "

if [[ "$confirm" != "y" ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "Removing Synology destination (interactive)..."
tmutil removedestination 7A316888-DD45-43F3-96B6-037FA2BD84FA

echo ""
echo "✅ Done! Remaining destinations:"
tmutil destinationinfo
