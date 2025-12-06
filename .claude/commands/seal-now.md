# seal-now

**Alias:** `seal-now` (legacy: `seal`, `drs`)  
**Function:** `dev_seal()`  
**Script:** `tools/workflow_dev_review_save.py` (or `.zsh` fallback)

## Purpose

Full workflow chain for final safety check:
- Review code changes
- Create GitDrop snapshot
- Run session_save
- Complete safety workflow before push/merge/deployment

## Usage

```bash
seal-now
# or with options
seal-now --mode staged --strict
seal-now --offline --skip-gitdrop
seal-now --mode branch --base main --target feature

# Legacy aliases (backward compatible)
seal
drs
```

## Options

- `--mode`: staged, unstaged, last-commit, branch, range
- `--offline`: Run review without API calls
- `--strict`: Treat warnings as failures
- `--skip-gitdrop`: Skip GitDrop step
- `--skip-save`: Skip save step
- `--base`: Base ref (for branch/range)
- `--target`: Target ref (for branch/range)

## Characteristics

- ✅ Complete workflow (Review → GitDrop → Save)
- ✅ Safety-focused
- ✅ Used less frequently (final step)
- ✅ Covers 3 critical parts: review, safety, save
- ✅ Clear final step of work cycle

## When to Use

- End of session
- Before push/merge
- Before deployment
- Final safety check needed

## Workflow

1. **Review:** Local Agent Review on staged/unstaged changes
2. **GitDrop:** Create snapshot of working papers
3. **Save:** Run session_save.zsh

## Implementation

Defined in: `tools/git_safety_aliases.zsh`

```zsh
function dev_seal() {
    (
        cd "${LUKA_MEM_REPO_ROOT:-$HOME/02luka}" || return 1
        if [[ -f "./tools/workflow_dev_review_save.py" ]]; then
            python3 ./tools/workflow_dev_review_save.py "$@"
        elif [[ -f "./tools/workflow_dev_review_save.zsh" ]]; then
            # Fallback to .zsh if .py not available
            ./tools/workflow_dev_review_save.zsh "$@"
        else
            echo "❌ Workflow script not found in $(pwd)/tools/"
            return 1
        fi
    )
}
alias seal-now='dev_seal'
alias seal='seal-now'  # Legacy redirect
alias drs='dev_review_save'  # Legacy (calls dev_seal)
```

## Telemetry

Logs to: `g/telemetry/dev_workflow_chain.jsonl`

View status:
```bash
seal-status
# or
drs-status
```
