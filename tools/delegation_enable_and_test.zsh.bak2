#!/usr/bin/env zsh
set -euo pipefail

# Redis URL ควรตั้งใน ENV/Secrets ถ้าไม่มีจะ fail แบบชัดเจน
: ${LUKA_REDIS_URL:?"Missing LUKA_REDIS_URL (e.g. redis://:pass@127.0.0.1:6379)"}

echo "== Enable delegation routing =="
# 1) ลงทะเบียนสถานะ orchestrator (บอกว่ารับงานแบบ delegate แล้ว)
mkdir -p "$HOME/02luka/g/state"
print -r -- '{"delegation_mode":"enabled","ts":"'"$(date -u +%FT%TZ)"'"}' \
  > "$HOME/02luka/g/state/gg_delegation.json"

echo "== Send a real task GG→Mary→Lisa =="
# 2) สร้าง task ที่ชัดเจน: ให้ Lisa ทำไฟล์ PDF test
task_id="wo-$(date +%Y%m%d%H%M%S)"
payload=$(jq -n --arg id "$task_id" '
{
  wo_id: $id,
  target: "Lisa",
  action: "generate_document",
  params: {
    template: "hello_world",
    out_path: "g/outbox/hello_world.pdf",
    data: { title: "Hello from GG→Mary→Lisa", note: "real delegation test" }
  },
  meta: { producer: "gg", via: "mary", ts: now|todate }
}')

echo "$payload" | redis-cli -u "$LUKA_REDIS_URL" PUBLISH "mary:requests" >/dev/null

echo "== Done. Monitor channels =="
echo "  - mary:events"
echo "  - lisa:events"
echo "  - check: ~/02luka/g/outbox/hello_world.pdf (when done)"

