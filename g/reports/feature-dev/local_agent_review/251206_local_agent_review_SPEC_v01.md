# Local Agent Review Specification

**Feature:** Local Code Review Tool (Cursor Agent Review Clone)
**Date:** 2025-12-06
**Status:** Revised
**Version:** 1.2 (Refined Logic & Safety)

---

## 1. System Overview

The Local Agent Review tool is a Python-based CLI utility that uses the Anthropic API to perform AI-powered code reviews on local git repositories. It mimics the functionality of Cursor's Agent Review but operates entirely within the local CLI environment, providing actionable feedback on code changes before they are committed or merged.

## 2. Architecture

### 2.1 Core Components

*   **Git Interface (`GitInterface`)**: Handles all git operations (diff generation, commit hash retrieval).
*   **Review Engine (`ReviewEngine`)**: Orchestrates the review process, managing context and API interaction.
*   **LLM Client (`LLMClient`)**: Abstraction layer for the AI provider (initially Anthropic).
*   **Report Generator (`ReportGenerator`)**: Formats the analysis results into Markdown, JSON, or Console output.
*   **Config Manager (`ConfigManager`)**: Loads and validates configuration from YAML and environment variables.
*   **Privacy Guard (`PrivacyGuard`)**: Pre-flight checks to prevent accidental exfiltration of secrets or binary data.

### 2.2 Data Flow

1.  **CLI Input**: User invokes `local-review <target>`.
2.  **Config Load**: `ConfigManager` loads rules and API keys.
3.  **Git Diff**: `GitInterface` retrieves the diff for the specified target.
4.  **Filtering & Safety**: `PrivacyGuard` filters secrets/binaries; `GitInterface` applies size limits.
5.  **Analysis**: `ReviewEngine` constructs the prompt and sends it to `LLMClient`.
6.  **Response Parsing**: `ReviewEngine` parses the structured JSON response from the LLM.
7.  **Report Generation**: `ReportGenerator` creates the output artifact (and manages report rotation).
8.  **Output**: Result is displayed to stdout or saved to a file. Exit code set based on findings.

## 3. Detailed Design

### 3.1 Python Modules

#### `tools/local_agent_review.py` (Main Entry Point)

```python
class LocalAgentReview:
    def __init__(self):
        self.config = ConfigManager()
        self.git = GitInterface()
        self.llm = LLMClient(self.config)
        self.engine = ReviewEngine(self.llm, self.config)
        self.guard = PrivacyGuard(self.config)

    def run(self, mode: str, output_format: str, output_file: str = None):
        # 1. Check Acknowledgement (Skip if offline)
        # 2. Get Diff
        # 3. Privacy Scan (Secrets/Binaries)
        # 4. API Call (if not dry-run)
        # 5. Report & Exit
```

#### `tools/lib/privacy_guard.py`

```python
class PrivacyGuard:
    def scan_diff(self, diff_text: str) -> List[SecurityWarning]:
        """Regex-based scan for API keys, tokens, and PII."""
        pass
    
    def is_safe_file(self, filename: str) -> bool:
        """Checks against ignore patterns and binary extensions."""
        pass
```

### 3.2 Data Structures

#### `ReviewResult` (Pydantic Model or Dict)

```python
{
    "summary": "Brief overview of changes...",
    "issues": [
        {
            "file": "path/to/file.py",
            "line": 123,
            "severity": "critical|warning|suggestion|info",
            "category": "bug|security|performance|style",
            "description": "Detailed description of the issue",
            "suggestion": "Code snippet or fix instructions"
        }
    ],
    "metrics": {
        "complexity": "low|medium|high",
        "risk": "low|medium|high"
    }
}
```

### 3.3 Prompt Engineering

**System Prompt:**
```text
You are an expert senior software engineer performing a code review.
Your goal is to catch bugs, security vulnerabilities, and performance issues.
Be concise, constructive, and focus on high-value feedback.
Output your review in strictly valid JSON format matching the specified schema.
```

**User Prompt:**
```text
Review the following git diff.
Context: {context_description}
Focus Areas: {focus_areas_from_config}

DIFF:
{diff_content}
```

### 3.4 Configuration Schema (`g/config/local_agent_review.yaml`)

```yaml
api:
  provider: "anthropic"
  model: "claude-3-5-sonnet-20241022"
  max_tokens: 4096
  temperature: 0.2

review:
  focus_areas: ["bugs", "security", "performance"]
  ignore_patterns: ["**/*.lock", "**/*.md", "**/*.min.js", "dist/**"]
  context_lines: 3
  # Safety settings
  exclude_files: ["*.pem", "*.key", ".env*"]
  redact_secrets: true
  # Review strictness
  strict_mode: false # If true, warnings exit with code 1

output:
  format: "markdown"
  save_dir: "g/reports/reviews"
  # Retention only applies to auto-generated files in save_dir
  retention_count: 20 
```

### 3.5 Limits & Chunking (Phase 1 Strategy)

**Strategy:** Partial Review (Truncation)
**Rationale:** Phase 1 targets MVP. Multi-call chunking introduces report merging complexity deferred to Phase 2.

1.  **Diff Size Limit:**
    *   **Soft Limit:** 60kb text (approx 15k tokens). Safe buffer for response generation.
    *   **Action:** If exceeded, apply **Smart Truncation**.
2.  **Smart Truncation:**
    *   **Filter:** Drop lockfiles, minified code, SVGs, large data files first.
    *   **Prioritize:** Source code (`.py`, `.ts`, `.rs`, etc.) gets highest priority.
    *   **Truncate:** If still over limit, cut off at file boundaries (do not split files).
3.  **Warning:** Report must explicitly state: "⚠️ PARTIAL REVIEW: Diff exceeded size limit. Only first N files analyzed."

## 4. Interface Specifications

### 4.1 CLI Arguments

*   `mode`:
    *   `staged` (default): `git diff --cached`
    *   `unstaged`: `git diff` (working tree vs index)
    *   `branch [base]`: Reviews `base..HEAD`. If `base` omitted, defaults to `origin/main` (or `main/master` if local only).
    *   `range <base> <target>`: Reviews `base..target`.
*   `--format`: `markdown`, `json`, `console`
*   `--output`: Custom path. **Note:** Custom paths are NEVER rotated/deleted.
*   `--quiet`: Suppress stdout (useful for hooks).
*   `--verbose`: Debug logging.
*   `--dry-run` / `--offline`: Perform local checks (secrets, lint) only; do not call API.
*   `--no-interactive`: Disable all user prompts (auto-fail on critical).
*   `--strict`: Override config to enable strict mode (warnings = error).

### 4.2 Environment Variables

*   `LOCAL_REVIEW_ACK`: `1` (Required for API calls).
*   `LOCAL_REVIEW_ENABLED`: `1` to enable hooks.
*   `ANTHROPIC_API_KEY`: API key.

### 4.3 Git Hooks Behavior

*   **Mode:** Always runs with `--no-interactive`.
*   **Logic:**
    *   **Critical Issues:** Always Exit `1` (Block).
    *   **Warnings:**
        *   If `strict_mode=true` (or `--strict`): Exit `1`.
        *   Default: Print warning to stderr, Exit `0` (Allow).
*   **Paths:** Must use `$(git rev-parse --show-toplevel)` for relative path resolution.

## 5. Error Handling & Exit Codes

*   **0**: Success (No issues, or allowed warnings).
*   **1**: Review Failed (Critical issues, or warnings in strict mode).
*   **2**: System Error (API, Git, Config).
*   **3**: Security Block (Local secret detection).

## 6. Security Considerations

*   **Consent:** Tool fails if `LOCAL_REVIEW_ACK` is not set **UNLESS** `--offline` or `--dry-run` is used.
*   **Secret Scanning:** `PrivacyGuard` runs *before* API call. If potential secrets are found, abort immediately (Exit 3).
*   **Data Privacy:** User is responsible for not reviewing internal-only proprietary IP.

## 7. Dependencies

*   `anthropic`: Official SDK.
*   `gitpython`: Robust git interaction.
*   `rich`: Beautiful terminal output.
*   `pyyaml`: Config parsing.
*   `pydantic`: Data validation.

## 8. Testing Plan

### 8.1 Unit Tests
*   **Mock LLM:** Use static JSON fixtures for API responses.
*   **Privacy Guard:** Test secret regexes against known dummy keys.
*   **Truncation:** Feed 100kb dummy diff, verify "Smart Truncation" selects correct files and warns.

### 8.2 Integration Tests
*   **Binary Skip:** Commit a binary file, verify it's excluded from diff.
*   **Hook Simulation:** Run wrapper script with strict mode on/off.
*   **Retention:** Verify custom output paths are NOT deleted during rotation.

---
**Approved By:** [Pending]
**Date:** [Pending]
