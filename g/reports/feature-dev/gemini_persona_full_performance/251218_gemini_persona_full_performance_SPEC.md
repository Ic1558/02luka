# Gemini Persona Full Performance Design - SPEC
**Feature:** `gemini.md` Persona with Full Performance + Safety Belt + Auto-Update  
**Date:** 2025-12-18  
**Status:** 📋 SPEC (Q&A Phase)

---

## Q&A: Clarifying Requirements

### Q1: What is `gemini.md`?
**A:** Based on codebase analysis, `gemini.md` should be:
- A **persona file** similar to `CLS.md` (located at `~/02luka/gemini.md` or `.cursor/commands/gemini.md`)
- Used by Gemini CLI/IDE to understand its role, capabilities, and constraints
- Loaded via `load_persona_v5.zsh gemini sync` or similar

**Assumption:** This is a **persona file** that defines Gemini's operational identity, not a configuration file.

---

### Q2: "Full Performance Not Blocks" - What does this mean?

**User Requirement (Confirmed):**
> "Full Performance = ปรับให้เร็วขึ้นโดยยังคงความปลอดภัย"
> "can act like clc or whatever with no block"
> "use it nature from model to get more reasoning and opinions"

**Current Understanding:**
- Gemini has quota limits (1500 requests/day, 120/minute) - **These are API limits, not artificial blocks**
- Safety-belt mode requires phase-based patches (prevents truncation) - **This is output management, not a performance block**
- Some operations may be unnecessarily blocked or rate-limited by **artificial constraints in persona/routing**

**Key Insight:**
- **Remove artificial performance blocks** that prevent Gemini from operating at full capacity
- **Allow Gemini to use its natural reasoning capabilities** (like CLC does)
- **Don't artificially limit thinking depth or opinion-giving**
- **Still maintain safety belt** (hard blocks like Safe Zones, DANGER patterns remain)

**Proposed Interpretation:**
- **Full Performance** = Act like CLC with no artificial blocks
  - **No artificial rate limiting** (only respect API quota limits)
  - **Full reasoning depth** - Use model's natural capabilities for analysis, opinions, strategic thinking
  - **No artificial thinking constraints** - Allow deep reasoning like CLC does
  - **Parallel processing** enabled for bulk operations
  - **Fast-path for low-risk operations** (still guarded by safety belt)
  - **Remove unnecessary validation delays** that don't add safety value

---

### Q3: "Still in Safety Belt" - What safety features are required?

**User Requirement (Confirmed):**
> "Still in safety belt" - Safety must remain, but not block performance

**Current Safety Systems:**
1. **Safe Zones** (hard block) - Prevents writes outside `/Users/icmini/02luka` ✅ **KEEP**
2. **GM Policy** (review flag) - Flags risky operations for review ✅ **KEEP** (but optimize)
3. **Router v5** - Lane/zone routing (FAST/WARN/STRICT/BLOCKED) ✅ **KEEP**
4. **SandboxGuard v5** - SIP requirements, path safety ✅ **KEEP**
5. **Safety-Belt Mode** - Phase-based patches, section-scoped output ✅ **KEEP** (for output management)

**Key Distinction:**
- **Hard Safety Blocks** (Safe Zones, DANGER patterns) = **MUST KEEP** (these are real safety)
- **Performance Blocks** (artificial rate limits, thinking constraints) = **REMOVE** (these block performance)
- **Review Flags** (GM policy) = **KEEP** (but make them fast, don't block reasoning)

**Proposed Safety Belt:**
- **Keep all hard blocks** (Safe Zones, DANGER patterns) - These are real safety
- **Keep review flags** (GM policy) - But make them fast, non-blocking for reasoning
- **Adaptive strictness** (FAST lane in OPEN zone = minimal checks, STRICT = full checks)
- **SIP requirements** remain for code changes, relaxed for docs
- **No artificial thinking constraints** - Allow full reasoning depth like CLC
- **No artificial rate limiting** - Only respect API quota limits

---

### Q4: "Using Context Engineering, AI/OP, Governance" - How should they integrate?

**Current Integration Points:**
1. **Context Engineering Protocol v3.2** - Defines Gemini as Layer 4.5
2. **AI_OP_001_v5** - Operational rules for AI execution
3. **GOVERNANCE_UNIFIED_v5** - Gateway v3, Router v5, SandboxGuard v5
4. **Persona Loading Guide** - How personas are loaded/synced

**Questions:**
1. Should `gemini.md` **reference** these protocols, or **embed** key rules?
2. Should it **auto-update** when protocols change?
3. How should it **integrate with governance v5** (router, guard, processor)?

**Proposed Integration:**
- **Reference** protocols (don't duplicate, point to SOT)
- **Embed** key operational rules (zone permissions, lane logic)
- **Auto-sync** with protocol changes via file watcher or periodic check
- **Governance v5** integration via explicit routing/guard calls

---

### Q5: "Auto-Update to System" - What triggers updates?

**Current Auto-Update Mechanisms:**
1. **Persona Loader** (`load_persona_v5.zsh`) - Manual sync command
2. **Memory Hub** - Syncs context to Redis/file periodically
3. **LaunchAgents** - Can watch files and trigger updates

**Questions:**
1. Should `gemini.md` **auto-update** when:
   - Protocol files change (`CONTEXT_ENGINEERING_PROTOCOL_v3.md`, `AI_OP_001_v5.md`)?
   - Governance configs change (`GOVERNANCE_UNIFIED_v5.md`)?
   - Persona source changes (`personas/GEMINI_PERSONA_v3.md`)?
2. Should updates be **immediate** (file watcher) or **periodic** (cron/LaunchAgent)?
3. Should updates **notify** Gemini CLI/IDE to reload?

**Proposed Auto-Update:**
- **File watcher** on protocol/governance files → trigger persona rebuild
- **Periodic sync** (every 15-30 min) to catch missed updates
- **Version tracking** (persona version vs protocol version) to detect drift
- **Reload signal** to active sessions (via Redis/pub-sub or file touch)

---

## Proposed Design (Based on User Requirements)

### Design Principles

1. **Full Performance (No Artificial Blocks):**
   - **Remove artificial thinking constraints** - Allow full reasoning depth like CLC
   - **No artificial rate limiting** - Only respect API quota limits (1500/day, 120/min)
   - **Full model capabilities** - Use natural reasoning, analysis, opinion-giving
   - **Parallel processing** for multi-file operations
   - **Fast-path for OPEN zone + FAST lane** (minimal validation, full reasoning)
   - **Batch operations** where safe
   - **Smart quota management** (informational only, don't block reasoning)

2. **Safety Belt (Real Safety Only):**
   - **Hard blocks remain** (Safe Zones, DANGER patterns) - These are real safety
   - **Review flags** (GM policy) - Fast, non-blocking for reasoning
   - **Adaptive strictness** (FAST/OPEN = minimal checks, STRICT/LOCKED = full checks)
   - **SIP requirements** for code, relaxed for docs
   - **No artificial performance blocks** - Only real safety blocks

3. **Natural Model Capabilities:**
   - **Full reasoning depth** - Like CLC, not artificially limited
   - **Opinion-giving enabled** - Provide strategic insights, recommendations
   - **Analysis capabilities** - Deep code analysis, pattern recognition
   - **Multi-step reasoning** - Complex problem-solving without artificial limits
   - **Context awareness** - Full repository understanding

4. **Context Engineering Integration:**
   - References `CONTEXT_ENGINEERING_PROTOCOL_v3.md` (Layer 4.5 rules)
   - Embeds zone permissions and lane logic
   - Links to `GEMINI_CLI_RULES.md` for CLI-specific rules
   - Includes MLS integration (read-only lessons)
   - **No artificial constraints** on thinking scope

5. **AI/OP Integration:**
   - References `AI_OP_001_v5.md` for operational rules
   - Embeds SIP requirements and WO lifecycle
   - Includes telemetry/logging requirements
   - Links to governance v5 components
   - **Full operational capabilities** like CLC

6. **Governance Integration:**
   - References `GOVERNANCE_UNIFIED_v5.md` for architecture
   - Embeds Router v5 lane/zone logic
   - Includes SandboxGuard v5 SIP requirements
   - Links to Gateway v3 routing
   - **Respects governance, but doesn't artificially limit reasoning**

7. **Auto-Update:**
   - File watcher on protocol/governance files
   - Periodic sync (15-30 min) via LaunchAgent
   - Version tracking (persona version vs protocol version)
   - Reload signal to active sessions
   - **Auto-sync keeps persona aligned with latest protocols**

---

## Requirements Summary (Confirmed)

1. ✅ **`gemini.md` is a persona file** (like `CLS.md`)
2. ✅ **Full Performance** = Act like CLC with no artificial blocks
   - Remove artificial thinking constraints
   - Allow full reasoning depth and opinion-giving
   - Use natural model capabilities
   - No artificial rate limiting (only API quota limits)
3. ✅ **Safety Belt** = Real safety only
   - Keep hard blocks (Safe Zones, DANGER patterns)
   - Keep review flags (but make them fast, non-blocking)
   - Remove artificial performance blocks
4. ✅ **Auto-Update** = File watcher + periodic sync
   - Sync with protocol/governance changes
   - Version tracking
   - Reload signal to active sessions
5. ✅ **Persona** = Reference protocols + embed key rules
   - Don't duplicate, point to SOT
   - Embed operational rules for performance

---

## Next Steps

**Proceeding to PLAN.md with:**
- Implementation tasks for full-performance persona
- Remove artificial blocks while keeping safety
- Enable natural reasoning capabilities
- Auto-update mechanism design
- Integration points with governance v5
- Test strategy for performance vs safety balance

