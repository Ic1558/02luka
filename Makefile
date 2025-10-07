SHELL := /bin/zsh

.PHONY: dev validate ci

dev:
	@./scripts/dev-setup.zsh

validate:
	@command -v jq >/dev/null 2>&1 || { echo "jq required for validate"; exit 1; }
	@jq empty .cursor/mcp.example.json
	@[ -f .cursor/mcp.json ] && jq empty .cursor/mcp.json || echo ".cursor/mcp.json missing (ok on CI)"

ci: validate
