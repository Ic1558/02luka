# PR Automation Toolkit

`scripts/pr_create_auto_merge.sh` automates the workflow of pushing your branch,
creating a GitHub pull request, enabling auto-merge, and embedding a diff/risk
summary in the PR body.

## Requirements
- GitHub CLI (`gh`) installed and authenticated (`gh auth login`).
- Clean working tree (no staged or unstaged changes).
- Branch with commits that diverge from the base branch (default `main`).

## Usage
```bash
# Basic usage
scripts/pr_create_auto_merge.sh

# Custom base branch and merge strategy
scripts/pr_create_auto_merge.sh --base develop --merge-method merge

# Preview without creating a PR
scripts/pr_create_auto_merge.sh --dry-run
```

## Options
| Flag | Description |
|------|-------------|
| `--base <branch>` | Base branch to compare against (default: `main`). |
| `--remote <name>` | Git remote to push to (default: `origin`). |
| `--title <title>` | Override the PR title (defaults to latest commit). |
| `--merge-method <type>` | Auto-merge strategy (`squash`, `merge`, `rebase`). |
| `--body-file <path>` | Use a custom PR body template. |
| `--label <label>` | Apply labels (repeat flag for multiple labels). |
| `--draft` | Create the PR as a draft. |
| `--no-auto-merge` | Skip enabling auto-merge. |
| `--dry-run` | Show the generated summary without creating a PR. |

## Generated Summary
The script automatically adds:
- Commit list between the base and current branch.
- `git diff --stat` output.
- Parsed diff metrics (files changed, insertions, deletions).
- Risk level heuristic (Low/Medium/High) with notes.
- List of changed file paths.

## Recommended Flow
1. Ensure tests pass locally.
2. Run `scripts/pr_create_auto_merge.sh --dry-run` to review the summary.
3. Execute without `--dry-run` once satisfied.
4. Monitor the PR to confirm checks pass and auto-merge completes.
