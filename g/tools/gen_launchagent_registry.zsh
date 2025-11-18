#!/usr/bin/env zsh

# gen_launchagent_registry.zsh
# Stub generator for LaunchAgent registry (markdown).
# CURRENT STATUS: DOES NOT GENERATE — DIAGNOSTIC ONLY.

set -euo pipefail

SOT="${SOT:-$HOME/02luka}"

REGISTRY_FILE="$SOT/g/docs/LAUNCHAGENT_REGISTRY.md"

echo "[gen] LaunchAgent Registry Generator (STUB)"
echo "[gen] SOT: $SOT"
echo "[gen] Current registry file: $REGISTRY_FILE"

cat <<'EOF'
[gen] TODO (future PR):
  - Scan LaunchAgent plists (e.g. ~/Library/LaunchAgents/com.02luka.*.plist)
  - Collect: Label, Script path, Critical flag, Role
  - Emit a markdown table to a GENERATED file, e.g.:
      g/docs/LAUNCHAGENT_REGISTRY.generated.md
  - DO NOT overwrite the manual registry automatically.
  - Use diff-only comparison for safety.
EOF

exit 0

