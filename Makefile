SHELL := /bin/bash

.PHONY: dev validate ci proof tidy-plan tidy-apply tidy-retention validate-zones boss-refresh report mem boss status boss-find boss-daily report-menu menu audit-parent centralize centralize-dry centralize-rollback archive-legacy go-live-guarded

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

boss-daily:
	@./scripts/generate_boss_daily_html.sh

report-menu:
	@./scripts/new_ops_menu.zsh

menu: report-menu

.PHONY: validate-docs
validate-docs:
	@if command -v rg >/dev/null 2>&1; then \
	  rg -n --no-config --hidden --iglob '!**/.git/**' \
	     -g '!g/reports/**' -g '!boss/sent/**' -g '!**/legacy/**' \
	     -g '!**/MIGRATION_*.md' -g '!CLAUDE.md' -g '!FILE_DISCOVERY_PROTOCOL.md' -g '!Makefile' \
	     -e 'c/centralized|a/section/clc/protocols|docs/ai_ops' -- '**/*.md' \
	     && { echo "❌ Stale doc references found"; exit 1; } \
	     || echo "✅ docs OK"; \
	else \
	  ! grep -RInE --exclude-dir=.git --exclude-dir=reports \
	      --exclude-dir=sent --exclude-dir='*legacy*' \
	      --exclude='*MIGRATION_*.md' --exclude='CLAUDE.md' --exclude='FILE_DISCOVERY_PROTOCOL.md' --exclude='Makefile' \
	      'c/centralized|a/section/clc/protocols|docs/ai_ops' . \
	    || { echo "❌ Stale doc references found"; exit 1; }; \
	  echo "✅ docs OK"; \
	fi

.PHONY: validate-workspace
validate-workspace:
	@bash scripts/validate_workspace.sh
	@[ -x scripts/agent_audit.sh ] && scripts/agent_audit.sh || true

audit-parent:
	@bash $(HOME)/Library/02luka_runtime/tools/mirror_audit.sh

centralize:
	@bash scripts/centralize.sh run

centralize-dry:
	@bash scripts/centralize.sh dry-run

centralize-rollback:
	@bash scripts/centralize.sh rollback

archive-legacy:
	@bash scripts/archive_legacy.sh

go-live-guarded:
	@echo "== Phase D: Finalize & Push =="
	@git add -A
	@git commit -m "Centralization complete: symlinks+enforce+verify" || echo "Nothing to commit"
	@git tag -a v2.1 -m "Centralization verified (251011_033438)" || echo "Tag already exists"
	@echo "== Phase E: Archive Legacy Backups =="
	@make archive-legacy
	@echo "== Verification =="
	@make validate-workspace
	@make audit-parent
	@echo ""
	@echo "✅ Go-Live Guarded Complete"
	@echo "   Next: git push && git push --tags"
	@echo "   Monitor: make status"
