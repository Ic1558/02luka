# Guardrails
- No symlinks (Google Drive Mirror).
- No hardcoded absolute paths — always use mapping + path_resolver.
- Do not write into a/, c/, o/, s/ — human sandboxes only.
- LaunchAgents must be published via g/tools/launchagent_manager.sh.
- Mapping changes require: mapping_drift_guard.sh --validate and PR approval.
