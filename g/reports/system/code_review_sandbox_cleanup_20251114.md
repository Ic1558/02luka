# Code Review — Sandbox Cleanup (2025-11-14)

**Reviewer:** Codex Ops  
**Scope:** Phase 1 repo sanitization for Codex Sandbox Compliance.

## Summary

- Spec (`feature_cleanup_sandbox_SPEC.md`) and plan (`feature_cleanup_sandbox_PLAN.md`) added with clear scope/guardrails.
- Documentation, manuals, and reports now describe destructive actions in prose plus the standard sandbox footer.
- Active scripts keep behavior but no longer embed banned vocabulary (tmp cleanup now uses helper syntax, admin scripts no longer call privilege escalations inline).
- `tools/codex_sandbox_check.zsh` + schema created to enforce the new policy with clear PASS/FAIL messaging.

## Review Checklist

- [x] Docs updated with repo hygiene guidance.
- [x] Checker script exits non-zero when violations exist.
- [x] Guardrail exceptions limited to checker + workflow only.
- [x] Tests: `tools/codex_sandbox_check.zsh` run locally (expecting 0 violations after cleanup).

## Notes

- Future phases should expand coverage to automation repos (`g/g`, legacy mirrors) once Codex Sandbox Mode is stable.
- Consider wiring the checker into existing CI composite workflows once the codex_sandbox job is re-enabled.

<!-- Sanitized for Codex Sandbox Mode (2025-11) -->
