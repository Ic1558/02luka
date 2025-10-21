# Prompt Standards

## Structure Template
1. **Instruction**: Explicit task definition, constraints, and desired autonomy level.
2. **Context**: Summaries of relevant documents, previous steps, and stakeholder expectations.
3. **Data**: Structured inputs (tables, metrics, tickets) with source provenance.
4. **Output Format**: Required schema, tone, or markdown tables; include citation expectations.
5. **Tool Budget**: Allowed tools, rate limits, approval requirements, and fallback behavior.

```
INSTRUCTION:
- ...

CONTEXT:
- Key doc summary A
- KPI snapshot

DATA:
- table/json snippet

OUTPUT FORMAT:
- Markdown bullets with citations

TOOLS:
- Allowed: context.load, memory.remember
- Fallback: escalate to human if RAG score < 0.3
```

## Autonomy Tags
- `[assistive]`: Provide answers, never execute tools.
- `[guarded]`: Execute pre-approved tools with logging; request confirmation on anomalies.
- `[supervised]`: Require human approval before tool execution.
- `[diagnostic]`: Investigate and summarize issues without applying fixes.

## Tool Use Policy
- Default: Tools disabled until explicitly allowed in prompt.
- Each tool call must include `why` statement for audit trail.
- If tool errors occur twice consecutively, abort and escalate to human.
- Sensitive data tools (CRM/email) require `[supervised]` tag and `ops:approve` scope.
- Memory write operations must include `importance` estimate and `retentionHint`.

## Retrieval-Augmented Generation (RAG) Guidance
- Always cite retrieved documents with canonical IDs.
- Limit combined context to configured token budget (default 1200 tokens).
- Use freshness decay: boost items touched within last 14 days.
- When no relevant data found, return `confidence: low` and recommended next steps.

## Feedback Loop Prompts
- Post-task prompts ask for user satisfaction rating and desired improvements.
- Feedback stored via `memory.remember` with `kind=feedback` and `importance >= 0.4`.
- Tickets generated for `needs_changes` feedback using backlog connector stubs.

## Testing & Evaluation Prompts
- Regression prompts stored under `prompts/regression/` with expected outcomes.
- Eval harness records latency, accuracy, and cost metrics for KPI tracking.
