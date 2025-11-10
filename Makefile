.PHONY: help test smoke clean proof validate-zones quick-health quick-health-json

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

test: smoke ## Run all tests (alias for smoke)

smoke: ## Run smoke tests
	@bash scripts/smoke.sh

clean: ## Clean temporary files and build artifacts
	@echo "Cleaning temporary files..."
	@rm -rf tmp/ .tmp/ *.tmp
	@rm -rf dist/ build/
	@echo "✅ Cleaned"

proof: ## Generate daily proof report
	@echo "Generating proof report..."
	@mkdir -p g/reports/proof
	@echo "# Daily Proof - $$(date '+%Y-%m-%d')" > g/reports/proof/daily_proof_$$(date '+%Y%m%d').md
	@echo "" >> g/reports/proof/daily_proof_$$(date '+%Y%m%d').md
	@echo "## System Status" >> g/reports/proof/daily_proof_$$(date '+%Y%m%d').md
	@git log --oneline -5 >> g/reports/proof/daily_proof_$$(date '+%Y%m%d').md
	@echo "✅ Proof generated"

validate-zones: ## Validate repository structure
	@echo "Validating zones..."
	@test -d .github/workflows || { echo "❌ workflows missing"; exit 1; }
	@test -d docs || { echo "❌ docs missing"; exit 1; }
	@test -f package.json || { echo "❌ package.json missing"; exit 1; }
	@test -f scripts/smoke.sh || { echo "❌ smoke.sh missing"; exit 1; }
	@echo "✅ All zones validated"

install: ## Install CLS hooks (if not already installed)
	@echo "Checking CLS installation..."
	@if [ -f ~/.zshrc.d/02luka-cls-hooks.zsh ]; then \
		echo "✅ CLS hooks already installed"; \
	else \
		echo "❌ CLS hooks not found. Please run installation script."; \
	fi

quick-health: ## Run Phase15 Quick Health Check (human-readable)
	@TZ=Asia/Bangkok ./tools/phase15_quick_health.zsh

quick-health-json: ## Run Phase15 Quick Health Check (JSON output)
	@TZ=Asia/Bangkok ./tools/phase15_quick_health.zsh --json | jq .

status: ## Show system status
	@echo "═══════════════════════════════════════"
	@echo "02LUKA System Status"
	@echo "═══════════════════════════════════════"
	@echo ""
	@echo "Repository:"
	@git remote get-url origin 2>/dev/null || echo "  No remote configured"
	@echo "  Branch: $$(git branch --show-current)"
	@echo "  Latest: $$(git log --oneline -1)"
	@echo ""
	@echo "CLS Integration:"
	@test -f ~/.zshrc.d/02luka-cls-hooks.zsh && echo "  ✅ Hooks installed" || echo "  ❌ Hooks not installed"
	@test -f ~/02luka/memory/cls/learning_db.jsonl && echo "  ✅ Database: $$(wc -l < ~/02luka/memory/cls/learning_db.jsonl) entries" || echo "  ❌ Database not found"
	@echo ""
	@echo "Workflows:"
	@ls -1 .github/workflows/*.yml 2>/dev/null | wc -l | awk '{print "  Total: " $$1 " files"}'
	@echo ""
