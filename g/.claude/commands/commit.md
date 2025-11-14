# /commit

**Goal:** Create a compliant commit after running pre-commit checks.

## Usage

- Provide: commit message (or let tool generate from changes)
- Format: `type(scope): subject` (Conventional Commits)

## Steps (tool-facing)

1) Run: `tools/claude_hooks/pre_commit.zsh`

2) Verify message format: `type(scope): subject`

   - Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`
   - Scope: optional, lowercase
   - Subject: imperative mood, no period

3) Commit with Co-Authored-By if agent-assisted:
   ```
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```

4) Optionally call `tools/claude_tools/metrics_collector.zsh` with `plan=0 review=0 commit=1`

## Example

```
/commit "feat(ops): integrate check_runner library"
```

This will:
- Run pre-commit hooks
- Validate commit message format
- Create commit with Co-Authored-By
- Record metrics (if available)
