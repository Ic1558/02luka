SHELL := /bin/zsh

.PHONY: dev validate ci

dev:
	@./scripts/dev-setup.zsh

validate:
	@command -v jq >/dev/null 2>&1 || { echo "jq required for validate"; exit 1; }
	@jq empty .cursor/mcp.example.json
	@[ -f .cursor/mcp.example.json ] && jq empty .cursor/mcp.example.json || echo ".cursor/mcp.example.json missing (ok on CI)"

ci: validate
