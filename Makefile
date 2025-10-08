SHELL := /bin/zsh

.PHONY: dev validate ci validate-mcp proof tidy-plan tidy-apply validate-zones boss-refresh report mem boss

dev:
	@./scripts/dev-setup.zsh

validate:
	@command -v jq >/dev/null 2>&1 || { echo "jq required for validate"; exit 1; }
	@jq empty .cursor/mcp.example.json
	@[ -f .cursor/mcp.example.json ] && jq empty .cursor/mcp.example.json || echo ".cursor/mcp.example.json missing (ok on CI)"

ci: validate

validate-mcp:
	@BAD=.cursor/mcp.; EXT=json; PAT="$BAD$EXT"; \
	{ command -v rg >/dev/null 2>&1 && rg -n --fixed-strings "$PAT" --hidden --glob "!*example*" --glob "!.gitignore" || grep -Rna --exclude-dir=.git --exclude="*example*" --exclude=.gitignore "$PAT" .; } \
	| grep -v "^.git/" && { echo "❌ Replace with .cursor/mcp.example.json"; exit 1; } || echo "✅ MCP paths clean"

proof:
	@./scripts/proof_harness_simple.sh
	@echo "✅ Latest report: ./g/reports/proof/"
	@ls -t ./g/reports/proof/*.md | head -1

tidy-plan:
	@./scripts/generate_moveplan.zsh

tidy-apply:
	@PLAN=$$(ls -t g/reports/proof/*_MOVEPLAN.tsv 2>/dev/null | head -1); \
	if [ -z "$$PLAN" ]; then echo "❌ No move plan found. Run 'make tidy-plan' first."; exit 1; fi; \
	./scripts/apply_moveplan.zsh "$$PLAN" --apply; \
	make proof

validate-zones:
	@echo "Checking SOT compliance..."
	@bad=$$(find . -path ./node_modules -prune -o -path ./.git -prune -o \
	  -type f \( -name "report*.md" -o -name "analysis*.md" -o -name "summary*.md" \) \
	  ! -path "./g/reports/*" -print); \
	[ -z "$$bad" ] || { echo "❌ Reports outside g/reports/:"; echo "$$bad"; exit 1; }
	@bad=$$(find . -path ./node_modules -prune -o -path ./.git -prune -o \
	  -type f -name "session_*.md" ! -path "./memory/*" -print); \
	[ -z "$$bad" ] || { echo "❌ Sessions outside memory/<agent>/:"; echo "$$bad"; exit 1; }
	@echo "✅ All zones compliant"

boss-refresh:
	@./scripts/generate_boss_catalogs.sh

report:
	@f=$$(./scripts/new_report.zsh "$(name)"); echo "✅ $$f"
	@make boss-refresh >/dev/null || true

mem:
	@f=$$(./scripts/new_mem.zsh "$(agent)" "$(title)"); echo "✅ $$f"
	@make boss-refresh >/dev/null || true

boss:
	@make boss-refresh >/dev/null || true
	@echo "Open: boss/reports/index.md  |  boss/memory/index.md"
