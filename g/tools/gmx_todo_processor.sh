#!/usr/bin/env zsh
set -euo pipefail

BASE_DIR="/Users/icmini/02luka"
TODO_FILE="$BASE_DIR/gmx_todo.txt"
LOG_DIR="$BASE_DIR/logs"
LOCK_DIR="$BASE_DIR/locks"
GMX_CLI="$BASE_DIR/g/tools/gmx_cli.py"

mkdir -p "$LOG_DIR" "$LOCK_DIR"

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log() {
  echo "[$(timestamp)] $*" >> "$LOG_DIR/gmx_todo_processor.log"
}

# 🔒 กันรันซ้อน
LOCK_FILE="$LOCK_DIR/gmx_todo.lock"
exec 9>"$LOCK_FILE" || exit 1
if ! flock -n 9; then
  log "Another gmx_todo_processor instance is running. Exiting."
  exit 0
fi

if [[ ! -f "$TODO_FILE" ]]; then
  log "TODO file not found: $TODO_FILE (nothing to do)"
  exit 0
fi

# 🧩 ย้ายไฟล์ TODO ของรอบนี้ไปเป็น temp แบบ atomic
TMP_FILE="$TODO_FILE.processing.$$"

# ถ้าระหว่างนี้มีคนเขียนเพิ่ม จะถูกเขียนลง TODO_FILE ตัวใหม่ ไม่ใช่ TMP_FILE
mv "$TODO_FILE" "$TMP_FILE" 2>/dev/null || {
  # ถ้าย้ายไม่ได้ (เช่นไฟล์หาย) ก็ถือว่าไม่มีอะไรทำ
  log "No tasks to process (mv failed or file empty)."
  exit 0
}

# สร้าง TODO_FILE ใหม่ให้คนอื่นเขียนได้ทันที
: > "$TODO_FILE"

log "Processing GMX tasks from $TMP_FILE"

# อ่านไฟล์รอบนี้ทีละบรรทัด
while IFS= read -r line || [[ -n "$line" ]]; do
  task="${line//[$'\r\n']/}"

  # ข้ามว่าง + คอมเมนต์
  if [[ -z "$task" ]] || [[ "$task" == \#* ]]; then
    continue
  fi

  log "GMX task: $task"

  # Explicitly source the user's profile to get the full environment, then use venv python
  if ! { source ~/.zshrc; "$BASE_DIR"/.venv/bin/python3 "$GMX_CLI" "$task"; } >> "$LOG_DIR/gmx_cli.run.log" 2>&1; then
    log "ERROR: gmx_cli failed for task: $task"
    # NOTE: ถ้าอยากเก็บ task ที่ fail ไว้ retry เพิ่ม logic append กลับลง TODO_FILE ตรงนี้ได้
  else
    log "SUCCESS: gmx_cli finished for task: $task"
  fi
done < "$TMP_FILE"

rm -f "$TMP_FILE"
log "Finished processing GMX tasks from $TMP_FILE"
