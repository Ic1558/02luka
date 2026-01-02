#!/usr/bin/env zsh
set -euo pipefail

PLIST="/Users/icmini/02luka/infra/launchd/com.antigravity.bridge.plist"
LABEL="com.antigravity.bridge"
DOMAIN="gui/$(id -u)"

launchctl bootout "${DOMAIN}/${LABEL}" 2>/dev/null || true
launchctl bootstrap "${DOMAIN}" "${PLIST}"
launchctl print "${DOMAIN}/${LABEL}" | head -n 20
