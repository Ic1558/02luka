# Gemini Persona Full Performance Design — SPEC (Revised)
**Feature:** Gemini CLI `GEMINI.md` (Behavioral Contract) + 02luka Persona v3 (Full Performance + Safety Belt + Auto-Update)  
**Date:** 2025-12-18  
**Status:** 📋 SPEC

---

## 0) The “Do Not Confuse” Definition (Pinned)

### A) `GEMINI.md` (Gemini CLI) = Behavioral Contract
- **Purpose:** Tell Gemini *how to behave* (reasoning style, opinion-giving, execution discipline).
- **What it must NOT do:** “brain damage” governance (self-blocking: “never use tools”, “read-only always”, “always gmx identity”).
- **Where it lives (hierarchy):**
  - Global: `~/.gemini/GEMINI.md`
  - Project: `~/02luka/GEMINI.md` (plus subdirs)

### B) `personas/GEMINI_PERSONA_v3.md` (02luka) = System Persona
- **Purpose:** 02luka identity + Two Worlds + zone/lane vocabulary for IDE/routing.
- **How it’s used:** `tools/load_persona_v5.zsh gemini sync` → `.cursor/commands/gemini.md`.
- **Rule:** Persona can reference governance SOT; it should not copy massive “law” into itself.

---

## 1) What “Full Performance” Means (Pinned)

**Full Performance ≠ “no rules”.**  
Full Performance = “acts like CLC in capability” (deep reasoning + multiple opinions + tool usage) **without artificial blocks**, while staying within a real safety belt.

### What actually controls “fullness”
1) **Tool surface:** sandbox on/off, approvals, and installed tool/extension capabilities.
2) **Behavioral contract:** `GEMINI.md` should *encourage* reasoning and tool usage, not ban it.
3) **External law:** governance/AI-OP should be referenced and enforced at routing/sandbox/approval, not by suppressing cognition.

### Non-negotiable: Multi-Opinion is desired
When uncertain, Gemini should produce multiple options and trade-offs (Explorer-style), then converge to a single evidence-backed recommendation (Decider rule below).

---

## 2) Safety Belt (Real Safety Only)

### Hard blocks (must keep)
- Path safety: no writing outside `~/02luka` in normal operation.
- Destructive actions: delete/reset/overwrite/system paths require explicit confirmation.
- Locked zones: require WO/CLC lane per 02luka governance (Two Worlds).

### What must be removed (artificial performance blocks)
- “Don’t think deeply”, “don’t provide opinions”, “never use tools”, “always ask even for trivial reads”.
- Blanket bans that reduce tool surface without safety value.

### Where safety lives (correct placement)
- **CLI flags:** `--sandbox`, `--approval-mode`
- **02luka routing:** lanes/zones (FAST/WARN/STRICT/BLOCKED)
- **Catalog discipline:** `tools/catalog.yaml` → `tools/catalog_lookup.zsh` + `tools/run_tool.zsh`

---

## 3) Design: Layered + Modular Context (Scalable)

### Global (neutral) vs Project (governed)
- `~/.gemini/GEMINI.md` should remain **neutral** (no “always gmx”).
- `~/02luka/GEMINI.md` is **project-scoped HUMAN mode** and can import updated modules from the repo.

### Project module layout (repo-managed)
`~/02luka/context/gemini/`
- `ai_op.md` — operational summary (references AI/OP SOT)
- `gov.md` — governance summary (references governance SOT)
- `tooling.md` — “how to execute in 02luka”: catalog first, run-tool entrypoint, save-now semantics
- `system_snapshot.md` — **auto-generated truth** (P0 health, gateway telemetry presence, etc.)

### Why modules
- System jobs (or humans) can rewrite `system_snapshot.md` without editing `GEMINI.md`.
- `GEMINI.md` stays stable; content updates are safe and auditable.
- Gemini CLI can reload via `/memory refresh`.

---

## 4) Multi-Model Opinions (02luka-Compatible)

**Multi-model ≠ multi-executor.**  
Use multiple “opinions” but keep a single decider bound to evidence.

Recommended roles:
- **Explorer:** propose 2–3 approaches + trade-offs
- **Skeptic:** find failure modes, governance risks, edge cases
- **Decider:** pick one path using concrete evidence (catalog, files, logs)

This can be implemented as:
- Multiple sessions/models, or
- One session simulating roles (structured output), but still converging to one decision.

---

## 5) Operational Reality (Do Not Regress)

### OAuth vs API key
If the user wants Google OAuth flow, avoid exporting `GEMINI_API_KEY` into the shell session that runs Gemini CLI; otherwise CLI may route through API-key behavior.

### “auto model”
Gemini CLI `--model auto` is not guaranteed to be a valid model name; “auto” should be treated as **wrapper policy** (don’t pass `--model` unless user specifies a real model).

---

## 6) Acceptance Criteria

### Behavioral Contract (Gemini CLI)
- [ ] `~/02luka/GEMINI.md` exists and **does not** contain self-blocking phrases (no “always gmx”, no tool bans).
- [ ] `~/02luka/GEMINI.md` imports `context/gemini/*.md` modules.
- [ ] `/memory show` demonstrates the loaded context is the expected concatenation.

### Persona v3 (02luka)
- [ ] `personas/GEMINI_PERSONA_v3.md` exists and passes `tools/load_persona_v5.zsh gemini verify`.
- [ ] `tools/load_persona_v5.zsh gemini sync` produces `.cursor/commands/gemini.md`.

### Safety Belt
- [ ] Hard blocks remain intact (paths, destructive ops confirmation, Locked Zone policy).
- [ ] No artificial reasoning/opinion suppression.

---

## 7) Out of Scope (This SPEC)
- Installing third-party extensions from the internet (may require separate approval/policy).
- Changing user-global `~/.gemini/GEMINI.md` automatically (should be a manual, explicit user action).

