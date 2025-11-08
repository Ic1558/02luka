# Hub Auto-Index & Memory Sync (Phase 20)

## Run one-shot
```bash
./tools/hub_index_now.zsh
```

## Enable LaunchAgent
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.hub-autoindex.plist 2>/dev/null || true
cp g/launchagents/com.02luka.hub-autoindex.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.02luka.hub-autoindex.plist
launchctl list | grep hub-autoindex || true
```

## Env
- LUKA_MEM_REPO_ROOT
- HUB_INDEX_PATH
- REDIS_URL
