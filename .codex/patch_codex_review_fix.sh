#!/usr/bin/env bash
set -euo pipefail

# -- helpers (portable sed -i)
sedi() { if sed --version >/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi; }

changed=0

# 1) boss-ui/shared/api.js -> use explicit API_BASE instead of location.origin
mkdir -p boss-ui/shared
if [ -f boss-ui/shared/api.js ]; then
  if ! grep -q "API_BASE" boss-ui/shared/api.js; then
    tmp="$(mktemp)"; cat > "$tmp" <<'JS'
// NOTE: explicit API base so UI (5173) can talk to API (4000)
window.API_BASE = window.API_BASE || "http://127.0.0.1:4000";

export async function jfetch(path, opts = {}) {
  const base = window.API_BASE || "http://127.0.0.1:4000";
  const url  = new URL(path, base);
  const init = { headers: { 'Content-Type': 'application/json' }, ...(opts||{}) };
  const res  = await fetch(url.toString(), init);
  if (!res.ok) {
    const txt = await res.text().catch(()=> '');
    throw new Error(`API ${res.status} ${res.statusText} @ ${url}: ${txt}`);
  }
  // try JSON first; fall back to text
  const ct = res.headers.get('content-type') || '';
  if (ct.includes('application/json')) return res.json();
  return res.text();
}
JS
    mv "$tmp" boss-ui/shared/api.js
    echo "[api.js] injected API_BASE & robust jfetch"
    changed=$((changed+1))
  else
    # best-effort replace if old pattern exists
    if grep -q "new URL(path, location.origin)" boss-ui/shared/api.js; then
      if sed --version >/dev/null 2>&1; then
        sed -i 's|new URL(path, location.origin)|new URL(path, (window.API_BASE||"http://127.0.0.1:4000"))|' boss-ui/shared/api.js
      else
        sed -i '' 's|new URL(path, location.origin)|new URL(path, (window.API_BASE||"http://127.0.0.1:4000"))|' boss-ui/shared/api.js
      fi
      echo "[api.js] rewired jfetch to API_BASE"
      changed=$((changed+1))
    fi
  fi
else
  echo "[api.js] skip (file not found)"
fi

# 2) run/dev_up_simple.sh -> export API_BASE before serving UI
if [ -f run/dev_up_simple.sh ]; then
  if ! grep -q 'API_BASE=' run/dev_up_simple.sh; then
    # insert export before python http.server line when possible
    if grep -n "python3 -m http.server" run/dev_up_simple.sh >/dev/null; then
      line=$(grep -n "python3 -m http.server" run/dev_up_simple.sh | head -1 | cut -d: -f1)
      awk -v inject_line="$line" '
        NR==inject_line{ print "export API_BASE=\"http://127.0.0.1:4000\""; print; next } { print }
      ' run/dev_up_simple.sh > run/dev_up_simple.sh.new && mv run/dev_up_simple.sh.new run/dev_up_simple.sh
      chmod +x run/dev_up_simple.sh
      echo "[dev_up_simple.sh] exported API_BASE"
      changed=$((changed+1))
    fi
  fi
else
  echo "[dev_up_simple.sh] skip (file not found)"
fi

# 3) scripts/gg_local_bridge.py -> safe path containment check
if [ -f scripts/gg_local_bridge.py ]; then
  if ! grep -q "is_relative_to" scripts/gg_local_bridge.py; then
    # Patch function in_safelist if it contains startswith
    if grep -q "startswith(safe)" scripts/gg_local_bridge.py; then
      python3 - <<'PY'
from pathlib import Path
p = Path("scripts/gg_local_bridge.py")
s = p.read_text()
s = s.replace("startswith(safe)", "is_relative_to(Path(safe))")
p.write_text(s)
PY
      # add fallback block if needed
      if ! grep -q "commonpath" scripts/gg_local_bridge.py; then
        cat >> scripts/gg_local_bridge.py <<'PY'

# Fallback for Python <3.9 environments
def _is_inside(child, parent):
    import os
    try:
        return Path(child).is_relative_to(Path(parent))
    except AttributeError:
        return os.path.commonpath([str(Path(child).resolve()), str(Path(parent).resolve())]) == str(Path(parent).resolve())
PY
      fi
      echo "[gg_local_bridge.py] hardened safelist (is_relative_to/commonpath)"
      changed=$((changed+1))
    fi
  fi
else
  echo "[gg_local_bridge.py] skip (file not found)"
fi

# 4) scripts/gg_local_bridge_setup.sh -> dynamic ALLOW_PATH_*
if [ -f scripts/gg_local_bridge_setup.sh ]; then
  # ensure we resolve SOT_PATH / REPO_PATH into plist
  if ! grep -q "SOT_PATH" scripts/gg_local_bridge_setup.sh; then
    cat >> scripts/gg_local_bridge_setup.sh <<'SH'

# --- dynamic allow paths (override with env when running the setup) ---
SOT_PATH="${SOT_PATH:-$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka}"
REPO_PATH="${REPO_PATH:-$HOME/dev/02luka-repo}"
# when generating LaunchAgent plist:
#   <key>ALLOW_PATH_1</key><string>'"$SOT_PATH"'</string>
#   <key>ALLOW_PATH_2</key><string>'"$REPO_PATH"'</string>
SH
    echo "[gg_local_bridge_setup.sh] appended dynamic allow paths usage note"
    changed=$((changed+1))
  fi
else
  echo "[gg_local_bridge_setup.sh] skip (file not found)"
fi

echo "[patch] files changed: $changed"
exit 0
