# Multi-Agent PR Review CLI Manual

## Overview
`tools/multi_agent_pr_review.zsh` wraps the Claude subagent orchestrator so a single command can fetch a PR, generate a contract-aware payload, run multi-agent reviewers, and persist their output under `g/reports/system/`.

The CLI expects to run from `~/02luka/g` with both `gh` and `jq` installed. It also requires the governance contract located at `../docs/MULTI_AGENT_PR_CONTRACT.md`.

## Requirements
- `gh` authenticated against the repository.
- `jq` for JSON parsing.
- Executable `tools/claude_subagents/orchestrator.zsh` and whatever agent command you want to run (defaults to `cat`).

## Usage
From the repo root or `~/02luka/g`:
```bash
# Basic two-agent review
tools/multi_agent_pr_review.zsh 289

# Competing three-agent review with custom runner
MULTI_AGENT_REVIEW_CMD='cls_shell_request.zsh "codex_cli review --task {TASK_FILE}"' \
  tools/multi_agent_pr_review.zsh 289 --agents 3 --mode compete

# Explicit agent command template (placeholder {TASK_FILE} will be replaced)
tools/multi_agent_pr_review.zsh 289 --agent-command 'codex_cli --mode pr-review --input {TASK_FILE}'
```

### Arguments
- `PR_NUMBER` (required): GitHub pull request number to review.
- `--agents N`: Number of reviewers (1-10, default 2).
- `--mode MODE`: Orchestrator strategy. Supports `review`, `compete`, and `collab` (mapped to `collaborate`).
- `--agent-command CMD`: Command template executed for each agent. Use `{TASK_FILE}` placeholder to reference the generated task file. Defaults to `cat {TASK_FILE}`.
- `--meta-file PATH`: Provide saved `gh pr view ... --json` output. When set, GitHub metadata fetch is skipped (helpful for sandboxes without network).
- `--diff-file PATH`: Provide a local patch to avoid `gh pr diff`.

### Modes
- `review` – cooperative default.
- `compete` – pit agents against each other.
- `collab` – alias for orchestrator `collaborate` mode.

### Agent command resolution
`--agent-command` (or the `MULTI_AGENT_REVIEW_CMD` environment variable) accepts a template string. The literal token `{TASK_FILE}` will be replaced with the generated payload path before invoking the orchestrator. If the placeholder is omitted it is appended automatically.

## How it works
1. Fetch metadata and diffs via `gh pr view` + `gh pr diff`.
2. Inline the multi-agent contract text to remind reviewers of governance constraints.
3. Build a JSON payload with metadata, files, diff, and contract pointer.
4. Launch the orchestrator: `zsh tools/claude_subagents/orchestrator.zsh <mode> <task> <agents>`.
5. Parse `g/reports/system/claude_orchestrator_summary.json` for agent stdout/stderr.
6. Emit two artifacts under `g/reports/system/`:
   - `code_review_pr<PR>_<timestamp>.md`
   - `code_review_pr<PR>_<timestamp>.json`

## Outputs
Each run writes:
- Markdown: `g/reports/system/code_review_pr<PR>_<TIMESTAMP>.md`
- JSON mirror: `g/reports/system/code_review_pr<PR>_<TIMESTAMP>.json`
- Payload scratch file: `g/tmp/multi_agent_pr_review.*.md` (removed after execution)

The Markdown report includes:
1. PR snapshot metadata
2. Raw agent outputs (from `claude_orchestrator_summary.json`)
3. Strategy summary
4. Mandatory classification block:
   ```yaml
   classification:
     task_type: PR_FIX | PR_FEAT | PR_DOCS
     primary_tool: codex_cli
     needs_pr: true
     security_sensitive: true|false
     reason: "Why the classification was selected"
   ```

Use the JSON mirror when you need to ingest results programmatically or archive the orchestrator summary alongside the rendered report.

## Failure modes
- Missing prerequisites (`gh`, `jq`, contract file, orchestrator) ⇒ CLI exits with a clear error.
- Invalid PR number / GH lookup failure ⇒ aborts before orchestrator runs.
- Orchestrator non-zero exit ⇒ CLI logs the failure but still collates whatever output exists.

## Tips
- Reports inherit UTC timestamps in their filenames; keep them alongside other governance evidence.
- Use `--mode compete` plus higher agent counts for contentious changes; switch back to `review` for light-touch audits.
- When network access is unavailable (e.g., Codex sandbox), copy down a `gh pr view` JSON + patch ahead of time or use the sample fixtures under `tools/fixtures/multi_agent_pr_review/` to validate the orchestrator wiring locally.
