# Subagents - Subagent Orchestrator

**Last Updated:** 2025-11-15  
**Implementation:** `g/tools/claude_subagents/orchestrator.zsh`

---

## Role

**Subagents** = Subagent Orchestrator

Coordinates multiple subagents for parallel execution of tasks like code review, testing, and validation.

---

## Purpose

The orchestrator enables:
- Parallel execution of multiple subagents
- Result aggregation and comparison
- Strategy-based coordination (review, compete, collaborate)
- Winner selection based on scoring

---

## Implementation

**Main Script:** `g/tools/claude_subagents/orchestrator.zsh`

**Alternative Locations:**
- `tools/claude_subagents/orchestrator.zsh` (duplicate?)
- `tools/subagents/orchestrator.zsh` (alternative?)

**Supporting Tools:**
- `tools/claude_subagents/compare_results.zsh` - Result comparison

---

## Usage

```bash
orchestrator.zsh <strategy> <task> <num_agents>
```

**Parameters:**
- `strategy`: `review`, `compete`, or `collaborate`
- `task`: Command or script to run
- `num_agents`: Number of agents (1-10)

**Example:**
```bash
g/tools/claude_subagents/orchestrator.zsh \
  review \
  "tools/ci_check.zsh --view-mls" \
  3
```

---

## Strategies

### review
Multiple agents review the same task, results aggregated for consensus.

### compete
Multiple agents compete on the same task, winner selected based on score.

### collaborate
Multiple agents work together on different aspects of a task.

---

## Result Aggregation

Results are aggregated into JSON format:
- Agent ID, exit code, score
- stdout and stderr for each agent
- Winner selection based on score
- Summary written to `g/reports/system/claude_orchestrator_summary.json`

**Scoring:**
- Simple scoring: `100 - (exit_code * 10)`, minimum 0
- Agent with highest score wins

---

## Output

**Summary File:** `g/reports/system/claude_orchestrator_summary.json`

**Metrics Log:** `logs/claude_subagent_metrics.log`

**Format:**
```json
{
  "strategy": "review",
  "num_agents": 3,
  "timestamp": "2025-11-15T...",
  "winner": "agent2",
  "best_score": 100,
  "agents": [
    {"id": 1, "exit_code": 0, "score": 100, "stdout": "...", "stderr": "..."},
    ...
  ]
}
```

---

## Links

- **Implementation:** `g/tools/claude_subagents/orchestrator.zsh`
- **Agent System Index:** `/agents/README.md`
- **Test Scripts:** `tests/claude_code/orchestrator_review_smoke.zsh`

---

**Note:** This is a summary. For implementation details, see the orchestrator script.
