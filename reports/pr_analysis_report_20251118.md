# Pull Request Analysis Report - 2025-11-18

This report analyzes open pull requests to identify root causes for conflicts, CI errors, and quality issues.

## Phase 1: Triage & Categorization

Based on the initial scan, the 11 open PRs are categorized as follows:

### Category 1: Recent CI/CD Protocol Updates (Likely Redundant)
These PRs seem to be related to the recent `bridge-selfcheck` update. They may be redundant or superseded by the changes already pushed to `main`.

- **#365: feat(ci): bridge self-check aligned with Context Protocol v3.2**
- **#364: feat(ci): bridge self-check aligned with Context Protocol v3.2**

### Category 2: Known Large & Complex PRs
These PRs were previously identified as having a very large number of changed files or lines, often a root cause for conflicts and review difficulty.

- **#358: feat(ops): Phase 3 Complete - LaunchAgent Recovery + Context Engineering Spec**
- **#310: Add WO timeline/history view in dashboard**

### Category 3: Needs Investigation (Potential CI Failures or Stale)
These PRs have an indeterminate status ("Loading…") or a low score, suggesting they are stale, have failing checks, or have merge conflicts.

- **#353: fix: relocate MLS overlay report to system folder**
- **#349: Add WO timeline/history view to dashboard**
- **#345: Dashboard Global Health Summary Bar**
- **#336: Link WO timeline and MLS lessons to detail view**
- **#328: Add dashboard WO history timeline view**
- **#306: Include filters in trading snapshot filenames**
- **#298: feat(trading): add trading journal CSV importer and MLS hook**

---

## Phase 2: Detailed Root Cause Analysis (In Progress)

The next step is to investigate each PR individually to find the specific root cause of its status.

**Analysis Plan:**
1.  **Investigate Redundant PRs (#365, #364):** Check if they are duplicates of recently merged work. Recommend closing if they are.
2.  **Analyze Large PRs (#358, #310):** Examine the file lists to see if they contain auto-generated or vendor files that should be in `.gitignore`. This is a common cause of conflicts and review friction.
3.  **Diagnose "Needs Investigation" PRs:** For each PR in this category, fetch its detailed status to check for:
    - **Merge Conflicts:** Identify the conflicting files.
    - **CI Check Failures:** Pinpoint the exact failing job and error message.
    - **Stale Branch:** Determine how far behind the target branch it is.
