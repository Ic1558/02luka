#!/bin/zsh
# tools/atg_snap.zsh - Antigravity System Snapshot
# Captures runtime state for AI debugging.

OUT_FILE="magic_bridge/snapshot.md"
[ ! -d "magic_bridge" ] && mkdir -p "magic_bridge"

echo "# ATG Snapshot $(date)" > "$OUT_FILE"

echo "\n## 1. Git State 🌳" >> "$OUT_FILE"
echo "\`\`\`" >> "$OUT_FILE"
git status -s 2>&1 | sed 's/^/  /' >> "$OUT_FILE"
echo "\n--- Recent Log ---" >> "$OUT_FILE"
git log -n 3 --oneline 2>&1 | sed 's/^/  /' >> "$OUT_FILE"
echo "\`\`\`" >> "$OUT_FILE"

echo "\n## 2. Daemons ⚙️" >> "$OUT_FILE"
echo "\`\`\`" >> "$OUT_FILE"
pgrep -fl "gemini_bridge|fs_watcher|python" | sort | sed 's/^/  /' >> "$OUT_FILE"
echo "\`\`\`" >> "$OUT_FILE"

echo "\n## 3. Ports 🔌" >> "$OUT_FILE"
echo "\`\`\`" >> "$OUT_FILE"
tools/ports_check.zsh 2>/dev/null | grep -E "safe|conflict|unknown" | sed 's/^/  /' >> "$OUT_FILE"
echo "\`\`\`" >> "$OUT_FILE"

echo "\n## 4. Telemetry (Recent) 📈" >> "$OUT_FILE"
echo "\`\`\`json" >> "$OUT_FILE"
tail -n 10 g/telemetry/fs_index.jsonl 2>/dev/null >> "$OUT_FILE"
echo "\`\`\`" >> "$OUT_FILE"

echo "\n## 5. System Logs (Errors) 🚨" >> "$OUT_FILE"
echo "\`\`\`" >> "$OUT_FILE"
echo "--- fs_watcher.stderr ---" >> "$OUT_FILE"
tail -n 5 /tmp/com.02luka.fs_watcher.stderr.log 2>/dev/null >> "$OUT_FILE"
echo "--- bridge.stderr ---" >> "$OUT_FILE"
tail -n 5 /tmp/com.antigravity.bridge.stderr.log 2>/dev/null >> "$OUT_FILE"
echo "\`\`\`" >> "$OUT_FILE"

echo "📸 Snapshot saved to: $OUT_FILE"
cat "$OUT_FILE"
