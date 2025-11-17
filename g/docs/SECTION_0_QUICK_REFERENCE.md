# Section 0: Quick Reference / TL;DR

**Note:** This file contains Section 0 content for `CONTEXT_ENGINEERING_PROTOCOL_v3.md`. The content has been integrated into the main protocol file.

---

## 0. Quick Reference / TL;DR

**🎯 Key Principle (Invariant):**
> **"Gemini writes non‑locked zones via patch. CLC writes privileged zones. Codex thinks. LPE transcribes."**

---

### Who Uses This Protocol?

**Primary Users (Read Full Document):**

- **GG** — Uses 100% of document for every classification/routing
- **GC** — Uses sections 2, 3, 4, 6 for validation
- **CLC** — Uses multiple sections for SIP patches and governance changes

**Secondary Users (Read Specific Sections):**

- **Liam** — Uses sections 2.2, 3, 4 for routing decisions
- **Andy** — Uses allowed zones + Gemini/Andy relationship
- **Gemini** — Uses capability table + safety-belt mode (~20% of file)

**Non-Users:**

- **LPE Worker** — Does not read (bash/zsh script, no LLM reasoning)

---

### Agent Capabilities (At-a-Glance)

| Agent | Can Think? | Can Write SOT? | Primary Use |
|-------|------------|----------------|-------------|
| **GG** | ✅ Strategic | ✅ Governance only | Governance decisions |
| **GC** | ✅ Tactical | ✅ Specs, PRPs | Implementation planning |
| **CLC** | ✅ Operational | ✅ Locked zones | Privileged writes |
| **Gemini** | ✅ Operational | ✅ Non-locked zones (patch) | Primary operational writer |
| **Codex/Liam/Andy** | ✅ Analysis | ⚠️ Override only | IDE assistance, routing |
| **LPE** | ❌ No | ✅ Fallback only | Emergency writes |
| **Kim** | ✅ Routing | ❌ No | Task orchestration |

---

### Zone Rules (Quick Check)

**✅ Allowed:** `apps/**`, `tools/**`, `tests/**`, `docs/**` (non-governance)  
**❌ Locked:** `/CLC/**`, `/core/governance/**`, `memory_center/**`, `launchd/**`, `bridge/**`

**Rule:** If unsure, check `CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json` → `zones.locked_zones`

---

### Fallback Ladder (When Primary Writer Unavailable)

1. **Primary:** Gemini (non-locked zones) or CLC (locked zones)
2. **Fallback:** LPE (with Boss approval, logs to MLS)
3. **Emergency Override:** Codex/Liam/Andy (Boss explicit authorization, tag `EMERGENCY_LIAM_WRITE`)

**Decision:** Urgent? → Use LPE. Not urgent? → Wait for new session.

---

### Common Queries (Use JSON Schema)

For programmatic access, use `CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json`:

- **Which agent can write to zone X?** → Query `agents[].write_zones` or `agents[].write_scope`
- **Which zones are locked?** → Query `zones.locked_zones`
- **Fallback chain?** → Query `fallback_ladder.fallback_chain`

---

### Enforcement (Must-Know)

- **Git Hook:** `.git/hooks/pre-commit` (tags Codex/Liam/Andy commits, validates LaunchAgents)
- **Token Monitoring:** CLC warns at 150K, alerts at 180K, fallback at 190K+
- **MLS Logging:** Required for all SOT writes (who, when, what, why, approval)

---

### Quick Links

- **Full Protocol:** See Section 1-12 below
- **Quick Reference:** `PROTOCOL_QUICK_REF.md` (decision trees + matrix only)
- **Machine-Readable:** `CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json` (JSON schema)

---

**💡 Tip:** If you're an AI agent (Liam/Andy/Gemini), load the JSON schema first for fast capability lookups, then reference specific sections of the markdown as needed.

---
