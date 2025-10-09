# Agent: codex

**Memory:** [memory/codex/](../../memory/codex/)
**Owner:** codex
**Type:** Code & Automation Agent

## Scope
- Automated code generation and modifications
- Create and manage pull requests
- Execute predefined automation templates
- Apply code patches and refactoring
- Run smoke tests and validation
- Implement feature requests via templates
- Maintain codex prompt library

## Commands
- Create memo: `make mem agent=codex title="Note"`
- Search boss: `make boss-find q="…"`

## Key Files
- `.codex/templates/` - Codex prompt templates
- `scripts/proof_harness_simple.sh` - Validation
- Master prompts for automation workflows

## Integration
- GitHub PR automation (29 open PRs from previous work)
- Template-based code generation
- Automated testing and validation
- Change tracking and documentation
