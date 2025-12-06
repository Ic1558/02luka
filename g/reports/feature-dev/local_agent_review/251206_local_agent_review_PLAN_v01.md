# Local Agent Review Implementation Plan

**Feature:** Local Code Review Tool (Cursor Agent Review Clone)  
**Date:** 2025-12-06  
**Scope:** Phase 1 - Core Review Functionality

---

## User Review Required

> [!IMPORTANT]
> **Phase 1 Scope**
> - Review git diffs (staged, unstaged, or between branches)
> - AI-powered code analysis using Claude API
> - Generate review reports with issue flags
> - Support both CLI and integration modes
> - **Goal:** Catch bugs before commit/merge, similar to Cursor's Agent Review

> [!NOTE]
> **Inspiration**
> - Based on [Cursor Agent Review](https://cursor.com/docs/agent/review)
> - Analyzes diffs line-by-line to catch bugs
> - Flags issues before merging
> - Provides suggestions and follow-ups

---

## Proposed Changes

### Core Implementation

#### [NEW] [tools/local_agent_review.py](file:///Users/icmini/02luka/tools/local_agent_review.py)

**Purpose:** Local code review tool that analyzes git diffs using AI

**Functions:**
```python
def get_diff(target: str = None, base: str = "HEAD") -> str:
    """Get git diff between base and target (or staged/unstaged)"""
    # Support modes:
    # - staged: git diff --cached
    # - unstaged: git diff
    # - branch: git diff base..target
    # - all: git diff HEAD

def analyze_diff(diff_content: str, context: dict = None) -> dict:
    """Send diff to Claude API for analysis"""
    # Use Claude API to review code changes
    # Return structured review with:
    # - issues: list of flagged problems
    # - suggestions: improvement recommendations
    # - summary: overall assessment

def generate_report(review: dict, output_format: str = "markdown") -> str:
    """Generate human-readable review report"""
    # Format: markdown, json, or terminal-friendly

def review_changes(mode: str = "staged", output_file: str = None) -> int:
    """Main CLI entry point"""
    # 0 = no issues, 1 = issues found, 2 = error
```

**Dependencies:**
- `anthropic` (Claude API client)
- `gitpython` or `subprocess` for git operations
- `pathlib`, `json`, `argparse` (stdlib)

---

### Configuration

#### [NEW] [g/config/local_agent_review.yaml](file:///Users/icmini/02luka/g/config/local_agent_review.yaml)

**Purpose:** Configuration for review behavior

```yaml
version: "1.0"

api:
  provider: "anthropic"  # Future: support openai, local models
  model: "claude-3-5-sonnet-20241022"
  max_tokens: 4096
  temperature: 0.3  # Lower = more focused on bugs

review:
  focus_areas:
    - "bug_detection"
    - "security_issues"
    - "performance_problems"
    - "code_quality"
    - "breaking_changes"
  
  severity_levels:
    - "critical"  # Blocks merge
    - "warning"   # Should fix
    - "suggestion" # Nice to have
    - "info"      # Informational

  ignore_patterns:
    - "**/*.md"  # Don't review markdown files
    - "**/test_*.py"  # Optional: skip test files
    - "g/reports/**"  # Skip generated reports

output:
  default_format: "markdown"
  report_dir: "g/reports/reviews"
  include_diff: true
  include_suggestions: true
```

---

### CLI Interface

#### [NEW] [tools/local_agent_review.zsh](file:///Users/icmini/02luka/tools/local_agent_review.zsh)

**Purpose:** Shell wrapper for easy CLI usage

**Usage:**
```bash
# Review staged changes
local-review staged

# Review unstaged changes
local-review unstaged

# Review all changes (staged + unstaged)
local-review all

# Review changes between branches
local-review branch main..feature-branch

# Review specific commit
local-review commit HEAD~1

# Save report to file
local-review staged --output g/reports/reviews/review_$(date +%Y%m%d_%H%M%S).md

# JSON output for automation
local-review staged --format json
```

**Exit codes:**
- `0` = No issues found
- `1` = Issues found (warnings or critical)
- `2` = Error (API failure, git error, etc.)

---

### Integration Points

#### [MODIFY] [tools/claude_hooks/pre_commit.zsh](file:///Users/icmini/02luka/tools/claude_hooks/pre_commit.zsh)

**Add optional review step:**
```bash
# Optional: Run local review before commit
if [[ "${LOCAL_REVIEW_ENABLED:-0}" == "1" ]]; then
    echo "🔍 Running local agent review..."
    python3 ~/02luka/tools/local_agent_review.py staged --quiet || {
        echo "⚠️  Review found issues. Continue anyway? [y/N]"
        read -q response
        [[ "$response" != "y" ]] && exit 1
    }
fi
```

#### [NEW] [tools/claude_hooks/post_commit.zsh](file:///Users/icmini/02luka/tools/claude_hooks/post_commit.zsh)

**Review last commit:**
```bash
#!/usr/bin/env zsh
# Optional: Review last commit after it's made

if [[ "${LOCAL_REVIEW_ENABLED:-0}" == "1" ]]; then
    python3 ~/02luka/tools/local_agent_review.py commit HEAD \
        --output "g/reports/reviews/commit_$(git rev-parse --short HEAD).md"
fi
```

---

### Report Format

#### [NEW] Report Structure

**Markdown format:**
```markdown
# Code Review Report

**Date:** 2025-12-06 20:00:00
**Target:** staged changes
**Files Changed:** 5 files, 42 insertions(+), 18 deletions(-)

---

## Summary

✅ **Overall:** Changes look good with minor suggestions

- **Critical Issues:** 0
- **Warnings:** 2
- **Suggestions:** 3
- **Info:** 1

---

## Issues Found

### 🔴 Critical (0)
None

### ⚠️ Warnings (2)

#### 1. Potential Null Pointer (governance/overseerd.py:115)
**Severity:** Warning  
**Line:** 115  
**Issue:** Variable `cmd` may be None if `task_meta.get("command")` returns None

**Suggestion:**
```python
cmd = task_meta.get("command") or ""
if not cmd:
    return {"approval": "No", "reason": "Empty command"}
```

#### 2. Missing Error Handling (agents/mary_router/gateway_v3_router.py:45)
**Severity:** Warning  
**Line:** 45  
**Issue:** File rename operation may fail silently

**Suggestion:** Add try/except around `wo_path.rename(target_path)`

---

### 💡 Suggestions (3)

1. Consider extracting magic number `3600` to named constant
2. Add type hints to function signature
3. Update docstring to reflect new behavior

---

### ℹ️ Info (1)

- Good use of pathlib for cross-platform compatibility

---

## Diff Summary

<details>
<summary>View full diff</summary>

\`\`\`diff
... (full diff content)
\`\`\`

</details>

---

**Review completed in:** 2.3s  
**Model:** claude-3-5-sonnet-20241022
```

---

### Storage Structure

#### [NEW] [g/reports/reviews/](file:///Users/icmini/02luka/g/reports/reviews/)

**Created automatically:**
```
g/reports/reviews/
├── review_20251206_200000.md  # Timestamped reviews
├── commit_a9027316.md         # Commit-specific reviews
└── .gitignore                 # Ignore review reports in git
```

---

## Implementation Tasks

### Phase 1: Core Functionality

- [ ] **T1:** Create `tools/local_agent_review.py`
  - [ ] Implement `get_diff()` function
  - [ ] Implement `analyze_diff()` with Claude API
  - [ ] Implement `generate_report()` function
  - [ ] Add CLI argument parsing
  - [ ] Add error handling and logging

- [ ] **T2:** Create configuration file
  - [ ] `g/config/local_agent_review.yaml`
  - [ ] Support environment variable overrides
  - [ ] Validate configuration on load

- [ ] **T3:** Create shell wrapper
  - [ ] `tools/local_agent_review.zsh`
  - [ ] Add to PATH or create alias
  - [ ] Support all review modes

- [ ] **T4:** Generate review reports
  - [ ] Markdown format (default)
  - [ ] JSON format (for automation)
  - [ ] Terminal-friendly output

- [ ] **T5:** Integration with git hooks
  - [ ] Optional pre-commit review
  - [ ] Optional post-commit review
  - [ ] Respect `LOCAL_REVIEW_ENABLED` env var

---

## Testing Strategy

### Unit Tests

- [ ] Test `get_diff()` with various git states
- [ ] Test `analyze_diff()` with mock API responses
- [ ] Test `generate_report()` with sample reviews
- [ ] Test error handling (API failures, git errors)

### Integration Tests

- [ ] Test CLI with staged changes
- [ ] Test CLI with unstaged changes
- [ ] Test CLI with branch comparison
- [ ] Test pre-commit hook integration
- [ ] Test report generation and storage

### Manual Testing

- [ ] Review a real feature branch
- [ ] Verify report format and readability
- [ ] Test with large diffs (>1000 lines)
- [ ] Test with empty diffs
- [ ] Test API rate limiting handling

---

## Dependencies

### Required

- `anthropic` Python package (Claude API)
- `gitpython` or `subprocess` (git operations)
- Python 3.8+

### Optional

- `rich` (for better terminal output)
- `pyyaml` (for YAML config parsing)

### Installation

```bash
pip install anthropic gitpython pyyaml rich
```

---

## Configuration

### Environment Variables

```bash
# Enable local review in git hooks
export LOCAL_REVIEW_ENABLED=1

# Override API key (if not in config)
export ANTHROPIC_API_KEY=sk-ant-...

# Override model
export LOCAL_REVIEW_MODEL=claude-3-5-sonnet-20241022
```

### Git Config (Optional)

```bash
# Add alias for convenience
git config --global alias.review '!python3 ~/02luka/tools/local_agent_review.py'

# Usage: git review staged
```

---

## Future Enhancements (Phase 2+)

- [ ] Support for OpenAI API (GPT-4)
- [ ] Support for local models (Ollama, LM Studio)
- [ ] Caching reviews for unchanged code
- [ ] Batch review multiple commits
- [ ] Integration with PR workflows
- [ ] Custom review rules/prompts
- [ ] Review history and trends
- [ ] Auto-fix suggestions (with approval)
- [ ] Integration with Cursor IDE
- [ ] Review templates for different file types

---

## Success Criteria

✅ **Phase 1 Complete When:**
- Can review staged/unstaged/branch diffs
- Generates readable markdown reports
- Flags critical issues and warnings
- Integrates with git hooks (optional)
- Handles errors gracefully
- Works with real code changes

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| API costs | Medium | Cache reviews, batch requests, optional feature |
| API rate limits | Medium | Implement retry logic, exponential backoff |
| False positives | Low | Allow user to dismiss, learn from feedback |
| Slow for large diffs | Medium | Split large diffs, show progress, timeout |
| Git state conflicts | Low | Validate git state before review |

---

## Related Tools

- `tools/codex_sandbox_check.zsh` - Pattern-based security checks
- `tools/pr_quickcheck.zsh` - PR validation
- `tools/pr_score.mjs` - PR scoring
- Cursor Agent Review (inspiration)

---

**Next Steps:**
1. Review this plan
2. Create SPEC document if needed
3. Begin implementation (T1-T5)
4. Test with real code changes
5. Document usage in README
