# Summary
- (Required) What change is being proposed?
- (Required) Why is this required now?

# Testing
- [ ] `zsh tools/codex_prompt_helper.zsh refactor`
- [ ] `zsh tools/codex_sandbox_check.zsh`
- [ ] _Additional checks (list here)_

# Codex Safety Checklist
- [ ] `docs/CODEX_SAFETY_ONBOARDING.md` explains sandbox modes/policies in a <5 min read.
- [ ] `docs/CODEX_MASTER_READINESS.md` documents the Phase 3 readiness section.
- [ ] All three prompt templates exist under `tools/codex_prompts/*.txt` and contain no disallowed commands.
- [ ] `tools/codex_prompt_helper.zsh` only reads templates (no repo mutations) and handles clipboard fallback.
- [ ] `zsh tools/codex_prompt_helper.zsh refactor` succeeds on a target machine with clipboard support (note if stdout fallback used).
- [ ] `tools/codex_sandbox_check.zsh` passes with **0 violations**.
