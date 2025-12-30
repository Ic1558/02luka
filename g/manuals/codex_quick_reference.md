# Codex Quick Reference

## 1) When to Use Codex vs CLC
- Codex: tools/, apps/, g/ | 1-3 files | clear patch | low-medium risk
- CLC: locked zones | security-critical | 4+ files | design needed
- If unsure, start with CLC or ask for routing

## 2) codex-task Command Format
```
codex-task "Instruction: what to change, where, and why. Keep scope tight."
```

## 3) Common Patterns
- Add check:
  `codex-task "Add jq availability check to tools/foo.zsh after shebang; error + exit 1."`
- Fix bug:
  `codex-task "Fix null handling in tools/bar.zsh: guard missing value, keep output format."`
- Refactor:
  `codex-task "Refactor tools/baz.zsh: extract helper for parsing, keep CLI identical."`

## 4) Validation Steps
- Review diff: `git diff <file>`
- Run the script or a minimal repro
- Test an edge case (empty input, quotes, missing file)
- Confirm no regressions in outputs

## 5) Rollback If Needed
- If no new commits: `git checkout -- <file>`
- If a bad commit was made: `git reset --hard HEAD~1`
