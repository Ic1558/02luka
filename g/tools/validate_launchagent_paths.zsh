#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
REPO_BASE="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULT_BASE="${LUKA_SOT:-$HOME/02luka}"
if [[ -n "${LUKA_SOT:-}" && -d "${LUKA_SOT}" ]]; then
  BASE="$LUKA_SOT"
elif [[ -f "$REPO_BASE/g/tools/lpe_worker.zsh" ]]; then
  BASE="$REPO_BASE"
elif [[ -d "$DEFAULT_BASE" ]]; then
  BASE="$DEFAULT_BASE"
else
  BASE="$REPO_BASE"
fi
TARGETS=("com.02luka.lpe.worker.plist")
ERRS=0

check_plist() {
  local plist="$1"
  if [[ ! -f "$plist" ]]; then
    echo "❌ missing plist: $plist" >&2
    (( ERRS++ ))
    return
  fi

  if ! python3 - "$plist" "$BASE" <<'PY'; then
import plistlib, sys, pathlib, os
plist_path = pathlib.Path(sys.argv[1])
base = pathlib.Path(sys.argv[2])
try:
    data = plistlib.loads(plist_path.read_bytes())
except Exception as exc:  # pragma: no cover - runtime guard
    print(f"❌ parse error for {plist_path}: {exc}")
    sys.exit(1)

args = data.get("ProgramArguments") or []
program = data.get("Program")
script = None
if args:
    script = args[-1]
elif program:
    script = program

if not script:
    print(f"❌ {plist_path}: no Program or ProgramArguments")
    sys.exit(1)

script_path = pathlib.Path(os.path.expandvars(script)).expanduser()
if not script_path.exists():
    fallback = None
    home_root = pathlib.Path.home() / "02luka"
    if script_path.is_absolute() and home_root in script_path.parents:
        try:
            relative = script_path.relative_to(home_root)
            candidate = base / relative
            if candidate.exists():
                script_path = candidate
        except Exception:
            pass
    if not script_path.exists():
        print(f"❌ {plist_path}: script missing -> {script_path}")
        sys.exit(1)

resolved = script_path.resolve()
if base not in resolved.parents and resolved != base:
    print(f"❌ {plist_path}: script not under base {base} -> {resolved}")
    sys.exit(1)

print(f"✅ {plist_path}: OK ({resolved})")
PY
    (( ERRS++ ))
  fi
}

for label in "${TARGETS[@]}"; do
  check_plist "$BASE/LaunchAgents/$label"
done

if (( ERRS > 0 )); then
  exit 1
fi

echo "All LaunchAgent paths valid"
