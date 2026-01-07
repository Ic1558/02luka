#!/usr/bin/env zsh
# Core History Sync — standalone generator for shared agent history
# - Deterministic, SIP-friendly, atomic writes
# - Works without Antigravity/Raycast; best-effort inputs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OUT_DIR_DEFAULT="$ROOT/g/telemetry/core_history"
OUT_DIR="$OUT_DIR_DEFAULT"
MODE="run"             # run | dry-run
MAX_DECISIONS=40
MAX_OPS=40

usage() {
  cat <<'USAGE'
Usage: tools/core_history_sync.zsh [--dry-run|--run] [--out-dir DIR] [--max-decisions N] [--max-ops N]

Options:
  --dry-run         Show JSON/MD preview to stdout (no writes)
  --run             Write outputs atomically (default)
  --out-dir DIR     Output directory (default: g/telemetry/core_history)
  --max-decisions N Tail size for decision_log.jsonl (default: 40)
  --max-ops N       Tail size for ops logs (default: 40)
  --help            Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run" ;;
    --run) MODE="run" ;;
    --out-dir) OUT_DIR="${2:-}"; shift ;;
    --max-decisions) MAX_DECISIONS="${2:-40}"; shift ;;
    --max-ops) MAX_OPS="${2:-40}"; shift ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

DECISION_LOG="$ROOT/g/telemetry/decision_log.jsonl"
OPS_RUNNER="$ROOT/g/telemetry/atg_runner.jsonl"
OPS_FS="$ROOT/g/telemetry/fs_index.jsonl"
SNAPSHOT_MD="$ROOT/magic_bridge/inbox/atg_snapshot.md"
SNAPSHOT_SUMMARY="${SNAPSHOT_MD}.summary.txt"
CODEX_LOG="$ROOT/g/reports/codex_routing_log.jsonl"
TASKS_JSON="$ROOT/g/knowledge/tasks.jsonl"
RULE_PATH="$ROOT/decision_summarizer.py"

GIT_BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
GIT_HEAD="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"
GIT_STATUS="$(git -C "$ROOT" status --porcelain=v1 2>/dev/null || true)"

if [[ "$MODE" == "run" ]]; then
  mkdir -p "$OUT_DIR"
fi

OUT_JSON_TMP=""
OUT_MD_TMP=""
OUT_STATUS_TMP=""
OUT_JSON=""
OUT_MD=""
OUT_STATUS=""

if [[ "$MODE" == "run" ]]; then
  OUT_JSON="$OUT_DIR/latest.json"
  OUT_MD="$OUT_DIR/latest.md"
  OUT_STATUS="$OUT_DIR/core_history_status.json"
  OUT_JSON_TMP="$(mktemp "${OUT_DIR}/latest.json.XXXXXX")"
  OUT_MD_TMP="$(mktemp "${OUT_DIR}/latest.md.XXXXXX")"
  OUT_STATUS_TMP="$(mktemp "${OUT_DIR}/core_history_status.json.XXXXXX")"
fi

CORE_ROOT="$ROOT" \
CORE_MODE="$MODE" \
MAX_DECISIONS="$MAX_DECISIONS" \
MAX_OPS="$MAX_OPS" \
DECISION_LOG="$DECISION_LOG" \
OPS_RUNNER="$OPS_RUNNER" \
OPS_FS="$OPS_FS" \
SNAPSHOT_MD="$SNAPSHOT_MD" \
SNAPSHOT_SUMMARY="$SNAPSHOT_SUMMARY" \
CODEX_LOG="$CODEX_LOG" \
TASKS_JSON="$TASKS_JSON" \
RULE_PATH="$RULE_PATH" \
GIT_BRANCH="$GIT_BRANCH" \
GIT_HEAD="$GIT_HEAD" \
GIT_STATUS="$GIT_STATUS" \
OUT_JSON="$OUT_JSON_TMP" \
OUT_MD="$OUT_MD_TMP" \
OUT_STATUS="$OUT_STATUS_TMP" \
OUT_DIR="$OUT_DIR" \
python3 - "$MODE" <<'PY'
import json, os, sys, time, socket, hashlib, pathlib, datetime, importlib.util
from collections import deque

def tail_jsonl(path, limit):
    try:
        dq = deque(maxlen=limit)
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    dq.append(line)
        out = []
        for line in dq:
            try:
                out.append(json.loads(line))
            except Exception:
                out.append({"raw": line, "parse_error": True})
        return out
    except FileNotFoundError:
        return {"status": "missing"}
    except Exception as e:
        return {"status": "error", "error": str(e)}

def read_text(path, max_chars=8000):
    try:
        with open(path, "r", encoding="utf-8") as f:
            txt = f.read()
        if len(txt) > max_chars:
            return txt[:max_chars] + "…"
        return txt
    except FileNotFoundError:
        return None
    except Exception as e:
        return f"[error: {e}]"

def compute_rule_hash(decision_path):
    p = pathlib.Path(decision_path)
    if not p.exists():
        return {"status": "missing"}
    try:
        spec = importlib.util.spec_from_file_location("decision_summarizer", decision_path)
        if spec is None or spec.loader is None:
            return {"status": "error", "error": "loader_not_available"}
        mod = importlib.util.module_from_spec(spec)
        import sys as _sys
        _sys.modules[spec.name] = mod
        spec.loader.exec_module(mod)
        tbl = getattr(mod, "RULE_TABLE", None)
        if tbl is None:
            return {"status": "missing_RULE_TABLE"}
        encoded = json.dumps(tbl, sort_keys=True, ensure_ascii=False).encode("utf-8")
        h = hashlib.sha256(encoded).hexdigest()
        return {"status": "ok", "hash": h, "count": len(tbl)}
    except Exception as e:
        return {"status": "error", "error": str(e)}

def normalize_decisions(decisions):
    if isinstance(decisions, list):
        out = []
        for item in decisions:
            if isinstance(item, dict):
                out.append({
                    "ts": item.get("ts"),
                    "risk": item.get("risk"),
                    "route_hint": item.get("route_hint"),
                    "requires": item.get("requires"),
                    "matched_rules": item.get("matched_rules"),
                    "text_preview": item.get("text_preview"),
                })
            else:
                out.append({"raw": item})
        return out
    return decisions

def normalize_list(entries):
    if isinstance(entries, list):
        out = []
        for e in entries:
            out.append(e if isinstance(e, dict) else {"raw": e})
        return out
    return entries

root = os.environ["CORE_ROOT"]
mode = os.environ.get("CORE_MODE", "run")
limit_dec = int(os.environ.get("MAX_DECISIONS", "40"))
limit_ops = int(os.environ.get("MAX_OPS", "40"))

decision_log = os.environ["DECISION_LOG"]
ops_runner = os.environ["OPS_RUNNER"]
ops_fs = os.environ["OPS_FS"]
snapshot_md = os.environ["SNAPSHOT_MD"]
snapshot_summary = os.environ["SNAPSHOT_SUMMARY"]
codex_log = os.environ["CODEX_LOG"]
tasks_json = os.environ["TASKS_JSON"]
rule_path = os.environ["RULE_PATH"]

git_branch = os.environ.get("GIT_BRANCH", "?")
git_head = os.environ.get("GIT_HEAD", "?")
git_status = os.environ.get("GIT_STATUS", "").strip()

decisions = tail_jsonl(decision_log, limit_dec)
ops1 = tail_jsonl(ops_runner, limit_ops)
ops2 = tail_jsonl(ops_fs, limit_ops)
codex = tail_jsonl(codex_log, min(limit_ops, 20))
tasks = tail_jsonl(tasks_json, min(limit_ops, 20))
snap_text = read_text(snapshot_md, max_chars=12000)
snap_summary = read_text(snapshot_summary, max_chars=8000)
rule_info = compute_rule_hash(rule_path)

now = int(time.time())
meta = {
    "ts": now,
    "ts_iso": datetime.datetime.fromtimestamp(now, datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
    "host": socket.gethostname(),
    "generator_version": "1.0.0",
    "mode": mode,
    "root": root,
    "git": {"branch": git_branch, "head": git_head, "status": git_status},
}

snapshot = {
    "path": snapshot_md,
    "status": "present" if snap_text is not None else "missing",
    "summary_status": "present" if snap_summary is not None else "missing",
    "content_preview": snap_text[:800] if snap_text else None,
    "summary_preview": snap_summary[:800] if snap_summary else None,
}

payload = {
    "meta": meta,
    "snapshot": snapshot,
    "decisions": normalize_decisions(decisions),
    "ops": {
        "atg_runner": normalize_list(ops1),
        "fs_index": normalize_list(ops2),
    },
    "tasks": {
        "codex_routing": codex,
        "task_tracker": tasks,
    },
    "rules": rule_info,
    "sources": {
        "decision_log": decision_log,
        "snapshot_md": snapshot_md,
        "snapshot_summary": snapshot_summary,
        "ops_runner": ops_runner,
        "ops_fs": ops_fs,
        "codex_log": codex_log,
        "tasks_json": tasks_json,
        "rule_path": rule_path,
    },
}

json_out = json.dumps(payload, ensure_ascii=False, indent=2)

def build_md():
    lines = []
    lines.append("# Core History Snapshot")
    lines.append(f"- Generated: {meta['ts_iso']}")
    lines.append(f"- Mode: {mode}")
    lines.append(f"- Git: {git_branch}@{git_head}")
    lines.append("")
    lines.append("## Snapshot")
    lines.append(f"- Status: {snapshot['status']}")
    lines.append(f"- File: {snapshot_md}")
    lines.append(f"- Summary: {snapshot['summary_status']} (run bridge to generate .summary.txt)")
    if snap_text:
        lines.append(f"- Content preview length: {len(snap_text)} chars")
    if snap_summary:
        lines.append(f"- Summary preview length: {len(snap_summary)} chars")
    lines.append("")
    lines.append("## Decisions (recent)")
    if isinstance(payload["decisions"], list):
        for d in payload["decisions"]:
            ts = d.get("ts")
            risk = d.get("risk")
            route = d.get("route_hint")
            preview = d.get("text_preview")
            lines.append(f"- ts={ts} risk={risk} route={route} :: {preview}")
    elif isinstance(payload["decisions"], dict):
        status = payload["decisions"].get("status")
        lines.append(f"- status={status} (decision_log.jsonl missing? run bridge with decision_summarizer)")
    else:
        lines.append(f"- {payload['decisions']}")
    lines.append("")
    lines.append("## Ops")
    for name, val in payload["ops"].items():
        if isinstance(val, list):
            lines.append(f"- {name}: {len(val)} entries (tail)")
        else:
            lines.append(f"- {name}: {val}")
    lines.append("")
    lines.append("## Rules")
    lines.append(f"- Status: {rule_info.get('status')}")
    if rule_info.get("hash"):
        lines.append(f"- RULE_TABLE hash: {rule_info['hash']}")
        lines.append(f"- Entries: {rule_info.get('count')}")
    return "\n".join(lines)

md_out = build_md()

out_json_path = os.environ.get("OUT_JSON", "")
out_md_path = os.environ.get("OUT_MD", "")
out_status_path = os.environ.get("OUT_STATUS", "")
out_dir = os.environ.get("OUT_DIR", "")

if mode == "dry-run":
    print("=== JSON (preview) ===")
    print(json_out)
    print("\n=== Markdown (preview) ===")
    print(md_out)
else:
    for path, content in ((out_json_path, json_out), (out_md_path, md_out)):
        if path:
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
    if out_status_path:
        has_decisions = isinstance(payload["decisions"], list) and len(payload["decisions"]) > 0
        has_snapshot = snapshot["status"] == "present"
        has_summary = snapshot["summary_status"] == "present"
        status_payload = {
            "ts": now,
            "ts_iso": meta["ts_iso"],
            "mode": mode,
            "git": meta["git"],
            "has_decisions": has_decisions,
            "decisions_status": payload["decisions"] if not has_decisions else "ok",
            "has_snapshot": has_snapshot,
            "has_snapshot_summary": has_summary,
            "rule_table": rule_info,
            "outputs": {
                "json": os.path.join(out_dir, "latest.json") if out_dir else "",
                "md": os.path.join(out_dir, "latest.md") if out_dir else "",
            },
        }
        with open(out_status_path, "w", encoding="utf-8") as f:
            json.dump(status_payload, f, ensure_ascii=False, indent=2)
    print(f"wrote_json={bool(out_json_path)} wrote_md={bool(out_md_path)} wrote_status={bool(out_status_path)}")
PY

if [[ "$MODE" == "run" ]]; then
  mv -f "$OUT_JSON_TMP" "$OUT_JSON"
  mv -f "$OUT_MD_TMP" "$OUT_MD"
  mv -f "$OUT_STATUS_TMP" "$OUT_STATUS"
  echo "✅ core_history_sync: wrote $OUT_JSON, $OUT_MD, and $OUT_STATUS"
else
  echo "✅ core_history_sync (dry-run): no files written"
fi
