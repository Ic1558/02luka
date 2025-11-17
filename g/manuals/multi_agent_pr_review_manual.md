# Multi-Agent PR Review CLI Manual

## Overview
`tools/multi_agent_pr_review.zsh` collects GitHub PR context, inlines the governance contract, and fan-outs review tasks to multiple agents through `tools/claude_subagents/orchestrator.zsh`. Each execution emits Markdown/JSON reports under `g/reports/system/` with the required classification footer so governance evidence stays consistent.

## Requirements
- Run from the repo root (`~/02luka` or `~/02luka/g`).
- Authenticated `gh` CLI for fetching PR metadata/diffs.
- `jq` for JSON parsing.
- Executable `tools/claude_subagents/orchestrator.zsh` plus whatever agent runner you want (defaults to `cat`).
- Governance contract at `docs/MULTI_AGENT_PR_CONTRACT.md` (referenced in payloads).

## Usage
```bash
cd ~/02luka/g
# Basic two-agent cooperative review
tools/multi_agent_pr_review.zsh 289

# Competing review with custom runner template
MULTI_AGENT_REVIEW_CMD='cls_shell_request.zsh "codex_cli review --task {TASK_FILE}"' \
  tools/multi_agent_pr_review.zsh 289 --agents 3 --mode compete

# Collaborate alias
tools/multi_agent_pr_review.zsh 289 --mode collab

# Explicit agent command template (auto-appends {TASK_FILE} if omitted)
tools/multi_agent_pr_review.zsh 289 --agent-command 'codex_cli --mode pr-review --input {TASK_FILE}'
```

### Arguments & Modes
- `PR_NUMBER` (required): Target GitHub PR.
- `--agents N` (default 2, max 10): number of reviewers.
- `--mode review|compete|collab`: maps directly to orchestrator strategies (collab ⇒ `collaborate`).
- `--agent-command TEMPLATE`: overrides the runner; `{TASK_FILE}` placeholder is replaced with the generated payload path. The `MULTI_AGENT_REVIEW_CMD` env var offers the same capability.

## How it Works
1. Fetch metadata and diffs via `gh pr view` / `gh pr diff`.
2. Inline `docs/MULTI_AGENT_PR_CONTRACT.md` to remind reviewers of governance rules.
3. Build a JSON payload with metadata, files, diff, and contract pointer.
4. Launch the orchestrator: `zsh tools/claude_subagents/orchestrator.zsh <mode> <task> <agents>` (with `{TASK_FILE}` passed through your runner).
5. Parse `g/reports/system/claude_orchestrator_summary.json` for agent stdout/stderr.
6. Convert the summary into Markdown + JSON reports and drop them in `g/reports/system/`.

## Outputs
- Markdown: `g/reports/system/code_review_pr<PR>_<TIMESTAMP>.md`
- JSON mirror: `g/reports/system/code_review_pr<PR>_<TIMESTAMP>.json`
- Scratch payloads under `g/tmp/multi_agent_pr_review.*.md` (cleaned up automatically)

Every Markdown report ends with:
```yaml
classification:
  task_type: PR_FIX | PR_FEAT | PR_DOCS
  primary_tool: codex_cli
  needs_pr: true
  security_sensitive: true|false
  reason: "Why the classification was selected"
```
Use the JSON mirror when ingesting the results programmatically or archiving the orchestrator summary alongside the rendered report.

## Failure Modes
- Missing prerequisites (`gh`, `jq`, contract, orchestrator) ⇒ exits early with actionable messaging.
- Invalid PR number / GitHub lookup failure ⇒ aborts before starting agents.
- Orchestrator non-zero exit ⇒ still collates whatever output exists so you can inspect partial results.

## Tips
- Reports use UTC timestamps—handy for governance timelines.
- Increase `--agents` or switch to `--mode compete` for contentious changes; keep `review` for quick audits.
- Pair the CLI with `tools/reality_hooks/pr_reality_check.zsh` if you want orchestration evidence captured alongside runtime reality hooks.
