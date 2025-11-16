# Docker → Native Migration (02LUKA)

**สรุปสั้น:** วันนี้ 02LUKA รันแบบ Native บน macOS (Homebrew + LaunchAgents) ทั้งหมดแล้ว
Docker ถูกเก็บไว้ใช้เฉพาะกรณีจำเป็น (Linux-only deps / sandbox เข้ม / ทีมงานหลายเครื่อง / heavy DBs)

## ทำไมอดีตต้องใช้ Docker
- macOS sandbox/permission ทำให้ process ไม่มี Full Disk Access อ่าน/เขียน `/Volumes/lukadata` ไม่ได้
- ต้อง mount external SSD เข้าคอนเทนเนอร์เพื่อให้บริการ (Redis/Python/Node) ใช้ข้อมูลร่วมกัน
- แยก environment กัน (หลบ version/dep ชน)

## วันนี้ทำไมไม่ต้องใช้ Docker
- ย้าย working dir มาอยู่ใน `~/02luka` (home) → ไม่มี permission issue
- Redis ใช้ Homebrew (127.0.0.1:6379), services ถูกดูแลด้วย LaunchAgents
- เร็ว/เบากว่า ไม่มี virtualization overhead

## สถาปัตยกรรมปัจจุบัน (Native)
- **Working dir:** `~/02luka/g/`
- **Backups/Archives:** `/Volumes/lukadata/…`
- **Core services:** Redis (Homebrew), Dashboard API (Python), Cloudflared tunnels
- **MCP:** ค่าตั้งต้นรันแบบ Native (แยก LaunchAgent ต่อเซิร์ฟเวอร์)

## กลยุทธ์ MCP (Native เป็นค่าเริ่ม)
- ใช้ **uvx/pipx** (Python) หรือ **npm/npx** (Node) ติดตั้งรายเซิร์ฟเวอร์
- โครงสร้าง:
  ```
  ~/02luka/mcp/
    servers/<name>/
    config/<name>.json
    logs/<name>.log
  ```
- LaunchAgent (ย่อ):
  - `KeepAlive: true`, `RunAtLoad: true`
  - `ProgramArguments: /bin/zsh -lc "<run mcp> --config $HOME/02luka/mcp/config/<name>.json"`
  - Stdout/Stderr → `~/02luka/mcp/logs/*.log`

### เมื่อใดจึงเลือก Docker
- ต้องพึ่ง **Linux-only** หรือ native binary เฉพาะลินุกซ์
- **Dependency conflict** หลายเวอร์ชันรุนแรง
- ต้องการ **sandbox/เน็ตเวิร์กจำกัด** เข้ม หรือ **ทีม/CI** reproducible
- ต้องพ่วง heavy service (e.g., Postgres/Qdrant/Elasticsearch)

## ข้อสรุป
- โหมดปัจจุบัน: **Local-first, Native-first**
- เก็บ Docker ไว้เป็น **fallback เฉพาะรายกรณี**
- เอกสารนี้คือ SOT อธิบาย "ทำไม ณ วันนี้เราไม่เห็น container รันใน Docker.app" และวิธีตัดสินใจต่อไป
