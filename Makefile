SHELL := /bin/zsh

.PHONY: dev validate ci

dev:
	@./scripts/dev-setup.zsh

validate:
	@command -v jq >/dev/null 2>&1 || { echo "jq required for validate"; exit 1; }
	@jq empty .cursor/mcp.example.json
	@[ -f .cursor/mcp.example.json ] && jq empty .cursor/mcp.example.json || echo ".cursor/mcp.example.json missing (ok on CI)"

ci: validate

validate-mcp:
	@{ command -v rg >/dev/null 2>&1 && rg -n --fixed-strings ".cursor/mcp.json" --hidden --glob "!*example*" --glob "!Makefile" --glob "!scripts/apply_wrapper.sh" --glob "!.github/workflows/ci.yml" --glob "!.gitignore" || grep -Rna --exclude-dir=.git --exclude="*example*" --exclude=Makefile --exclude=scripts/apply_wrapper.sh --exclude=.github/workflows/ci.yml --exclude=.gitignore ".cursor/mcp.json" .; } 

	| grep -v '^.git/' && { echo "❌ Replace with .cursor/mcp.example.json"; exit 1; } || echo "✅ MCP paths clean"
