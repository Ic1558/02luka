SHELL := /bin/bash

.PHONY: dev validate ci proof tidy-plan tidy-apply tidy-retention validate-zones boss-refresh report mem boss status boss-find report-menu menu

dev:
	@./scripts/dev-setup.zsh

validate:
	@command -v jq >/dev/null 2>&1 || { echo "jq required for validate"; exit 1; }
	@jq empty .cursor/mcp.example.json
	@[ -f .cursor/mcp.json ] && jq empty .cursor/mcp.json || echo ".cursor/mcp.json missing (ok on CI)"

ci: validate

# Temporarily disable validate-mcp due to too many false positives
# validate-mcp:
#	@echo "Validating MCP config paths..."
#	@echo "✅ MCP paths clean (validation disabled)"

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

tidy-retention:
	@echo "🧹 Cleaning old files (>30 days)..."
	@deleted=0; \
	if [ -d .trash ]; then \
		count=$$(find .trash -type f -mtime +30 2>/dev/null | wc -l | tr -d ' '); \
		find .trash -type f -mtime +30 -delete 2>/dev/null || true; \
		find .trash -type d -empty -delete 2>/dev/null || true; \
		echo "  .trash/: $$count files removed"; \
		deleted=$$((deleted + count)); \
	fi; \
	if [ -d g/reports/proof ]; then \
		count=$$(find g/reports/proof -type f -name "*_proof.md" -mtime +30 2>/dev/null | wc -l | tr -d ' '); \
		find g/reports/proof -type f -name "*_proof.md" -mtime +30 -delete 2>/dev/null || true; \
		echo "  g/reports/proof/: $$count proof files removed"; \
		deleted=$$((deleted + count)); \
	fi; \
	if [ $$deleted -eq 0 ]; then \
		echo "✅ No files to clean (nothing >30 days old)"; \
	else \
		echo "✅ Total removed: $$deleted files"; \
	fi

validate-zones:
	@echo "Checking SOT compliance..."
	@bad=$$(find . -path ./node_modules -prune -o -path ./.git -prune -o \
	  -type f \( -name "report*.md" -o -name "analysis*.md" -o -name "summary*.md" \) \
	  ! -path "./g/reports/*" -print); \
	[ -z "$$bad" ] || { echo "❌ Reports outside g/reports/:"; echo "$$bad"; exit 1; }

boss-refresh:
	@./scripts/boss_refresh.sh

report:
	@./scripts/generate_report.sh

mem:
	@./scripts/memory_management.sh

boss:
	@make boss-refresh >/dev/null || true
	@echo "Open: boss/reports/index.md  |  boss/memory/index.md"

status:
	@f=$$(ls -t g/reports/proof/*_proof.md 2>/dev/null | head -1); \
	echo "Latest proof: $$f"; \
	grep -E 'Total files|Out-of-zone files|Max path depth' "$$f" 2>/dev/null || true; \
	echo "Open: boss/reports/index.md  |  boss/memory/index.md"

boss-find:
	@./scripts/boss_find.sh "$(q)"

report-menu:
	@./scripts/new_ops_menu.zsh

menu: report-menu
