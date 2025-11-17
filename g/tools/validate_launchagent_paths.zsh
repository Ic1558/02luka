#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
FILTER="${LAUNCH_AGENT_FILTER:-com.02luka.lpe.worker.plist}"
PLISTS=(${BASE}/LaunchAgents/$FILTER)

if (( ${#PLISTS[@]} == 0 )); then
  echo "No LaunchAgents matched filter '$FILTER' under $BASE/LaunchAgents" >&2
  exit 0
fi

python3 - "$BASE" "${PLISTS[@]}" <<'PY'
import os
import plistlib
import sys
import pathlib

base = pathlib.Path(sys.argv[1]).resolve()
plists = [pathlib.Path(p) for p in sys.argv[2:]]
errors = 0

home_prefix = pathlib.Path.home() / "02luka"

for plist in plists:
    try:
        data = plistlib.load(plist.open("rb"))
    except Exception as exc:  # noqa: BLE001
        print(f"{plist}: failed to parse plist ({exc})")
        errors += 1
        continue

    program = data.get("Program")
    prog_args = data.get("ProgramArguments") or []
    script_path = program or (prog_args[-1] if prog_args else None)

    if not script_path:
        print(f"{plist}: missing Program/ProgramArguments")
        errors += 1
        continue

    if "/Users/" in script_path and "$HOME" not in script_path and "${HOME}" not in script_path:
        print(f"{plist}: hard-coded absolute user path -> {script_path}")
        errors += 1

    expanded = os.path.expandvars(script_path.replace("${HOME}", str(pathlib.Path.home())))
    resolved = pathlib.Path(expanded).expanduser()
    if not resolved.is_absolute():
        resolved = (base / resolved).resolve()

    if not resolved.exists() and home_prefix in resolved.parents:
        alt = pathlib.Path(str(resolved).replace(str(home_prefix.resolve()), str(base)))
        if alt.exists():
            resolved = alt

    if not resolved.exists():
        print(f"{plist}: referenced script not found -> {resolved}")
        errors += 1

if errors:
    sys.exit(errors)
print("LaunchAgent path validation passed")
PY
