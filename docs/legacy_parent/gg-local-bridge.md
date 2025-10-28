# GG Local Bridge setup

The `scripts/gg_local_bridge_setup.sh` helper bootstraps the macOS background
service that connects the Redis queues to the local worker. The script mirrors
the manual steps we used previously (creating the virtual environment, writing
the orchestrator script, generating the `launchd` plist, etc.) so it can be run
repeatably on new machines.

## Usage

```bash
bash scripts/gg_local_bridge_setup.sh
```

All key paths can be overridden when calling the script. For example:

```bash
SOT="$HOME/Library/CloudStorage/GoogleDrive-example/My Drive/02luka" \
AGENT_DIR="$HOME/dev/custom-agent" \
bash scripts/gg_local_bridge_setup.sh
```

After running the script, the worker is available as
`com.02luka.gg_local_bridge` under `launchctl`. The script also provides helper
CLIs (`gg_send.py` and `gg_tail.py`) for interacting with the queues.
