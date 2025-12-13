# Phase 2C-Mini: Recipe - Fix `com.02luka.mary-coo`

**Service:** `com.02luka.mary-coo`  
**Current Issue:** Exit 2 (old path: `/Users/icmini/LocalProjects/02luka_local_g`)  
**Target:** Fix paths → Exit 0/1 (working)

---

## 🔍 Investigation Result

**Current plist points to:** `/Users/icmini/LocalProjects/02luka_local_g/agents/mary/mary.py`  
**Status:** Script doesn't exist in current architecture

**Found alternatives:**
- ✅ `agents/mary_router/gateway_v3_router.py` - Has `if __name__ == "__main__"` entry point
- ⚠️ `agents/liam/mary_router.py` - Integration example, not standalone

**Decision:** Use `gateway_v3_router.py` as replacement (Mary Router Gateway v3 handles WO routing)

---

## Copy-Paste Recipe (Ready to Use)

```bash
cd ~/02luka

# ============================================
# FIX: com.02luka.mary-coo
# ============================================

SERVICE="com.02luka.mary-coo"
PLIST="$HOME/Library/LaunchAgents/${SERVICE}.plist"
SCRIPT_PATH="/Users/icmini/02luka/agents/mary_router/gateway_v3_router.py"

# 1) Bootout current service
echo "🔧 Bootout $SERVICE..."
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true

# 2) Update plist paths
echo "📝 Updating plist paths..."
plutil -replace "ProgramArguments.1" -string "$SCRIPT_PATH" "$PLIST"
plutil -replace "StandardOutPath" -string "$HOME/02luka/logs/launchd_mary_coo.out" "$PLIST"
plutil -replace "StandardErrorPath" -string "$HOME/02luka/logs/launchd_mary_coo.err" "$PLIST"
plutil -replace "EnvironmentVariables.LAC_BASE_DIR" -string "/Users/icmini/02luka" "$PLIST"

# 3) Ensure log directory exists
mkdir -p ~/02luka/logs

# 4) Verify script exists
if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "❌ Script not found: $SCRIPT_PATH"
  exit 1
fi
echo "✅ Script found: $SCRIPT_PATH"

# 5) Make script executable
chmod +x "$SCRIPT_PATH"

# 6) Validate plist
plutil -lint "$PLIST" && echo "✅ Plist valid" || { echo "❌ Plist invalid"; exit 1; }

# 7) Reload service
echo "🔄 Reloading service..."
launchctl bootstrap "gui/$(id -u)" "$PLIST"

# 8) Verify (wait a moment for service to start)
sleep 3
EXIT_CODE=$(launchctl list | grep "$SERVICE" | awk '{print $2}')
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Result: Exit code = $EXIT_CODE"
if [[ "$EXIT_CODE" == "0" ]] || [[ "$EXIT_CODE" == "1" ]]; then
  echo "✅ Service working (exit $EXIT_CODE is acceptable)"
  echo "   Check log: tail -20 ~/02luka/logs/launchd_mary_coo.out"
else
  echo "❌ Service still failing (exit $EXIT_CODE)"
  echo "   Check error log: tail -20 ~/02luka/logs/launchd_mary_coo.err"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

---

## Verification Commands

```bash
# Check exit code
launchctl list | grep "mary-coo"

# Check log for success patterns
tail -20 ~/02luka/logs/launchd_mary_coo.out | grep -E "Gateway|started|Processing|inbox"

# Check for errors
tail -20 ~/02luka/logs/launchd_mary_coo.err | grep -v "^$"
```

**Expected log patterns (from gateway_v3_router.py):**
- `Gateway v3 Router started. Watching bridge/inbox/MAIN/...`
- `Processing <wo_file>.yaml...` (when WOs are present)
- No `FileNotFoundError` or `ModuleNotFoundError`

---

## Alternative: If Service Should Be Removed

**If mary-coo is truly obsolete (replaced by gateway_v3):**

```bash
cd ~/02luka

SERVICE="com.02luka.mary-coo"
ARCHIVE_DIR="$HOME/02luka/_plists_archive_20251207"

# Bootout
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true

# Archive plist
mkdir -p "$ARCHIVE_DIR"
mv "$HOME/Library/LaunchAgents/${SERVICE}.plist" "$ARCHIVE_DIR/" && echo "✅ Archived" || echo "⚠️  Already removed"
```

---

```bash
cd ~/02luka

SERVICE="com.02luka.mary-coo"
ARCHIVE_DIR="$HOME/02luka/_plists_archive_20251207"

# Bootout
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true

# Archive plist
mkdir -p "$ARCHIVE_DIR"
mv "$HOME/Library/LaunchAgents/${SERVICE}.plist" "$ARCHIVE_DIR/" && echo "✅ Archived" || echo "⚠️  Already removed"
```

---

**Reference:**
- Quick Ref: `launchagent_repair_PHASE2C_MINI_QUICK_REF.md`
- Expected Behavior: `launchagent_repair_PHASE2C_MINI_EXPECTED_BEHAVIOR.md`
