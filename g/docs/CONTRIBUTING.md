# Contributing to 02LUKA

Thank you for your interest in contributing to 02LUKA!

## Quick Start

```bash
# Clone the repository
git clone git@github.com:Ic1558/02luka.git
cd 02luka

# Run smoke tests
bash scripts/smoke.sh

# Enable CLS (optional)
cls-on
```

## Development Workflow

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Make Changes

- Follow existing code style
- Add tests if applicable
- Update documentation

### 3. Test Locally

```bash
# Run smoke tests
npm test

# Verify CLS integration (if applicable)
cls-status
```

### 4. Commit Changes

Use conventional commit format:

```
type(scope): description

- Detail 1
- Detail 2

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types**: `feat`, `fix`, `docs`, `chore`, `ci`, `refactor`, `test`

### 5. Push and Create PR

```bash
git push origin feature/your-feature-name

# Create PR using GitHub CLI
gh pr create --title "Your PR title" --body "Description"
```

## Code Standards

### Shell Scripts

- Use `#!/bin/bash` shebang
- Set `set -euo pipefail` for safety
- Include error handling
- Add descriptive comments

### Workflows

- Use latest action versions
- **IMPORTANT**: Use `actions/upload-artifact@v4` (not v3)
- Add `workflow_dispatch` for manual triggers
- Use caching where applicable

### Documentation

- Keep docs up to date
- Use clear, concise language
- Include code examples
- Follow markdown best practices

## Testing

### Smoke Tests

All PRs must pass smoke tests:

```bash
bash scripts/smoke.sh
```

Tests check:
1. Directory structure
2. CLS integration files
3. Workflow files (artifact@v4)
4. Git repository health
5. Script permissions

### CI Workflows

GitHub Actions will automatically run:
- **validate**: Smoke tests
- **docs-links**: Documentation validation
- **ops-gate**: Operational checks

## Pull Request Process

1. **Update documentation** if needed
2. **Pass all CI checks** before requesting review
3. **Address review feedback** promptly
4. **Squash commits** if requested
5. **Celebrate** when merged! 🎉

## Troubleshooting

### CI Failures

```bash
# View latest run
gh run list --limit 1

# View logs
gh run view --log

# Re-run failed jobs
gh run rerun
```

### CLS Issues

```bash
# Check status
cls-status

# View logs
tail ~/02luka/g/logs/cls_phase3.log

# Restart hooks
exec zsh
cls-on
```

## Need Help?

- Check existing documentation in `docs/`
- Review closed issues on GitHub
- Ask questions in pull request comments

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to 02LUKA! 🚀
