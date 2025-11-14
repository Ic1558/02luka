# Multi-Agent PR Review CLI

## Overview
`tools/multi_agent_pr_review.zsh` collects GitHub PR context, builds a contract-aware review payload, and fan-outs the task to multiple agents through `tools/claude_subagents/orchestrator.zsh`. The orchestrator summary is converted into Markdown/JSON reports under `g/reports/system/` with the required classification footer.

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

### Modes
- `review` – cooperative default.
- `compete` – pit agents against each other.
- `collab` – alias for orchestrator `collaborate` mode.

### Agent command resolution
`--agent-command` (or the `MULTI_AGENT_REVIEW_CMD` environment variable) accepts a template string. The literal token `{TASK_FILE}` will be replaced with the generated payload path before invoking the orchestrator. If the placeholder is omitted it is appended automatically.

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
