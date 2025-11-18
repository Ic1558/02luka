# Multi-Agent PR Review CLI

## Overview
`tools/multi_agent_pr_review.zsh` collects GitHub PR metadata, diffs, and the governance contract, packages them into a contract-aware payload, and launches the Claude subagent orchestrator (`tools/claude_subagents/orchestrator.zsh`). The orchestrator runs one or more reviewers, collates their outputs, and emits Markdown/JSON reports under `g/reports/system/`.

## Requirements
- `gh` authenticated against the repository
- `jq` available on the PATH for JSON parsing
- Executable `tools/claude_subagents/orchestrator.zsh`
- Governance contract at `../docs/MULTI_AGENT_PR_CONTRACT.md`

## Usage
Run from the repo root or `~/02luka/g`:

```bash
# Default two-agent review
tools/multi_agent_pr_review.zsh 289

# Competing three-agent review with custom runner
MULTI_AGENT_REVIEW_CMD='cls_shell_request.zsh "codex_cli review --task {TASK_FILE}"' \
  tools/multi_agent_pr_review.zsh 289 --agents 3 --mode compete

# Collaborate mode alias
tools/multi_agent_pr_review.zsh 289 --mode collab

# Explicit agent command template
tools/multi_agent_pr_review.zsh 289 --agent-command 'codex_cli --mode pr-review --input {TASK_FILE}'
```

### Arguments & Modes
- `PR_NUMBER` (required): GitHub pull request number.
- `--agents N` (1-10, default 2): number of reviewers.
- `--mode MODE`: `review` (default cooperative), `compete`, or `collab` (alias of orchestrator `collaborate`).

### Agent command resolution
`--agent-command` or `MULTI_AGENT_REVIEW_CMD` accepts a template string. The literal token `{TASK_FILE}` is replaced with the generated payload path; if omitted it is appended automatically.

## How it works
1. Fetch PR snapshot (metadata, files, diff) via `gh`.
2. Inline the governance contract to remind reviewers of constraints.
3. Build a JSON payload referencing the contract and collected data.
4. Invoke the orchestrator: `zsh tools/claude_subagents/orchestrator.zsh <mode> <task> <agents>`.
5. Capture `g/reports/system/claude_orchestrator_summary.json` for stdout/stderr.
6. Emit two artifacts per run under `g/reports/system/`:
   - `code_review_pr<PR>_<timestamp>.md`
   - `code_review_pr<PR>_<timestamp>.json`

The Markdown report includes PR metadata, raw agent outputs, a synthesized strategy summary, and ends with the required classification block:

```
classification:
  task_type: PR_FIX | PR_FEAT | PR_DOCS
  primary_tool: codex_cli
  needs_pr: true
  security_sensitive: true|false
  reason: "Why the classification was selected"
```

Use the JSON mirror for programmatic ingestion or archival of the orchestrator summary.

## Failure modes
- Missing prerequisites (`gh`, `jq`, contract, orchestrator) → immediate error.
- Invalid PR number / GH failure → abort before orchestrator runs.
- Orchestrator non-zero exit → CLI logs failure but still collates any output.

## Tips
- Reports use UTC timestamps; keep them with other governance evidence.
- Use `--mode compete` and higher agent counts for contentious reviews; fall back to `review` for lighter audits.
- Filter or rerun agents by adjusting `{TASK_FILE}` templates—any executable command is allowed as long as it consumes the payload path.
