# save-now

**Alias:** `save-now` (legacy: `save`)  
**Function:** `dev_save()`  
**Script:** `tools/session_save.zsh`

## Purpose

Lightweight save for quick state preservation:
- Snapshot memory between sessions
- Update `02luka.md`
- Commit memory repo
- No review overhead

## Usage

```bash
save-now
# or with arguments
save-now --option value

# Legacy alias (backward compatible)
save
```

## Characteristics

- ✅ Fast (no review overhead)
- ✅ No forced review
- ✅ Can use frequently
- ✅ Lightweight
- ✅ Perfect for mid-session saves

## When to Use

- Mid-session saves
- Memory/diary updates
- Quick state preservation
- Frequent updates needed

## Implementation

Defined in: `tools/git_safety_aliases.zsh`

```zsh
function dev_save() {
    (
        cd "${LUKA_MEM_REPO_ROOT:-$HOME/02luka}" || return 1
        if [[ -f "./tools/session_save.zsh" ]]; then
            ./tools/session_save.zsh "$@"
        else
            echo "❌ session_save.zsh not found in $(pwd)/tools/"
            return 1
        fi
    )
}
alias save-now='dev_save'
alias save='save-now'  # Legacy redirect
```
