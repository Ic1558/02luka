#!/usr/bin/env zsh
set -euo pipefail

# Rollback script for: {{ feature_name }}
# Generated under V3.5 deploy policy
# Date: {{ date }}
# NOTE: This must be reviewed before first use.

BASE="${HOME}/02luka"

echo "⚠️  Rolling back feature: {{ feature_name }}"
echo "Base: $BASE"

# 1) Restore files (manual or from backup/snapshot)
#    Example (to be customized):
{% for file in files_changed %}
# cp "$BASE/backup/{{ file }}" "$BASE/{{ file }}"
{% endfor %}

# 2) Restart services / LaunchAgents if needed
{% if changes_launchagents_or_runtime %}
# launchctl bootout gui/$(id -u) com.02luka.some-agent || true
# launchctl bootstrap gui/$(id -u) "$BASE/launchd/com.02luka.some-agent.plist"
{% endif %}

# 3) Revert schema changes if needed
{% if changes_schema %}
# git checkout HEAD -- schemas/
{% endif %}

# 4) Log rollback to AP/IO
python3 << 'PYTHON'
import sys
sys.path.insert(0, '{{ base_path }}')
from tools.ap_io_v31.writer import write_ledger_entry

write_ledger_entry(
    agent="Hybrid",
    event="deployment_rolled_back",
    data={
        "feature_name": "{{ feature_name }}",
        "rollback_date": "{{ date }}",
        "files_restored": {{ files_changed | tojson }}
    }
)
print("✅ Rollback logged to AP/IO")
PYTHON

echo "✅ Rollback script completed (if all steps were implemented)."
echo "⚠️  IMPORTANT: Verify system state manually before proceeding."
