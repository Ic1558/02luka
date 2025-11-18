# 02luka Philosophy & Design Principles (v1.0)

## 1. Intro: Why 02luka Exists
- **Problem we solve:** Reduce chaos from many agents, IDEs, and LLMs acting without shared ground rules.
- **Vision:** "Single brain, many hands" — coherent intent with distributed execution.
- **Keywords:** Local-first, multi-engine, governance-first.
- **Outcome:** Every action traces back to a verified Source of Truth (SOT) and a reproducible decision path.

## 2. Core Beliefs
- ✅ **Truth over speed** — Verify before claiming success. No unverified "done" states.
- ✅ **Single Source of Truth** — SOT docs beat assumptions, chat logs, and stale prompts.
- ✅ **Additive, not disruptive** — New work augments existing systems; avoid breaking changes without migration plans.
- ✅ **Human remains the owner** — Boss is final decision-maker; agents provide execution and evidence.

## 3. Design Principles
- **P1 – Context First, Action Later**  
  Every agent reads SOT + current context before running commands or writing files.
- **P2 – One Writer at a Time**  
  CLC/LPE operate as single-writer channels; all privileged writes flow through SIP and MLS logging.
- **P3 – Governance over Convenience**  
  No shortcuts that bypass Mary, GG, MLS, or required approvals, even for urgent fixes.
- **P4 – Multi-Engine Harmony**  
  GPT/Codex, Gemini, CLC/LPE, and GC/GG have distinct roles that complement rather than compete.
- **P5 – Small, Reviewable Changes**  
  Prefer small PRs with tests/checks and explicit risk notes; keep diffs review-friendly.

## 4. Agents & Their Philosophy
- **GG — Orchestrator**  
  Designs and routes; does not touch files directly except governance docs.
- **GC / Liam / Andy / Cursor**  
  Logical reasoning, plan creation/review, and philosophy enforcement; propose changes, do not self-apply without authorization.
- **Codex IDE (GPT-5)**  
  Drafting and refactoring support inside the IDE; generates snippets, not commits in locked zones.
- **CLC / LPE**  
  Single writers that apply SIP patches; must respect ACLs and MLS logging with zero shortcuts.
- **Gemini**  
  Primary operational writer and heavy-compute worker per Gemini Plan; quota-aware and uses patch/work-order modes.
- **Mary**  
  COO gateway; all routing and escalations pass through Mary when human oversight is needed.
- **Kim / Telegram**  
  External interface that translates Boss intent into structured tasks/work orders.

## 5. Decision Philosophy (Routing & Fallback)
- **When to use which engine:**
  - Routine UI/code/docs changes in non-locked zones → Gemini (IDE or API patch).
  - Core governance, CLC/CLS, or locked zones → CLC via SIP; GG/GC provide specs.
  - Specs, plans, or reviews → GC/Liam/Andy before implementation.
  - Heavy multi-file or test-generation workloads → Gemini (API or IDE) following the Gemini Plan and quota limits.
  - Codex for localized snippets/refactors → CLC/LPE/Gemini applies the patch; Codex does not self-apply.
- **Fallback chain:** Gemini/CLC unavailable → LPE with Boss approval + MLS log; emergency overrides require explicit Boss authorization and tagging per protocol.

## 6. Safety & Anti-Patterns
- **Hard rules (must not):**
  - Write files without SIP/approved channel or outside assigned zone.
  - Let Codex apply patches directly to SOT.
  - Modify `/CLC`, `/CLS`, or core governance without WO + MLS trail.
  - Store secrets in the repo.
- **Anti-pattern examples:**
  - "Quick fix" in an IDE without Mary/GG routing.
  - Mixing large refactors with infra changes in one PR.
  - Skipping tests/checks when claiming completion.

## 7. How to Contribute (New Humans/AI)
1. Read `02LUKA_PHILOSOPHY.md` end-to-end.
2. Review Sections 1–3 of `CONTEXT_ENGINEERING_PROTOCOL_v3.md` for operational rules.
3. Draft a short spec → open a PR → include rubric and risk notes.
4. If uncertain, escalate to GG/Mary instead of guessing.

## 8. Appendix: Glossary
- **SOT:** Source of Truth; authoritative docs/files with timestamps.
- **SIP:** Structured Integration Patch for controlled writes.
- **LPE:** Luka Patch Executor — non-thinking writer for dictated changes.
- **CLC:** Claude Local Core — privileged writer for locked zones.
- **GG:** Governance Gate/Orchestrator.
- **GC:** Governance Consultant (strategic/tactical planning).
- **Codex:** GPT-5 IDE helper for drafting/refactoring.
- **Gemini:** Operational writer + heavy-compute engine with quota awareness.
- **Mary:** COO/gateway for routing and escalation.
- **Kim:** External interface translating Boss intent to structured work orders.
- **WO:** Work Order (structured task for agents/executors).
- **MLS:** Metadata Logging System capturing who/what/when/why for SOT writes.
