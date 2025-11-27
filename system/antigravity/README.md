# Antigravity

Simple greeting demo with lightweight tests.

## Layout
- `core/hello.py` — `Greeter` class with `say_hello` / `say_goodbye`
- `tests/test_hello.py` — pytest-style smoke test

## Running tests
```
cd /Users/icmini/02luka/system/antigravity
python -m pytest tests/test_hello.py
```

## Notes
- Package import: `from antigravity.core.hello import Greeter`
- Symlink: `g/src/antigravity` points to this directory for LAC lanes.

## Optional local CI (LaunchAgent)
- Plist: `g/launchd/com.02luka.antigravity-ci.plist`
- Script: `/Users/icmini/02luka/system/antigravity/scripts/antigravity_ci.zsh`
- Manual install (opt-in):
  ```
  cp g/launchd/com.02luka.antigravity-ci.plist ~/Library/LaunchAgents/
  launchctl load ~/Library/LaunchAgents/com.02luka.antigravity-ci.plist
  ```
- Disable/unload:
  ```
  launchctl unload ~/Library/LaunchAgents/com.02luka.antigravity-ci.plist
  rm ~/Library/LaunchAgents/com.02luka.antigravity-ci.plist
  ```
