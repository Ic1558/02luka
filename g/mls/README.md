# MLS (Machine Learning System) Ledger

## Overview

The MLS (Machine Learning System) Ledger is a structured knowledge tracking system that captures solutions, failures, improvements, patterns, and antipatterns from CI/CD workflows and other automated systems.

## Directory Structure

```
mls/
├── ledger/           # Daily JSONL files (append-only)
│   └── YYYY-MM-DD.jsonl
├── status/           # Status and tracking files
│   ├── mls_validation_streak.json
│   └── YYYYMMDD_ci_cls_codex_summary.{yml,json}
└── schema/          # JSON schemas
    └── mls_event.schema.json
```

## File Formats

### Ledger Files (`ledger/YYYY-MM-DD.jsonl`)

Each line is a valid JSON object representing a single MLS event:

```json
{
  "ts": "2025-11-10T03:20:44+0700",
  "type": "solution",
  "title": "CLS strict CI uploads artifact",
  "summary": "Added stage+guard; artifact selfcheck-report now stable",
  "source": {
    "producer": "cls",
    "context": "ci",
    "repo": "Ic1558/02luka",
    "run_id": "19213412721",
    "workflow": "cls-ci.yml",
    "sha": "fd066bc9...",
    "artifact": "selfcheck-report",
    "artifact_path": "/__artifacts__/cls_strict/selfcheck.json"
  },
  "links": {
    "followup_id": null,
    "wo_id": null
  },
  "tags": ["bridge","artifact","strict","stable"],
  "author": "gg",
  "confidence": 0.9
}
```

**Event Types:**
- `solution`: Successful solutions to problems
- `failure`: Documented failures and their causes
- `improvement`: Incremental improvements
- `pattern`: Reusable patterns
- `antipattern`: Patterns to avoid

### Status Files

#### `mls_validation_streak.json`

Tracks consecutive successful MLS validations:

```json
{
  "ts": "2025-11-10T03:18:44Z",
  "last_status": "ok",
  "success_streak": 1
}
```

- `last_status`: `"ok"` or `"fail"`
- `success_streak`: Number of consecutive successful validations
- Resets to 0 on failure
- After 3 consecutive greens (streak ≥ 3), validation failures will cause CI runs to fail

#### Summary Files (`status/YYYYMMDD_ci_cls_codex_summary.{yml,json}`)

Comprehensive status summaries generated after each strict CI run, including:
- Workflow status
- Artifact information
- Run metadata
- Summary statistics

## Validation

### Schema-Lite (Daily CI Runs)

Fast, lightweight validation using `jq` (no npm dependencies):

- Validates required fields and basic types
- Checks enum values (type, producer)
- Validates confidence range (0-1)
- Runs on every strict CI run

**Location:** `cls-ci.yml` and `bridge-selfcheck.yml` → `Validate MLS (jq schema-lite, no npm)`

### Deep Validation (Weekly)

Full JSON Schema validation using `ajv-cli`:

- Validates against `mls/schema/mls_event.schema.json`
- Checks all fields, types, and constraints
- Runs weekly via `mls-deep-validate.yml` workflow
- Validates last 7 days of ledger files

**Location:** `.github/workflows/mls-deep-validate.yml`

## Enforcement Policy

### Streak-Based Enforcement

After 3 consecutive successful validations (streak ≥ 3):

1. **Validation failures will cause CI runs to fail**
   - Step: `Enforce MLS validation after 3 green runs`
   - Condition: `streak >= 3 && last_status != "ok"`
   - Action: `exit 1` (fails the run)

2. **Before 3 greens:**
   - Validation errors are logged but don't fail the run
   - `continue-on-error: true` on validation step
   - Allows system to stabilize during initial runs

### Reset Streak

To reset the streak (start fresh):

```bash
jq -n '{ts: (now|todate), last_status:"fail", success_streak:0}' > mls/status/mls_validation_streak.json
git add mls/status/mls_validation_streak.json
git commit -m "chore(ci): reset MLS streak"
```

## Usage

### Adding MLS Events

Use the `mls_add.zsh` script:

```bash
~/02luka/tools/mls_add.zsh \
  --type solution \
  --title "CLS artifact stable" \
  --summary "artifact uploaded ok; bridge healthy" \
  --producer cls \
  --context ci \
  --repo Ic1558/02luka \
  --run-id "$(cat ~/02luka/__artifacts__/last_strict_run.txt)" \
  --workflow cls-ci.yml \
  --sha "$(git -C ~/02luka/g rev-parse HEAD)" \
  --artifact selfcheck-report \
  --artifact-path "$HOME/02luka/__artifacts__/cls_strict/selfcheck.json" \
  --tags "strict,artifact,bridge" \
  --author gg \
  --confidence 0.9
```

### Viewing MLS Events

```bash
# View last 10 events from today's ledger
DAY=$(date +%Y-%m-%d)
tail -n 10 mls/ledger/$DAY.jsonl | jq .

# View streak status
cat mls/status/mls_validation_streak.json | jq .

# View latest summary
ls -t mls/status/*_ci_cls_codex_summary.json | head -1 | xargs jq .
```

### CI Integration

MLS events are automatically written on strict CI success:

- **Workflow:** `cls-ci.yml` and `bridge-selfcheck.yml`
- **Step:** `Write MLS event (strict success)`
- **Condition:** `needs.sanity.outputs.ci_strict == '1'`
- **Location:** After artifact upload, before status summary

## Artifacts

### Available Artifacts

1. **`selfcheck-report`**
   - Bridge self-check results
   - Retention: 14 days
   - Path: `output/reports/selfcheck.json`

2. **`mls-validation-streak`**
   - Current validation streak status
   - Retention: 30 days
   - Path: `mls/status/mls_validation_streak.json`
   - Uploaded even on validation errors (`always()` condition)

3. **`escalation-prompt`** (if critical/warning issues)
   - Escalation prompts for CLC/Mary/GC
   - Retention: 7 days
   - Path: `output/alerts/escalation_prompt.txt`

## Best Practices

1. **Write events on success:** Only write MLS events when workflows succeed
2. **Include context:** Always include `run_id`, `workflow`, `sha`, and `artifact` in source
3. **Use appropriate types:** Choose the right event type (solution, failure, improvement, etc.)
4. **Tag appropriately:** Use consistent tags for easy filtering
5. **Set confidence:** Use realistic confidence scores (0.0-1.0)

## Troubleshooting

### "No valid JSON found in ledger"

- Check that ledger file exists: `ls -la mls/ledger/$(date +%Y-%m-%d).jsonl`
- Verify last line is valid JSON: `tail -n 1 mls/ledger/$(date +%Y-%m-%d).jsonl | jq .`
- Ensure newline at end: `printf '%s\n'` when writing

### "Schema validation failed"

- Check required fields are present
- Verify enum values (type, producer)
- Ensure confidence is 0-1
- Run deep validation: `gh workflow run mls-deep-validate.yml`

### "Streak not incrementing"

- Check streak file exists: `cat mls/status/mls_validation_streak.json`
- Verify validation step succeeded
- Check logs for "MLS streak: N (last=ok|fail)"

## Related Files

- **Tools:** `~/02luka/tools/mls_add.zsh`
- **CI Check:** `~/02luka/tools/ci_check.zsh`
- **Workflows:**
  - `cls-ci.yml` - CLS CI workflow
  - `bridge-selfcheck.yml` - Bridge Self-Check workflow
  - `mls-deep-validate.yml` - Weekly deep validation

## References

- JSON Schema: `mls/schema/mls_event.schema.json`
- Status summaries: `mls/status/YYYYMMDD_ci_cls_codex_summary.{yml,json}`
- Streak tracking: `mls/status/mls_validation_streak.json`

