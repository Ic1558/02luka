# Errors & Fixes Summary
- Docker stack down → restart via FIX-DEV-ENVIRONMENT.sh
- MCP Bridge (3003) closed → after Docker up, port should open
- FastVLM (5012) closed → ensure container present or mark optional
- LaunchAgents failing → reload via FIX-LAUNCHAGENTS.sh --fix
