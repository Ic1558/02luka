# Why One-Record Policy?

**Question:** ทำไมต้องเปลี่ยนจาก multi-append → single append at chain end?

---

## ปัญหาของ Multi-Append Approach

### ❌ Scenario 1: Partial Records

**Multi-Append:**
```jsonl
{"run_id": "run_123", "review_exit_code": 0, "gitdrop_snapshot_id": null, "gitdrop_status": null, "save_status": null}
{"run_id": "run_123", "review_exit_code": 0, "gitdrop_snapshot_id": "20251206_193005", "gitdrop_status": "ok", "save_status": null}
{"run_id": "run_123", "review_exit_code": 0, "gitdrop_snapshot_id": "20251206_193005", "gitdrop_status": "ok", "save_status": "ok"}
```

**ปัญหา:**
- 1 run = 3 records (duplicate data)
- ถ้า chain fail กลางคัน → มี partial records
- Query ซับซ้อน: ต้องหา record สุดท้ายของแต่ละ run_id
- ไม่รู้ว่า chain เสร็จหรือยัง (ต้อง check save_status != null)

### ❌ Scenario 2: Chain Failure

**Multi-Append เมื่อ GitDrop fail:**
```jsonl
{"run_id": "run_123", "review_exit_code": 0, "gitdrop_status": null, "save_status": null}  # After review
{"run_id": "run_123", "review_exit_code": 0, "gitdrop_status": "fail", "save_status": null}  # After gitdrop
# Save ไม่ได้ run → ไม่มี record ที่ 3
```

**ปัญหา:**
- ไม่รู้ว่า save_status = "skipped" หรือ "fail" หรือ chain ยังไม่เสร็จ
- ต้อง query หลาย records เพื่อดูสถานะ
- Partial state ทำให้ debugging ยาก

### ❌ Scenario 3: File Locking Complexity

**Multi-Append:**
```python
# Step 1: Review
with open("telemetry.jsonl", "a") as f:
    f.write(json.dumps(partial_record_1) + "\n")

# Step 2: GitDrop (อาจ run parallel หรือ separate process)
with open("telemetry.jsonl", "a") as f:
    f.write(json.dumps(partial_record_2) + "\n")  # อาจ conflict

# Step 3: Save
with open("telemetry.jsonl", "a") as f:
    f.write(json.dumps(partial_record_3) + "\n")
```

**ปัญหา:**
- ต้องใช้ file locking (flock) เพื่อป้องกัน race condition
- ถ้า chain run parallel → อาจ append ไม่เรียงลำดับ
- Implementation ซับซ้อนขึ้น

---

## ข้อดีของ One-Record Policy

### ✅ Scenario 1: Complete Records

**One-Record:**
```jsonl
{"run_id": "run_123", "review_exit_code": 0, "gitdrop_snapshot_id": "20251206_193005", "gitdrop_status": "ok", "save_status": "ok", "duration_ms_total": 1250}
```

**ข้อดี:**
- 1 run = 1 record (no duplication)
- Complete state ใน record เดียว
- Query ง่าย: `grep run_123 telemetry.jsonl` → ได้ 1 record
- รู้ทันทีว่า chain เสร็จหรือยัง (มี save_status)

### ✅ Scenario 2: Terminal Records on Failure

**One-Record เมื่อ GitDrop fail:**
```jsonl
{"run_id": "run_123", "review_exit_code": 0, "gitdrop_status": "fail", "save_status": "skipped", "errors": "GitDrop failed: ...", "duration_ms_total": 800}
```

**ข้อดี:**
- Terminal record บอกสถานะชัดเจน
- `save_status: "skipped"` บอกว่าไม่ได้ run
- `errors` field บอกสาเหตุ
- ไม่มี partial state

### ✅ Scenario 3: Simple Implementation

**One-Record:**
```python
# Collect data in memory
record = {
    "run_id": run_id,
    "review_exit_code": review_exit_code,
    # ... collect all fields during chain
}

# Append once at end
with open("telemetry.jsonl", "a") as f:
    f.write(json.dumps(record) + "\n")
```

**ข้อดี:**
- No file locking needed (single append)
- No race conditions (atomic write)
- Simple code (collect → append)
- Easy to test

---

## Comparison Table

| Aspect | Multi-Append | One-Record Policy |
|--------|--------------|------------------|
| **Records per run** | 3 records | 1 record |
| **Data duplication** | Yes (run_id, ts, etc.) | No |
| **Partial records** | Yes (if chain fails) | No (terminal record) |
| **Query complexity** | High (join records) | Low (grep-friendly) |
| **File locking** | Required | Not needed |
| **Implementation** | Complex | Simple |
| **Atomicity** | No (3 writes) | Yes (1 write) |
| **State clarity** | Unclear (check last record) | Clear (1 record) |

---

## Real-World Example

### Query: "Find all failed chains in last 24 hours"

**Multi-Append:**
```bash
# ต้อง query หลาย records, join, filter
grep "save_status.*fail" telemetry.jsonl | \
  awk '{print $1}' | \
  xargs -I {} grep "run_id.*{}" telemetry.jsonl | \
  tail -1
```

**One-Record:**
```bash
# Query ง่าย: 1 record = complete state
grep "save_status.*fail" telemetry.jsonl
```

---

## Edge Cases

### 1. Chain Hard-Fail (Process killed)

**Multi-Append:**
- อาจมี partial record (review done, gitdrop not done)
- ไม่รู้ว่า chain fail หรือยัง run อยู่

**One-Record:**
- Append terminal record with last-known state
- `errors: "Process killed"`, `save_status: "skipped"`

### 2. Config Error (Before Chain Starts)

**Multi-Append:**
- ไม่มี record (chain ไม่ได้ start)
- หรือมี partial record ที่ไม่สมบูรณ์

**One-Record:**
- Log minimal error record หรือ nothing
- Clear: config error = before chain

### 3. Security Block (Exit Code 3)

**Multi-Append:**
- Review record: `security_blocked: true`
- GitDrop/Save records: `skipped`
- 3 records สำหรับ 1 decision

**One-Record:**
- 1 record: `security_blocked: true`, `gitdrop_status: "skipped"`, `save_status: "skipped"`
- Clear decision point

---

## Conclusion

**One-Record Policy เหมาะกับ Unified Chain เพราะ:**

1. ✅ **Simplicity**: Implementation ง่าย (collect → append)
2. ✅ **Clarity**: 1 record = complete state
3. ✅ **Reliability**: No file locking, atomic write
4. ✅ **Queryability**: Grep-friendly, no joins needed
5. ✅ **Edge Cases**: Terminal records handle failures clearly

**Trade-off:**
- ต้องเก็บข้อมูลใน memory ระหว่าง chain (แต่ chain สั้น ~1-2 วินาที → ไม่เป็นปัญหา)

---

## Implementation Pattern

```python
# Chain Start
record = {
    "ts": datetime.now(timezone.utc).isoformat(),
    "run_id": generate_run_id(),
    "caller": determine_caller(),
    # ... initialize all fields
}
chain_start = time.monotonic()

# During Chain (collect data)
record["review_exit_code"] = run_review()
record["duration_ms_review"] = calculate_duration()

if record["review_exit_code"] in [0, 1]:
    record["gitdrop_snapshot_id"] = run_gitdrop()
    record["duration_ms_gitdrop"] = calculate_duration()
    
    if record["gitdrop_status"] == "ok":
        record["save_status"] = run_save()
        record["duration_ms_save"] = calculate_duration()

# Chain End (append once)
record["duration_ms_total"] = (time.monotonic() - chain_start) * 1000
append_jsonl(record)
```

**Simple, clear, reliable.** ✅
