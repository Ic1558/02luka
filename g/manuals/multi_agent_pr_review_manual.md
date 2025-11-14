# Multi-Agent PR Review CLI Manual

## Overview
`tools/multi_agent_pr_review.zsh` wraps the Claude subagent orchestrator so a single command can fetch a PR, generate a contract-aware payload, run multi-agent reviewers, and persist their output under `g/reports/system/`.

The CLI expects to run from `~/02luka/g` with both `gh` and `jq` installed. It also requires the governance contract located at `../docs/MULTI_AGENT_PR_CONTRACT.md`.

## Usage
```bash
cd ~/02luka/g
# Default run (2 agents, review mode)
tools/multi_agent_pr_review.zsh 288

# Increase coverage + switch strategy
tools/multi_agent_pr_review.zsh 288 --agents 3 --mode compete

# Collaborate mode alias
tools/multi_agent_pr_review.zsh 288 --mode collab
```

### Arguments
- `PR_NUMBER` (required): GitHub pull request number to review.
- `--agents N`: Number of reviewers (1-10, default 2).
- `--mode MODE`: Orchestrator strategy. Supports `review`, `compete`, and `collab` (mapped to `collaborate`).

## How it works
1. Fetch metadata and diffs via `gh pr view` + `gh pr diff`.
2. Inline the multi-agent contract text to remind reviewers of governance constraints.
3. Build a JSON payload with metadata, files, diff, and contract pointer.
4. Launch the orchestrator: `zsh tools/claude_subagents/orchestrator.zsh <mode> <task> <agents>`.
5. Parse `g/reports/system/claude_orchestrator_summary.json` for agent stdout/stderr.
6. Emit two artifacts under `g/reports/system/`:
   - `code_review_pr<PR>_<timestamp>.md`
   - `code_review_pr<PR>_<timestamp>.json`

Each Markdown report ends with the required block:
```
classification:
  task_type: PR_FEAT
  primary_tool: codex_cli
  needs_pr: true
  security_sensitive: false
  reason: "Multi-agent CLI to automate PR reviews using existing orchestrator and governance contract."
```

## Failure modes
- Missing prerequisites (`gh`, `jq`, contract file, orchestrator) ⇒ CLI exits with a clear error.
- Invalid PR number / GH lookup failure ⇒ aborts before orchestrator runs.
- Orchestrator non-zero exit ⇒ CLI logs the failure but still collates whatever output exists.

## Tips
- Reports inherit UTC timestamps in their filenames; keep them alongside other governance evidence.
- Use `--mode compete` plus higher agent counts for contentious changes; switch back to `review` for light-touch audits.
