# Codex Safety Onboarding

This quick-start note makes the sandbox rules scannable in under five minutes. Keep it open while building or reviewing Codex automations.

## 1. Sandbox Modes
- **read-only** – no writes anywhere; even temp files require explicit approval.
- **workspace-write** – reads everywhere, writes limited to repo + writable roots.
- **danger-full-access** – treat as production root access; log every destructive change.
- Always check the `sandbox_mode` line in the environment banner before running commands.

## 2. Approval Policies
- **never** – _never_ ask; you must succeed inside the sandbox or stop with findings.
- **on-request** – explicitly ask for escalation using `with_escalated_permissions`.
- **on-failure** – rerun failed commands with approval only if sandbox blocked them.
- **untrusted** – assume every non-trivial command needs approval.
- Describe why escalation is required in one sentence; destructive actions need prior user confirmation.

## 3. Guardrails
- Prefer `rg` over `grep`; avoid `cd` in shell calls (set `workdir` directly).
- Never run `git reset --hard`, `git checkout --`, `rm -rf /`, or similar destructive commands unless the user demanded them.
- When editing, default to ASCII; only introduce Unicode when the file already uses it and the change requires it.
- Do not touch files you did not create/modify unless the task demands it; never revert user edits.
- Plan before multi-step tasks, and keep the plan updated.

## 4. Validation Steps
1. Read the environment banner (cwd, sandbox, approval policy, network).
2. Decide whether a plan is required; if yes, document and maintain it.
3. Choose the least-privileged command that accomplishes the step; keep `workdir` explicit.
4. After edits, run targeted checks/tests and describe results in the final response.
5. Reference changed files with inline paths + line numbers; no giant dumps.

## 5. Quick Checklist (paste into PRs)
- [ ] Sandbox mode + approval policy acknowledged in the task.
- [ ] No destructive commands added; helper scripts avoid repo-mutating actions.
- [ ] `tools/codex_sandbox_check.zsh` run locally (or equivalent) with zero violations.
- [ ] Final response lists verification steps and next actions for reviewers.

Staying inside these constraints keeps Codex safe to run unattended and easy to audit.
