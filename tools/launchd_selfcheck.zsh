#!/usr/bin/env zsh
set -euo pipefail

# Config
: "${LABEL_PREFIX:=com.02luka.}"      # กรองเฉพาะเอเจนต์ของ 02luka
: "${OUT:=hub/selfcheck_report.json}" # ไฟล์รายงาน JSON
: "${ALLOW_EMPTY:=1}"                 # 1 = ไม่ล้มเหลวถ้าไม่พบเอเจนต์
: "${SELF_HEAL:=0}"                   # 1 = ลอง load เอเจนต์ที่หลุด

mkdir -p "$(dirname "$OUT")"

_now() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }

# ดึงรายการเอเจนต์
# ใช้ while loop แทน mapfile เพื่อความเข้ากันได้กับ Zsh
ALL=()
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue
  ALL+=("$line")
done < <(launchctl list | awk 'NR>1{print $1"\t"$2"\t"$3}')

labels=()
for line in "${ALL[@]}"; do
  label="${line##*$'\t'}"
  [[ "$label" == ${LABEL_PREFIX}* ]] && labels+=("$line")
done

if [[ ${#labels[@]} -eq 0 && "$ALLOW_EMPTY" = "0" ]]; then
  echo "No LaunchAgents found with prefix '${LABEL_PREFIX}'" >&2
  exit 2
fi

# เก็บผลพร้อม self-heal (ถ้าเปิด)
tmp="$(mktemp)"
> "$tmp"
for rec in "${labels[@]}"; do
  pid="$(echo "$rec" | awk -F'\t' '{print $1}')"
  last="$(echo "$rec" | awk -F'\t' '{print $2}')"
  label="$(echo "$rec" | awk -F'\t' '{print $3}')"

  ok="true"
  reason=()

  if [[ "$pid" = "-" ]]; then
    ok="false"
    reason+=("not-running")
    if [[ "$SELF_HEAL" = "1" ]]; then
      # พยายาม load อีกครั้ง (GUI session ของผู้ใช้ปัจจุบัน)
      launchctl bootstrap gui/"$(id -u)" "$HOME/Library/LaunchAgents/${label}.plist" 2>/dev/null || true
      sleep 0.3
      # ตรวจซ้ำ
      if launchctl list | awk 'NR>1{print $3}' | grep -q "^${label}$"; then
        ok="true"; reason=()
      else
        reason+=("self-heal-failed")
      fi
    fi
  fi

  printf "%s\t%s\t%s\t%s\n" "$label" "${pid}" "${last}" "${(j:,:)"${reason[@]:-}"}" >> "$tmp"
done

# สร้าง JSON (ใช้ Python เพื่อความปลอดภัยในการ escape)
python3 - <<PY > "$OUT"
import json, os, sys
rows=[]
for line in open("${tmp}", "r"):
    label, pid, last, reason_csv = line.rstrip("\n").split("\t")
    reasons = [r for r in reason_csv.split(",") if r] if reason_csv else []
    ok = (pid != "-")
    rows.append({
        "label": label,
        "ok": ok,
        "pid": None if pid=="-" else int(pid),
        "last_exit_status": None if last=="-" else int(last),
        "reasons": reasons
    })

doc = {
    "_meta": {
        "created_by": "GG_Agent_02luka",
        "created_at": "${_now()}",
        "source": "tools/launchd_selfcheck.zsh",
        "prefix": os.environ.get("LABEL_PREFIX","com.02luka."),
        "total": len(rows),
        "healthy": sum(1 for r in rows if r["ok"])
    },
    "items": rows
}
json.dump(doc, sys.stdout, indent=2, ensure_ascii=False)
PY

rm -f "$tmp"
echo "✅ wrote $OUT"
