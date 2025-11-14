# Claude Code Slash Commands - คู่มือการใช้งานจริง

**สถานะ**: ✅ Production Ready (Phase 1.5)
**ที่อยู่ไฟล์**: `~/.claude/commands/`
**อัพเดทล่าสุด**: 2025-11-12

---

## 🎯 ภาพรวม (Overview)

Slash commands คือ **คำสั่งพิเศษที่สั่งให้ Claude Code ทำงานแบบเฉพาะเจาะจง** แทนที่จะพิมพ์คำสั่งยาวๆ ทุกครั้ง

### Commands ที่มี (3 ตัว)
1. **/feature-dev** - สำหรับสร้าง feature ใหม่ (แบบ plan-first)
2. **/code-review** - สำหรับ review code (ใช้ subagents)
3. **/deploy** - สำหรับ deploy ระบบ (แบบ checklist-driven)

---

## 1️⃣ `/feature-dev` - พัฒนา Feature ใหม่

### วัตถุประสงค์
สร้าง feature ใหม่โดยใช้แนวทาง **plan-first** (วางแผนก่อน ไม่เขียนโค้ดทันที)

### ทำงานอย่างไร
```markdown
# /feature-dev (plan-first)
- Ask clarifying Qs → produce **SPEC.md**
- Break down tasks → TODO list
- Propose test strategy
- Output: `g/reports/feature_[slug]_PLAN.md`
```

### เมื่อไหร่ควรใช้ 🤔

**✅ ใช้เมื่อ:**
- ต้องการสร้าง feature ใหม่ที่ซับซ้อน (ไม่ใช่แก้ bug เล็กๆ)
- ต้องการให้ Claude ถามคำถามชี้แจงก่อนเริ่มงาน
- ต้องการแผนการพัฒนาที่ชัดเจน (ไม่ใช่เริ่มเขียนทันที)
- ต้องการ TODO list เพื่อ track progress
- ไม่แน่ใจว่าควรเริ่มต้นอย่างไร

**❌ ไม่ต้องใช้เมื่อ:**
- แก้ bug เล็กๆ (เช่น typo, syntax error)
- เปลี่ยนแปลงเล็กน้อย (เช่น เปลี่ยนข้อความ)
- รู้แน่นอนว่าจะทำอะไร และทำได้ง่าย

### ตัวอย่างการใช้งานจริง

#### ตัวอย่าง 1: สร้าง API endpoint ใหม่
```
User: /feature-dev
       เพิ่ม API endpoint สำหรับ export ข้อมูล MLS เป็น CSV

Claude: ขอถามชี้แจงก่อนครับ:
        1. ข้อมูล MLS ทั้งหมด หรือกรองตามวันที่?
        2. รูปแบบ CSV ต้องการ column อะไรบ้าง?
        3. จำกัดขนาดไฟล์ไหม (เช่น max 10MB)?
        4. Authentication ใช้วิธีเดียวกับ API อื่นๆ?

User: ตามวันที่, column ทั้งหมด, ไม่จำกัดขนาด, ใช่ auth เดียวกัน

Claude: เข้าใจแล้วครับ กำลังสร้างแผน...

        📋 SPEC.md

        ## Feature: MLS Export to CSV API

        ### Requirements
        - Endpoint: GET /api/mls/export
        - Query params: ?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
        - Auth: Existing JWT middleware
        - Output: CSV file download

        ### TODO List
        1. [ ] Create route in routes/mls.js
        2. [ ] Implement CSV converter (use fast-csv)
        3. [ ] Add date range validation
        4. [ ] Write tests (happy path + edge cases)
        5. [ ] Update API documentation

        ### Test Strategy
        - Unit test: CSV formatting with sample data
        - Integration test: Full endpoint with auth
        - Load test: Export 10K records

        แผนนี้เห็นด้วยไหมครับ?
```

#### ตัวอย่าง 2: Refactor ระบบเก่า
```
User: /feature-dev
       Refactor Kim agent ให้ support multiple profiles

Claude: ถามก่อนนะครับ:
        1. จำนวน profiles สูงสุดเท่าไหร่? (unlimited หรือมีข้อจำกัด)
        2. เปลี่ยน profile แบบ per-user หรือ global?
        3. Profile เก็บอะไรบ้าง? (model, temperature, prompt?)
        4. Backward compatible กับ single profile เดิมไหม?

User: unlimited, per-user, เก็บ model+temp+prompt, ต้อง backward compatible

Claude: 📋 g/reports/feature_kim_multiprofile_PLAN.md

        ## Refactor: Kim Multi-Profile Support

        ### Architecture Changes
        - ProfileStore (new): Per-user profile management
        - ProfileLoader (new): Load & validate profiles
        - Kim Agent (modify): Accept profile parameter

        ### TODO List
        1. [ ] Create profile_store.py (user → profile mapping)
        2. [ ] Create profile schema validation
        3. [ ] Modify kim_agent.py to accept profile
        4. [ ] Add default profile fallback (backward compat)
        5. [ ] Migrate existing config to default profile
        6. [ ] Write migration guide
        7. [ ] Test with old & new clients

        ### Migration Strategy
        - Existing users: Auto-migrate to "default" profile
        - New users: Prompt to create profile
        - Zero downtime: Deploy ProfileStore first, then agent

        เห็นด้วยไหมครับ?
```

### Output ที่ได้
- **SPEC.md** หรือ **g/reports/feature_[name]_PLAN.md** - แผนการพัฒนาแบบละเอียด
- **TODO list** - รายการงานที่ต้องทำ พร้อม checkbox
- **Test strategy** - วิธีการทดสอบที่แนะนำ

### Tips & Best Practices 💡

1. **ตอบคำถามของ Claude ให้ละเอียด** - ยิ่งละเอียด แผนยิ่งแม่นยำ
2. **Review แผนก่อนเริ่มงาน** - อย่าเพิ่งบอกให้เริ่มเขียนโค้ดทันที
3. **ใช้ TODO list track progress** - ทำเสร็จทีละอัน
4. **เก็บ PLAN.md ไว้ใน g/reports/** - เพื่ออ้างอิงภายหลัง

---

## 2️⃣ `/code-review` - Review โค้ด

### วัตถุประสงค์
Review โค้ดโดยใช้ **subagents** (agents หลายตัวทำงานร่วมกัน) เพื่อตรวจหาปัญหาจากหลายมุมมอง

### ทำงานอย่างไร
```markdown
# /code-review (subagents allowed)
- Style check, history-aware review, obvious-bug scan
- Summarize risks + diff hotspots
- One final verdict line: ✅/⚠️ with reasons
```

### เมื่อไหร่ควรใช้ 🤔

**✅ ใช้เมื่อ:**
- มี Pull Request ที่ต้อง review ก่อน merge
- แก้โค้ดเสร็จแล้ว ต้องการ second opinion
- โค้ดมีความซับซ้อนสูง ต้องการ review หลายมุมมอง
- ต้องการตรวจหา security issues หรือ performance problems
- ก่อน deploy production (double-check)

**❌ ไม่ต้องใช้เมื่อ:**
- แก้แค่ comment หรือ documentation
- เปลี่ยนแปลงเล็กมาก (1-2 บรรทัด)
- ต้องการ quick feedback (subagents ช้ากว่า single agent)

### ตัวอย่างการใช้งานจริง

#### ตัวอย่าง 1: Review PR ก่อน Merge
```
User: /code-review
       Review PR #123 ที่เพิ่ม caching layer ใหม่

Claude: กำลัง spawn 3 review agents...

        📊 Review Results

        **Agent A (Security):**
        - ✅ No SQL injection risks
        - ⚠️ Cache keys ไม่มี expiration → memory leak risk
        - ⚠️ Redis password ใน plaintext (ควรใช้ env var)

        **Agent B (Performance):**
        - ✅ Cache hit rate ดี (90%+)
        - ⚠️ Cache invalidation ใช้ brute-force → O(n)
        - ✅ Connection pooling implemented correctly

        **Agent C (Maintainability):**
        - ✅ Code well-structured
        - ⚠️ No tests for cache invalidation logic
        - ⚠️ Magic numbers (TTL=3600) should be config

        🎯 Final Verdict: ⚠️ **NEEDS FIXES**

        **Must Fix (blocking):**
        1. Add cache key expiration (TTL)
        2. Move Redis password to environment variable
        3. Add tests for invalidation

        **Nice to Have:**
        1. Optimize cache invalidation to O(log n)
        2. Make TTL configurable

        แก้ 3 ข้อแรกแล้ว approve ได้ครับ
```

#### ตัวอย่าง 2: Review ก่อน Deploy
```
User: /code-review
       Review deployment script WO-251113-DEPLOY-KIM.zsh

Claude: Spawning specialized agents...

        **Agent A (Safety):**
        - ✅ Has backup step
        - ⚠️ No rollback script generated
        - ❌ Missing health check after deploy

        **Agent B (Correctness):**
        - ✅ All file paths validated
        - ✅ Permissions set correctly
        - ⚠️ LaunchAgent reload not verified

        **Agent C (Production Ready):**
        - ✅ Logs to proper location
        - ⚠️ No notification on failure
        - ❌ No smoke test before declaring success

        🎯 Final Verdict: ❌ **NOT PRODUCTION READY**

        **Critical Issues:**
        1. Missing health check validation
        2. No rollback procedure
        3. No smoke test

        ต้องแก้ทั้ง 3 ข้อก่อน deploy production!
```

### Output ที่ได้
- **Multi-agent analysis** - มุมมองจากหลาย agents (security, performance, maintainability)
- **Risk summary** - ปัญหาที่พบ จัดเรียงตามความสำคัญ
- **Diff hotspots** - บรรทัดที่มีความเสี่ยงสูง
- **Final verdict** - ✅ (approve) หรือ ⚠️ (needs fixes) พร้อมเหตุผล

### Tips & Best Practices 💡

1. **ใช้กับ PR ที่ซับซ้อน** - Simple PR ไม่ต้องใช้ subagents
2. **Review ก่อน merge** - Catch issues ก่อนเข้า main branch
3. **Fix must-have issues ก่อน** - อย่าข้าม blocking issues
4. **เก็บ review results** - เพื่อ learn patterns ของปัญหาที่เจอบ่อย

---

## 3️⃣ `/deploy` - Deploy ระบบ

### วัตถุประสงค์
Deploy ระบบแบบ **checklist-driven** (ทำตาม checklist ทุกขั้นตอน) เพื่อความปลอดภัย

### ทำงานอย่างไร
```markdown
# /deploy (checklist driven)
- Backup current state
- Apply change
- Run health
- Generate rollback script
- Attach logs + artifact refs
```

### เมื่อไหร่ควรใช้ 🤔

**✅ ใช้เมื่อ:**
- Deploy ระบบไปยัง production
- Deploy configuration changes ที่สำคัญ
- Update critical services (database, cache, etc.)
- ต้องการ rollback plan ก่อน deploy
- Deploy ครั้งแรก (ไม่เคยทำมาก่อน)

**❌ ไม่ต้องใช้เมื่อ:**
- Deploy ไปยัง development environment
- Update documentation เท่านั้น
- Rollback (ใช้ rollback script ที่ generate ไว้แล้ว)

### ตัวอย่างการใช้งานจริง

#### ตัวอย่าง 1: Deploy Feature ใหม่
```
User: /deploy
       Deploy MLS export API to production

Claude: เข้าใจครับ เริ่ม deployment checklist...

        📋 Deployment Checklist: MLS Export API

        ## Pre-Deployment
        - [x] Backup current state
          → Backed up: routes/mls.js.BAK.20251112_004500
        - [x] Generate rollback script
          → Created: rollback_mls_export_20251112.zsh
        - [x] Verify tests passing
          → All 15 tests ✅

        ## Deployment
        - [x] Stop service gracefully
          → launchctl unload com.02luka.api
        - [x] Apply changes
          → Copied new routes/mls.js
          → Updated package.json dependencies
        - [x] Restart service
          → launchctl load com.02luka.api

        ## Post-Deployment
        - [x] Health check
          → API responding: ✅
          → Redis connection: ✅
          → Database connection: ✅
        - [x] Smoke test
          → GET /api/mls/export?start_date=2025-11-01 → 200 ✅
          → File size: 127KB (2,847 records)
        - [x] Monitor logs
          → No errors in first 2 minutes ✅

        ✅ Deployment Complete!

        📊 Summary
        - Deployed: routes/mls.js (MLS Export API)
        - Downtime: 8 seconds
        - Rollback available: rollback_mls_export_20251112.zsh
        - Health: All checks passed
        - Logs: ~/02luka/logs/api.log

        ต้องการให้ monitor อะไรเพิ่มไหมครับ?
```

#### ตัวอย่าง 2: Deploy Configuration Change
```
User: /deploy
       Update Redis maxmemory to 2GB

Claude: กำลังเตรียม deployment...

        ⚠️ Configuration Change Detected

        ระบบนี้เป็น **production critical**
        ขอยืนยันครั้งสุดท้าย:

        - Service: Redis
        - Parameter: maxmemory
        - Old value: 1GB
        - New value: 2GB
        - Impact: Redis restart required (< 5s downtime)
        - Dependent services: API, Kim Agent, Cache

        พิมพ์ "confirm" เพื่อดำเนินการ

User: confirm

Claude: Proceeding with deployment...

        📋 Deployment Steps

        1. [x] Backup current redis.conf
           → ~/02luka/config/redis.conf.BAK.20251112_004800

        2. [x] Generate rollback script
           → Created: rollback_redis_maxmem_20251112.zsh
           → Contains: Update maxmemory to 1GB + restart

        3. [x] Update configuration
           → Changed maxmemory 1gb → maxmemory 2gb

        4. [x] Validate config syntax
           → redis-server --test-config → OK ✅

        5. [x] Restart Redis
           → brew services restart redis → Done (3.2s)

        6. [x] Health check
           → PING → PONG ✅
           → GET test_key → OK ✅
           → INFO memory → maxmemory: 2147483648 (2GB) ✅

        7. [x] Check dependent services
           → API: responding ✅
           → Kim Agent: connected ✅
           → Cache hit rate: 94% ✅

        ✅ Configuration Updated Successfully!

        📊 Monitoring
        - Memory usage: 487MB / 2GB (24%)
        - Eviction policy: allkeys-lru
        - Connected clients: 3
        - Rollback available: rollback_redis_maxmem_20251112.zsh

        แนะนำ monitor memory usage ใน 24 ชั่วโมงแรก
```

### Output ที่ได้
- **Backup files** - ไฟล์ backup พร้อม timestamp
- **Rollback script** - สคริปต์สำหรับ undo deployment
- **Health check results** - ผลการตรวจสุขภาพระบบ
- **Deployment logs** - บันทึกทุกขั้นตอน
- **Smoke test results** - ทดสอบ basic functionality

### Tips & Best Practices 💡

1. **อ่าน checklist ทั้งหมดก่อน confirm** - เข้าใจทุกขั้นตอน
2. **เก็บ rollback script ไว้** - เผื่อต้องใช้ภายใน 24 ชม.
3. **Monitor หลัง deploy** - อย่างน้อย 30 นาทีแรก
4. **Test rollback script** - ทดสอบใน dev ก่อนถ้าทำได้
5. **Deploy ช่วงที่ traffic ต่ำ** - ลด impact ถ้ามีปัญหา

---

## 🎯 Decision Tree: ควรใช้ Command ไหน?

```
START
  ↓
  ต้องการทำอะไร?
  ├─ สร้าง feature ใหม่
  │   ├─ ซับซ้อน หรือไม่แน่ใจจะเริ่มยังไง?
  │   │   → ใช้ /feature-dev ✅
  │   └─ เรียบง่าย รู้แน่นอนว่าจะทำอะไร?
  │       → ไม่ต้องใช้ slash command (พิมพ์ธรรมดา)
  │
  ├─ Review โค้ด
  │   ├─ PR ใหญ่ หรือซับซ้อน?
  │   │   → ใช้ /code-review ✅
  │   └─ การเปลี่ยนแปลงเล็กน้อย?
  │       → ไม่ต้องใช้ slash command
  │
  └─ Deploy ระบบ
      ├─ Production deployment?
      │   → ใช้ /deploy ✅ (must!)
      ├─ Configuration change ที่สำคัญ?
      │   → ใช้ /deploy ✅
      └─ Dev/test deployment?
          → ไม่จำเป็นต้องใช้ (แต่ใช้ได้ถ้าต้องการ safety)
```

---

## 📚 ตัวอย่าง Workflow แนะนำ

### Workflow 1: พัฒนา Feature ใหม่ (New Feature)
```
1. /feature-dev
   → Claude ถามคำถาม
   → ตอบคำถามให้ละเอียด
   → ได้ SPEC.md + TODO list

2. Follow TODO list ทีละข้อ
   → พิมพ์ธรรมดา: "ทำข้อ 1: สร้าง API route"
   → Claude เขียนโค้ด
   → Test
   → Next TODO

3. /code-review (เมื่อทำเสร็จทั้งหมด)
   → Claude review โค้ดที่เขียน
   → แก้ issues ที่พบ

4. /deploy (เมื่อ ready สำหรับ production)
   → Deploy แบบปลอดภัย
   → Health check
   → Monitor
```

### Workflow 2: แก้ Bug + Deploy
```
1. พิมพ์ธรรมดา: "แก้ bug: API timeout after 10 requests"
   → Claude investigate
   → Fix code

2. /code-review
   → Review fix ว่าแก้ถูกต้อง
   → ไม่ทำให้เกิด regression

3. /deploy
   → Deploy fix to production
   → Verify bug หายแล้ว
```

### Workflow 3: Review Code Only
```
1. /code-review
   → Review PR ก่อน merge

2. แก้ issues ที่พบ (พิมพ์ธรรมดา)
   → Claude แก้ไข

3. /code-review อีกรอบ (optional)
   → ยืนยันว่าแก้ถูกต้อง
```

---

## ⚠️ ข้อควรระวัง (Common Pitfalls)

### 1. ใช้ /feature-dev แล้วบังคับให้เขียนโค้ดทันที
**ผิด:**
```
User: /feature-dev ทำ feature X
Claude: [ถามคำถาม]
User: เริ่มเขียนโค้ดเลย!  ❌
```

**ถูก:**
```
User: /feature-dev ทำ feature X
Claude: [ถามคำถาม]
User: [ตอบคำถาม]
Claude: [สร้าง PLAN.md]
User: แผนนี้โอเค เริ่มได้  ✅
```

### 2. ใช้ /code-review กับการเปลี่ยนแปลงเล็กๆ
**ผิด:**
```
User: /code-review
       แก้ typo ในคอมเมนต์  ❌
```

**ถูก:**
```
User: /code-review
       Review PR #123 ที่ refactor authentication  ✅
```

### 3. Deploy production โดยไม่ใช้ /deploy
**ผิด:**
```
User: Copy ไฟล์ใหม่ไป production แล้ว restart service  ❌
      (ไม่มี backup, ไม่มี rollback plan)
```

**ถูก:**
```
User: /deploy
       Deploy updated authentication module to production  ✅
```

---

## 🔧 การปรับแต่ง (Customization)

Slash commands เหล่านี้เป็น **template** ที่ Boss สามารถแก้ไขได้:

```bash
# ที่อยู่ไฟล์
~/.claude/commands/feature-dev.md
~/.claude/commands/code-review.md
~/.claude/commands/deploy.md
```

### ตัวอย่างการปรับแต่ง

**เพิ่มขั้นตอนใน /deploy:**
```markdown
# /deploy (checklist driven)
- Backup current state
- Apply change
- Run health
- Generate rollback script
- Attach logs + artifact refs
- Send notification to Slack  ← เพิ่มบรรทัดนี้
- Update deployment log       ← เพิ่มบรรทัดนี้
```

**ปรับ /feature-dev ให้สร้าง diagram:**
```markdown
# /feature-dev (plan-first)
- Ask clarifying Qs → produce **SPEC.md**
- Break down tasks → TODO list
- Create architecture diagram (mermaid) ← เพิ่มบรรทัดนี้
- Propose test strategy
- Output: `g/reports/feature_[slug]_PLAN.md`
```

---

## 📊 สรุปเปรียบเทียบ

| Command | Purpose | Complexity | Output | Best For |
|---------|---------|------------|--------|----------|
| `/feature-dev` | วางแผนพัฒนา feature | Medium-High | SPEC.md + TODO | Feature ใหม่ที่ซับซ้อน |
| `/code-review` | Review โค้ดหลายมุมมอง | High (subagents) | Multi-agent report | PR ใหญ่, critical code |
| `/deploy` | Deploy แบบปลอดภัย | Medium | Checklist + rollback | Production deployment |

---

## 🎓 Next Steps

1. **ทดลองใช้ /feature-dev** กับ feature เล็กๆ ก่อน
2. **ใช้ /code-review** กับ PR ถัดไป
3. **ใช้ /deploy** ทุกครั้งที่ deploy production
4. **ปรับแต่ง commands** ให้เหมาะกับ workflow ของตัวเอง
5. **สร้าง custom commands** เพิ่มเติมตามต้องการ

---

## 📖 เอกสารเพิ่มเติม

- **Thai Article**: Best practices ที่เป็นที่มาของ slash commands
- **Context Engineering**: `/Volumes/hd2/luka_docs_archive/docs/CONTEXT_ENGINEERING.md`
- **Phase 1.5 Report**: `g/reports/claude_code/phase1.5_deployment.md`

---

**สถานะ**: ✅ Ready to Use
**Version**: 1.0 (Phase 1.5)
**Last Updated**: 2025-11-12 00:42 +07

*คู่มือนี้จะถูกอัพเดทเมื่อมี commands ใหม่หรือการปรับปรุง*
