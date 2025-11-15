# Multi-Agent PR Review CLI Manual

## Overview
`tools/multi_agent_pr_review.zsh` collects GitHub PR context, builds a contract-aware review payload, and fans out the task to multiple agents through `tools/claude_subagents/orchestrator.zsh`. The orchestrator summary is converted into Markdown/JSON reports under `g/reports/system/` with the required classification footer.

The CLI expects to run from the repo root (or `~/02luka/g`) with both `gh` and `jq` installed plus the governance contract located at `../docs/MULTI_AGENT_PR_CONTRACT.md`.

## Requirements
- `gh` authenticated against the repository.
- `jq` for JSON parsing.
- Executable `tools/claude_subagents/orchestrator.zsh`.
- Whatever agent command you want to run (defaults to `cat`).

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

# Collaborate mode alias
tools/multi_agent_pr_review.zsh 288 --mode collab
```

### Arguments & Modes
- `PR_NUMBER` (required): GitHub pull request number to review.
- `--agents N`: Number of reviewers (1-10, default 2).
- `--mode MODE`: Orchestrator strategy – supports `review` (cooperative default), `compete`, and `collab` (alias for `collaborate`).

### Agent command resolution
`--agent-command` (or `MULTI_AGENT_REVIEW_CMD`) accepts a template string. The literal token `{TASK_FILE}` is replaced with the generated payload path before invoking the orchestrator. If omitted it is appended automatically.

## How it Works
1. Fetch metadata and diffs via `gh pr view` + `gh pr diff`.
2. Inline the multi-agent contract text to remind reviewers of governance constraints.
3. Build a JSON payload with metadata, files, diff, and contract pointer.
4. Launch the orchestrator: `zsh tools/claude_subagents/orchestrator.zsh <mode> <task> <agents>`.
5. Parse `g/reports/system/claude_orchestrator_summary.json` for agent stdout/stderr.
6. Emit two artifacts under `g/reports/system/`:
   - `code_review_pr<PR>_<timestamp>.md`
   - `code_review_pr<PR>_<timestamp>.json`

Each Markdown report ends with the required block:
```yaml
classification:
  task_type: PR_FEAT | PR_FIX | PR_DOCS
  primary_tool: codex_cli
  needs_pr: true
  security_sensitive: true|false
  reason: "Why the classification was selected"
```

Use the JSON mirror when you need to ingest results programmatically or archive the orchestrator summary alongside the rendered report.

## Failure Modes
- Missing prerequisites (`gh`, `jq`, contract file, orchestrator) ⇒ CLI exits with a clear error.
- Invalid PR number / GH lookup failure ⇒ aborts before orchestrator runs.
- Orchestrator non-zero exit ⇒ CLI logs the failure but still collates whatever output exists.

## Tips
- Reports inherit UTC timestamps in their filenames; keep them alongside other governance evidence.
- Use `--mode compete` plus higher agent counts for contentious changes; switch back to `review` for light-touch audits.
- The payload scratch file (`g/tmp/multi_agent_pr_review.*.md`) is removed after execution; inspect it before exit if you need to debug agent inputs.
