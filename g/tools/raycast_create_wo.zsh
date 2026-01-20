#!/bin/zsh
# @raycast.schemaVersion 1
# @raycast.title Drop WO to LAC
# @raycast.mode compact
# @raycast.packageName 02luka
# @raycast.icon 🤖
# @raycast.description Creates a JSON WO in bridge/inbox/lac from Clipboard

set -euo pipefail

# 1. Read Clipboard
CONTENT=$(pbpaste)
if [[ -z "$CONTENT" ]]; then
  echo "⚠️ Clipboard is empty"
  exit 1
fi

# 2. Setup Variables
ROOT_DIR="${LUKA_ROOT:-$HOME/02luka}"
INBOX_DIR="${ROOT_DIR}/bridge/inbox/lac"
mkdir -p "$INBOX_DIR"

TS=$(date +%s)
WO_ID="WO-RAYCAST-${TS}"
FILENAME="WO-${TS}.json"
FILEPATH="${INBOX_DIR}/${FILENAME}"

# 3. Create JSON Payload securely with Python
/usr/bin/env python3 -c "
import json
import os
import sys

# Get content from environment variable to avoid shell escaping issues
content = os.environ.get('CONTENT', '')

payload = {
    'wo_id': '${WO_ID}',
    'objective': content,
    'lane': 'dev',
    'source': 'RAYCAST',
    'dry_run': True,
    'complexity': 'simple'
}

with open('${FILEPATH}', 'w') as f:
    json.dump(payload, f, indent=2)
"

# 4. Output for Raycast
echo "🚀 Dropped ${WO_ID}"
