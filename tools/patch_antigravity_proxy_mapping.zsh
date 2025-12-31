#!/usr/bin/env zsh
set -euo pipefail

TARGET_FILE="/opt/homebrew/lib/node_modules/antigravity-claude-proxy/src/server.js"
NEEDLE="claude-haiku-4-5-20251001"
REPLACE="gemini-1.5-flash"

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "ERROR: not found: $TARGET_FILE"
  echo "Is antigravity-claude-proxy installed globally?"
  exit 1
fi

echo "Patching: $TARGET_FILE"

# Pre-check if already patched
if grep -F "$NEEDLE" "$TARGET_FILE" | grep -F "$REPLACE" >/dev/null; then
  echo "OK: Mapping for $NEEDLE already seems present."
  exit 0
fi

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP="${TARGET_FILE}.bak.${TS}"
cp -a "$TARGET_FILE" "$BACKUP"
echo "Backup created: $BACKUP"

python3 - <<PY
import pathlib, re, sys

path = pathlib.Path("${TARGET_FILE}")
content = path.read_text(encoding="utf-8")

# Look for the request object construction in /v1/messages handler
# const request = {
#     model: model || 'claude-3-5-sonnet-20241022',

pattern = r"(const request = \{\s*model: )(model \|\| '[^']+')([,;])"
replacement = r"\1(model === '${NEEDLE}' ? '${REPLACE}' : (model || 'claude-3-5-sonnet-20241022'))\3"

new_content = re.sub(pattern, replacement, content)

if new_content == content:
    print("ERROR: Could not find the pattern to patch in server.js")
    sys.exit(1)

path.write_text(new_content, encoding="utf-8")
print("Successfully patched server.js model assignment.")
PY

echo "Patch applied. Verify with: grep '$NEEDLE' '$TARGET_FILE'"
