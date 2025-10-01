# Task Recipes

1) Boss-UI (React+Node)
- boss-api: list/read via resolver; endpoints `/api/list/:folder`, `/api/file/:folder/:name`
- boss-ui: Gmail-like sidebar (Inbox/Sent/Deliverables/Dropbox/Drafts/Documents)
- README explains Boss flow and how to run

2) Add routing rule
- Edit `boss/routing.rules.yml`
- E2E: drop a `.json` into `human.dropbox` → must appear in `f/bridge/inbox`

3) New watcher LaunchAgent
- Create plist under g/fixed_launchagents/
- Publish with launchagent_manager.sh; logs under ~/Library/Logs/02luka/

4) Nightly self-test
- g/tools/nightly_selftest.sh + plist → write summary to run/system_status.v2.json

---

# Prompt: Boss UI Scaffold
Use `.codex/PREPROMPT.md` as system context.

Goal: Scaffold “Boss UI” (Gmail-like) that reads/writes via mapping keys (`human.*`) only.

Steps:
1. Read `.codex/CONTEXT_SEED.md` and `.codex/PATH_KEYS.md`.
2. Create boss-api (Node) with endpoints `/api/list/:folder` and `/api/file/:folder/:name` that resolve paths using `g/tools/path_resolver.sh`.
3. Create boss-ui (React) with sidebar: Inbox, Sent, Deliverables, Dropbox, Drafts, Documents; main panel: file list + markdown viewer.
4. Provide a README inside boss-ui explaining Boss Workspace flow and how to run locally.
5. Add a smoke test plan: place a file in `human.dropbox` and verify it appears in the UI (list).
6. Update docs if needed.

Constraints:
- No symlinks. No hardcoded absolute paths.
- Keep changes small and self-contained. Provide a PR description with the test plan.

---

# Environment Setup Notes
- Add `.devcontainer/devcontainer.json` or a Dockerfile with `postCreateCommand: .codex/preflight.sh`.
- Alternatively, run `bash .codex/preflight.sh` before development sessions to fetch the latest context.

---

# Recipe: CLC Soft Pre-Push Gate (push safety without pain)

## Purpose
รัน preflight + mapping guard (+ optional smoke) ทุกครั้งก่อน push แบบ ไม่กวนงาน: WARN ผ่านได้, FAIL เท่านั้นที่บล็อก — และถ้า gate หายไป hook จะ “ข้ามแบบไม่ล้ม”

## Install (one-time)
1. Gate script

```bash
mkdir -p g/tools
cat > g/tools/clc_gate.sh <<'SH'
#!/usr/bin/env bash
# CLC gate: soft by default (WARN passes), block on FAIL; set CLC_STRICT=1 to block WARN too
set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCOPE="${1:-prepush}"
STRICT="${CLC_STRICT:-0}"
ok=0; warn=0; fail=0

run_check () {
  local name="$1"; shift
  echo "[CLC] check: $name"
  if output=$("$@" 2>&1); then
    echo "  ✓ $name: OK"
    ok=$((ok+1))
  else
    if echo "$output" | grep -qiE 'fatal|FAIL|error (critical)'; then
      echo "  ✗ $name: FAIL"
      echo "$output" | sed 's/^/    /'
      fail=$((fail+1))
    else
      echo "  ! $name: WARN"
      echo "$output" | sed 's/^/    /'
      warn=$((warn+1))
    fi
  fi
}

[ -x "$ROOT/.codex/preflight.sh" ] && run_check preflight bash "$ROOT/.codex/preflight.sh"
[ -x "$ROOT/g/tools/mapping_drift_guard.sh" ] && run_check mapping_drift_guard bash "$ROOT/g/tools/mapping_drift_guard.sh" --validate
[ -x "$ROOT/run/smoke_api_ui.sh" ] && run_check smoke_api_ui bash "$ROOT/run/smoke_api_ui.sh" </dev/null || true

echo "[CLC] summary: OK=$ok WARN=$warn FAIL=$fail (scope=$SCOPE strict=$STRICT)"
if [ "$fail" -gt 0 ]; then
  echo "[CLC] blocking push due to FAIL."
  exit 1
fi
if [ "$STRICT" = 1 ] && [ "$warn" -gt 0 ]; then
  echo "[CLC] strict mode: WARN treated as FAIL."
  exit 1
fi
echo "[CLC] gate passed."
exit 0
SH
chmod +x g/tools/clc_gate.sh
```

2. Pre-push hook (tolerant)

```bash
cat > .git/hooks/pre-push <<'SH'
#!/usr/bin/env bash
set -e
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
GATE="$ROOT/g/tools/clc_gate.sh"

echo "[HOOK] pre-push → CLC gate"
if [ -x "$GATE" ]; then
  bash "$GATE" prepush
else
  echo "[HOOK] CLC gate missing → skipping (no fail)"
fi
SH
chmod +x .git/hooks/pre-push
```

## Usage
- ปกติ (soft gate): `git push`
- เข้มงวด (ให้ WARN บล็อกด้วย): `CLC_STRICT=1 git push`
- ข้ามครั้งเดียว (ไม่แนะนำให้ใช้เป็นนิสัย): `git push --no-verify`

## What it runs
- `.codex/preflight.sh` → ตรวจ environment + namespaces
- `g/tools/mapping_drift_guard.sh --validate` → mapping sync
- `run/smoke_api_ui.sh` → API/UI smoke (non-fatal ในโหมด soft)

## Troubleshooting
- Gate missing: hook จะพิมพ์ skipping (no fail) → ติดตั้ง gate ตามขั้นตอนบน
- Port busy ใน smoke: `lsof -ti:5173 | xargs kill -9` หรือชั่วคราวถอดสิทธิ์รันจาก `run/smoke_api_ui.sh`
- ถูกบล็อกด้วย FAIL แต่จำเป็นต้อง push: `git push --no-verify` (ใส่เหตุผลใน PR)
