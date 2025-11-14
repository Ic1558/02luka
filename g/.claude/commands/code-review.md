# /code-review

**Goal:** Run two review agents on a given diff/path and synthesize findings.

## Usage

- Provide: paths or a commit range
- Strategy: review (Agent A implements critique; Agent B double-checks security)
- Backend: CLS (default) or Claude (via BACKEND=claude)

## Steps (tool-facing)

1) Run: `tools/subagents/orchestrator.zsh review "$INPUT" 2` (default: BACKEND=cls)

   - For Claude backend: `BACKEND=claude tools/subagents/orchestrator.zsh review "$INPUT" 2`

2) Compare: `tools/subagents/compare_results.zsh "$OUTPUT_DIR"`

3) Emit report → `g/reports/code_review_$(date +%Y%m%d)_AUTO.md`

4) If available, call `tools/claude_tools/metrics_collector.zsh` with `review=1`

## Example

```
/code-review README.md tools/comprehensive_alert_review.zsh
```

This will:
- Run orchestrator in review mode with 2 agents (CLS backend by default)
- Compare results from both agents
- Generate synthesized report with backend tag
- Record metrics (if available)
