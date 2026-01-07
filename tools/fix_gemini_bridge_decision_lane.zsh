#!/usr/bin/env zsh
set -euo pipefail

die(){ print -u2 "❌ $*"; exit 1; }
info(){ print "ℹ️  $*"; }

REPO="$HOME/02luka"
GB="$REPO/gemini_bridge.py"
VENV_PY="$REPO/gemini_venv/bin/python3"

[[ -f "$GB" ]] || die "missing: $GB"
[[ -x "$VENV_PY" ]] || die "missing venv python: $VENV_PY"

TS="$(date +%Y%m%d_%H%M%S)"
BAK="$GB.bak_fix_${TS}"
cp -f "$GB" "$BAK"
info "backup: $BAK"

python3 - <<'PY'
import os, re, sys

gb = os.path.expanduser("~/02luka/gemini_bridge.py")
txt = open(gb, "r", encoding="utf-8").read()

def ensure_once(pattern, repl, desc):
    global txt
    if re.search(pattern, txt, flags=re.M):
        return
    txt2, n = re.subn(pattern, repl, txt, flags=re.M)
    if n == 0:
        raise SystemExit(f"PATCH_FAIL: cannot apply for {desc}")
    txt = txt2

# 1) WATCH_DIR should point to inbox (avoid recursive needs)
# replace WATCH_DIR = "./magic_bridge" (or anything) -> "./magic_bridge/inbox"
txt = re.sub(r'^(WATCH_DIR\s*=\s*["\']).*(["\']\s*)$', r'\1./magic_bridge/inbox\2', txt, flags=re.M)

# 2) Ensure decision_summarizer import block exists (non-fatal)
if "02LUKA_DECISION_SUMMARIZER_IMPORT" not in txt:
    # Insert after last import/from in top area
    lines = txt.splitlines(True)
    ins = 0
    for i, ln in enumerate(lines[:120]):
        if re.match(r"^\s*(import|from)\s+", ln):
            ins = i+1
    block = (
        "\n# >>> 02LUKA_DECISION_SUMMARIZER_IMPORT >>>\n"
        "try:\n"
        "    from decision_summarizer import summarize_decision\n"
        "except Exception:\n"
        "    summarize_decision = None\n"
        "# <<< 02LUKA_DECISION_SUMMARIZER_IMPORT <<<\n"
    )
    lines.insert(ins, block + "\n")
    txt = "".join(lines)

# 3) Ensure on_created exists and calls process_file (skip directories, .DS_Store, .summary)
if "def on_created" not in txt:
    # Insert right before on_modified definition in handler class
    pat = r"^(\s*)def on_modified\(self,\s*event\):"
    m = re.search(pat, txt, flags=re.M)
    if not m:
        raise SystemExit("PATCH_FAIL: cannot find on_modified to anchor on_created insertion")
    indent = m.group(1)
    block = (
        f"{indent}def on_created(self, event):\n"
        f"{indent}    \"\"\"Handle new file creation events.\"\"\"\n"
        f"{indent}    if event.is_directory:\n"
        f"{indent}        return\n"
        f"{indent}    filename = os.path.basename(event.src_path)\n"
        f"{indent}    if filename == '.DS_Store' or filename.endswith('.summary.txt'):\n"
        f"{indent}        return\n"
        f"{indent}    print(f\"📝 Detected new file: {filename}\")\n"
        f"{indent}    time.sleep(0.5)\n"
        f"{indent}    self.process_file(event.src_path)\n\n"
    )
    txt = re.sub(pat, block + indent + "def on_modified(self, event):", txt, flags=re.M)

# 4) Decision telemetry logging: enforce correct repo_root path (~/02luka)
# If your block exists, normalize the log_path calculation to repo_root=dirname(abspath(__file__))
if "02LUKA_DECISION_SUMMARIZER_LOG" in txt:
    # replace any older log_path assignment inside that block
    txt = re.sub(
        r"log_path\s*=\s*os\.path\.join\([^\n]+\)",
        "repo_root = os.path.dirname(os.path.abspath(__file__))\n                    log_path = os.path.join(repo_root, 'g/telemetry/decision_log.jsonl')",
        txt
    )
else:
    # Insert block right after "content = f.read()" and before "if not content.strip(): return"
    pat = r"(\s*content\s*=\s*f\.read\(\)\s*\n)"
    if not re.search(pat, txt, flags=re.M):
        raise SystemExit("PATCH_FAIL: cannot find 'content = f.read()' for telemetry insertion")
    block = (
        "\n            # >>> 02LUKA_DECISION_SUMMARIZER_LOG >>>\n"
        "            # Log decision analysis (telemetry, non-blocking)\n"
        "            if content.strip() and summarize_decision is not None:\n"
        "                try:\n"
        "                    decision_info = summarize_decision(content)\n"
        "                    repo_root = os.path.dirname(os.path.abspath(__file__))\n"
        "                    log_path = os.path.join(repo_root, 'g/telemetry/decision_log.jsonl')\n"
        "                    os.makedirs(os.path.dirname(log_path), exist_ok=True)\n"
        "                    with open(log_path, 'a', encoding='utf-8') as _log:\n"
        "                        _log.write(decision_info.to_json() + '\\n')\n"
        "                except Exception:\n"
        "                    pass\n"
        "            # <<< 02LUKA_DECISION_SUMMARIZER_LOG <<<\n\n"
    )
    txt = re.sub(pat, r"\1" + block, txt, flags=re.M)

# 5) Output summary to outbox (avoid inbox loop)
# Replace: output_path = f"{file_path}.summary.txt" -> outbox/<filename>.summary.txt
# Only patch if the old pattern exists somewhere.
if "output_path = f\"{file_path}.summary.txt\"" in txt or "output_path = f'{file_path}.summary.txt'" in txt:
    txt = re.sub(
        r"output_path\s*=\s*f[\"']\{file_path\}\.summary\.txt[\"']",
        "filename = os.path.basename(file_path)\n            outbox_dir = os.path.join(os.path.dirname(os.path.dirname(file_path)), 'outbox')\n            os.makedirs(outbox_dir, exist_ok=True)\n            output_path = os.path.join(outbox_dir, f\"{filename}.summary.txt\")",
        txt
    )

open(gb, "w", encoding="utf-8").write(txt)
print("OK_PATCHED")
PY

info "syntax check..."
"$VENV_PY" -m py_compile "$GB" >/dev/null
info "✅ py_compile OK"

info "restart bridge (kill old)..."
pkill -9 -f "gemini_bridge.py" >/dev/null 2>&1 || true

info "start bridge (background, logs in /tmp)..."
nohup "$VENV_PY" -u "$GB" > /tmp/bridge_stdout.log 2> /tmp/bridge_stderr.log &
sleep 1

info "quick test: create file in inbox"
TEST="test_decision_lane_${TS}.md"
echo "CRITICAL: sudo rm -rf /var/log && chmod 777 /etc/passwd && launchctl load /tmp/malicious.plist" > "$REPO/magic_bridge/inbox/$TEST"

info "wait 12s..."
sleep 12

OUT="$REPO/magic_bridge/outbox/$TEST.summary.txt"
DEC="$REPO/g/telemetry/decision_log.jsonl"

info "verify outputs..."
[[ -f "$OUT" ]] || die "missing summary output: $OUT (check /tmp/bridge_stdout.log)"
[[ -f "$DEC" ]] || die "missing decision log: $DEC (check /tmp/bridge_stderr.log)"

info "✅ OK: summary + decision_log created"
info "tail decision_log:"
tail -n 3 "$DEC" || true
