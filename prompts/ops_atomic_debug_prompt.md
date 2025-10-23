# Prompt: Debug & Fix OPS Monitoring / ops-atomic Failure

```
✅ Prompt to CLC / Codex — Debug & Fix OPS Monitoring / ops-atomic Failure

Context
    •  GitHub Actions workflow: OPS Monitoring
    •  Job ops-atomic: ❌ Failed (~1m 20s)
    •  Job notify-discord: ✅ Succeeded
    •  อาการ “แก้ไม่หาย” ต้องการหาสาเหตุเชิงระบบ + ออกแพตช์ให้เสถียร

Objectives
    1.  ระบุสาเหตุการล้มของ ops-atomic จากล็อกจริง (ไม่เดา)
    2.  ออกแพตช์ workflow/สคริปต์เพื่อแก้ให้ ผ่านเสถียร
    3.  เพิ่มการสังเกตการณ์/รีเทรัย (observability & retries) เพื่อกันล้มซ้ำ
    4.  ส่ง PR พร้อมผลทดสอบรันจริง

Tasks (ทำตามลำดับ)

1) ดึงข้อมูลรันที่ล้ม + เปิดโหมดดีบัก
    •  ระบุ repo+run ล่าสุด แล้วดึงล็อกละเอียดทุกสเต็ป

# ตั้งค่าให้ Actions พ่นดีบักละเอียดรอบถัดไป
gh secret set ACTIONS_STEP_DEBUG -b true
gh secret set ACTIONS_RUNNER_DEBUG -b true

# ดูรายการ run ล่าสุดของ workflow "OPS Monitoring"
gh run list --workflow "OPS Monitoring" --limit 5

# เจาะไปที่ run ล่าสุด: แทน <RUN_ID> ให้ถูก
gh run view <RUN_ID> --log
gh run download <RUN_ID> --dir ./ops-logs

# ดูเฉพาะ job ที่ล้ม
gh run view <RUN_ID> --job "ops-atomic" --log

ส่งออกผล: แนบ ./ops-logs/** และสรุป “สเต็ปไหน/เอ็กซิตโค้ดอะไร/สแต็กเทรซ” เป็น Markdown

2) วิเคราะห์สาเหตุ (ให้สรุป root cause ชัด ๆ)

ตรวจ 8 จุดนี้ก่อน (ติ๊กถูก/ผิดพร้อมหลักฐานจากล็อก):
    •  missing secrets / GITHUB_TOKEN / permission contents: read
    •  checkout ชน branch / sha ไม่เจอ
    •  uses: action เวอร์ชันเก่า / rate limit / 403
    •  node/python เวอร์ชันไม่ตรงกับสคริปต์ (เช่น node 18 vs 20)
    •  ขาด dependency (npm/pip install fail)
    •  สคริปต์ระบุ path ผิด / ไฟล์ไม่พบ
    •  timeout step (default 60–90s)
    •  matrix/conditional if: ทำให้ข้าม step ที่จำเป็น

3) ออกแพตช์ (ปรับ .github/workflows/ops.yml และ/หรือสคริปต์)

นำเสนอ diff ที่แก้ อย่างน้อย 5 ข้อด้านล่าง (เลือกที่ตรง root cause):

(ก) เพิ่มเสถียรภาพ & รีเทรัย

jobs:
  ops-atomic:
    timeout-minutes: 10
    strategy:
      fail-fast: false
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with: { fetch-depth: 1 }

      - name: Setup Node
        uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }

      - name: Install deps (retry)
        run: |
          npm ci || (sleep 3 && npm ci) || (sleep 5 && npm ci)

(ข) เปิดดีบักตามต้องการ (ควบคุมด้วย input)

env:
  DEBUG: ${{ inputs.debug || '0' }}
  ACTIONS_STEP_DEBUG: ${{ env.DEBUG }}

(ค) สิทธิ์โทเคนขั้นต่ำที่ต้องมี

permissions:
  contents: read
  actions: read
  pull-requests: write    # ถ้าสร้างคอมเมนต์/PR

(ง) จัดการ timeout ของ step เสี่ยง

- name: Run ops script
  run: node scripts/ops-atomic.cjs
  timeout-minutes: 5

(จ) noti-discord ให้ยิงเสมอ

notify-discord:
  if: ${{ always() }}
  needs: [ops-atomic]
  steps:
    - name: Summarize failure/success
      run: node scripts/summarize.cjs > summary.md

ถ้ารากปัญหาเกี่ยวกับ secret/name: ให้เพิ่ม env: ที่อ่านจาก secrets.* และตรวจว่าคีย์ตรงกับที่ใช้ในสคริปต์

4) เพิ่ม Observability (ให้แกะง่ายในครั้งต่อไป)
    •  พ่นบล็อกสรุปท้ายจ็อบด้วย ::group:: / ::notice::
    •  เก็บ artifact หลักฐาน:

- name: Upload artifacts
  if: ${{ failure() || always() }}
  uses: actions/upload-artifact@v4
  with:
    name: ops-atomic-logs
    path: |
      logs/**
      summary.md

5) ทดสอบ & รายงานผล
    •  รันซ้ำพร้อมดีบัก:

gh run rerun <RUN_ID> --debug

    •  แนบ:
    •  ลิงก์รันใหม่ + สเตตัสทุก job
    •  diff ของไฟล์ workflow/shell/scripts
    •  ภาพรวมเวลารัน: ก่อน (~1m20s ล้ม) → หลัง (ผ่าน, ระยะเวลา)
    •  ข้อเสนอ “guardrails” เพิ่มเติมถ้ายังเห็นจุดเสี่ยง

Deliverables
    1.  Root-cause report (Markdown) อ้างอิง line/log ที่ชัดเจน
    2.  Patch (diff/PR) ที่แก้ให้ผ่านเสถียร + เปิดสังเกตการณ์
    3.  ลิงก์รันที่ “ผ่าน” พร้อม artifacts & summary
    4.  Checklist การป้องกันซ้ำ (secrets, versions, timeouts, retries)

Acceptance Criteria
    •  ops-atomic ✅ ผ่านอย่างน้อย 2 ครั้งติดต่อกัน (rerun/manual)
    •  notify-discord ✅ ยิงสรุปถูกต้องทั้ง pass/fail
    •  ไม่มี error เดิมซ้ำใน 3 รันล่าสุด
    •  เวลารันรวมไม่เกิน 5 นาที (เว้นงานหนักจริง ๆ)

Quick hypotheses (ถ้าต้องเดาก่อนเห็นล็อก)
    •  หายบ่อย: missing secret / permission หรือ Node version mismatch
    •  ล้มเร็ว ~1m20s: มักเกิดจาก “สคริปต์ exit 1 ทันที” (ไฟล์ไม่พบ/path ผิด) หรือ “install fail & ไม่มี retry”
```
