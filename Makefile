ENV ?= .env

.PHONY: up down logs ps build
up:
	docker compose --env-file $(ENV) up -d --build

down:
	docker compose --env-file $(ENV) down

logs:
	docker compose --env-file $(ENV) logs -f

ps:
	docker compose --env-file $(ENV) ps

build:
	docker compose --env-file $(ENV) build

# Worker deploy (wrangler must be installed and logged in)
deploy-worker:
	cd ops-02luka-worker && printf '%s' "$$BRIDGE_TOKEN" | wrangler secret put BRIDGE_TOKEN && wrangler deploy

# Quick tests
test-state:
	docker exec -it redis redis-cli PUBLISH gg:clc:export_mode '{"mode":"off"}' >/dev/null && \
	grep -H . $(shell grep REPO_HOST_PATH .env | cut -d= -f2)/g/state/clc_export_mode.env || true

test-bridge:
	curl -fsS -X GET http://127.0.0.1:8788/state -H "x-auth-token: $$(grep BRIDGE_TOKEN .env | cut -d= -f2)" | jq .

# Health monitoring
test-health:
	curl -fsS https://ops.theedges.work/api/ping | jq .
	curl -fsS https://ops.theedges.work/api/state | jq .
	curl -fsS https://ops.theedges.work/api/metrics | jq .

show-health-metrics:
	@echo "=== Ops Health Metrics ==="
	@if [ -f "$$(grep REPO_HOST_PATH .env | cut -d= -f2)/g/metrics/ops_health.json" ]; then \
		jq '.summary' "$$(grep REPO_HOST_PATH .env | cut -d= -f2)/g/metrics/ops_health.json"; \
	else \
		echo "No health metrics found yet"; \
	fi

# Alerting & Reports
alert-once:
	docker compose exec ops_alerts sh -lc 'node /app/g/tools/services/ops_alerts.cjs && tail -n 50 /var/log/ops_alerts.log || true'

report-once:
	docker compose exec ops_daily sh -lc 'node /app/g/tools/services/ops_health_daily_report.cjs && tail -n 50 /var/log/ops_daily.log || true'

# Phase 8.0 Self-Healing
heal-once:
	docker compose exec ops_autoheal sh -lc 'node /app/g/tools/services/ops_autoheal.cjs && tail -n 50 /var/log/ops_autoheal.log || true'

maintenance-on:
	echo "$$(date -u +%FT%TZ) manual" > $(shell grep REPO_HOST_PATH .env | cut -d= -f2)/g/state/maintenance.flag; \
	echo "maintenance.flag created"

maintenance-off:
	rm -f $(shell grep REPO_HOST_PATH .env | cut -d= -f2)/g/state/maintenance.flag; \
	echo "maintenance.flag cleared"

show-heal-state:
	cat $(shell grep REPO_HOST_PATH .env | cut -d= -f2)/g/state/ops_autoheal_state.json 2>/dev/null || echo "(no state)"

# Phase 8.1 & 8.2 Maintenance UI
maint-on:
	curl -s -X POST https://ops.theedges.work/api/maintenance \
	  -H 'content-type: application/json' \
	  -d '{"action":"on","reason":"manual via make"}' | jq .

maint-off:
	curl -s -X POST https://ops.theedges.work/api/maintenance \
	  -H 'content-type: application/json' \
	  -d '{"action":"off","reason":"manual via make"}' | jq .

maint-status:
	curl -s https://ops.theedges.work/api/maintenance | jq .

# Phase 8.3-8.7 Feature Flag System
flag:
	ENV_FILE=.env g/tools/toggle_flag.sh $(VAR) $(VAL)

# Common flips
cfg-dryrun:
	$(MAKE) flag VAR=CFG_EDIT VAL=dryrun
cfg-off:
	$(MAKE) flag VAR=CFG_EDIT VAL=off
cfg-on:
	$(MAKE) flag VAR=CFG_EDIT VAL=on

correlation-shadow:
	$(MAKE) flag VAR=OPS_CORRELATE_MODE VAL=shadow
correlation-advice:
	$(MAKE) flag VAR=OPS_CORRELATE_MODE VAL=advice

predictive-shadow:
	$(MAKE) flag VAR=PREDICTIVE_MODE VAL=shadow
predictive-advice:
	$(MAKE) flag VAR=PREDICTIVE_MODE VAL=advice

federation-readonly:
	$(MAKE) flag VAR=FEDERATION_MODE VAL=readonly
federation-control:
	$(MAKE) flag VAR=FEDERATION_MODE VAL=control

auto-off:
	$(MAKE) flag VAR=AUTO_MODE VAL=off
auto-advice:
	$(MAKE) flag VAR=AUTO_MODE VAL=advice
auto-auto:
	$(MAKE) flag VAR=AUTO_MODE VAL=auto

# Lab page access
lab:
	@echo "Open https://ops.theedges.work/lab to view feature flags"

# Phase 8.3 Audit Trail Viewer
audit:
	@echo "Open https://ops.theedges.work/audit to view audit trail"

# Phase 8.5 AI Ops Digest
digest:
	@echo "Open https://ops.theedges.work/digest to view AI ops digest"

digest-now:
	curl -s -X POST https://ops.theedges.work/api/digest/generate | jq .

show-digest-path:
	curl -s https://ops.theedges.work/api/digest/latest | jq '.path'

# Phase 8.6 Incident Correlation
correlation:
	@echo "Open https://ops.theedges.work/correlation to view incident correlation"

correlation-now:
	curl -s -X POST https://ops.theedges.work/api/correlation/run | jq .

show-correlation:
	curl -s https://ops.theedges.work/api/correlation/latest | jq '.json.findings[0:3]'

# Phase 8.7 Predictive Maintenance
predict:
	@echo "Open https://ops.theedges.work/predict to view predictive maintenance"

predict-now:
	curl -s -X POST https://ops.theedges.work/api/predict/run | jq .

predict-latest:
	curl -s https://ops.theedges.work/api/predict/latest | jq '.json | {risk_level, score, horizon_hours, suggest}'

# Phase 8.8 Federation
federation:
	@echo "Open https://ops.theedges.work/federation to view federation overview"

federation-view:
	curl -s 'https://ops.theedges.work/api/federation/view' | jq '.peers[0]'

# Post-bootstrap verification
verify-ops:
	@echo "Running post-bootstrap verification..."
	./g/tools/services/ops_post_boot_verify.zsh

verify-ops-publish:
	@echo "Running post-bootstrap verification with Kim publish..."
	REDIS_URL?=redis://localhost:6379 \
	KIM_OUT_CH?=kim:out \
	KIM_CHAT_ID?=IC \
	./g/tools/services/ops_post_boot_verify.zsh

# Status viewing helpers
show-verify:
	@cat g/state/ops_verify_status.json 2>/dev/null || echo '{ "ok": false, "error": "no_status" }'

verify-and-show:
	@$(MAKE) -s verify-ops && $(MAKE) -s show-verify || { $(MAKE) -s show-verify; exit 1; }

open-health:
	@echo "Opening /health…"; open "https://ops.theedges.work/health" 2>/dev/null || xdg-open "https://ops.theedges.work/health"

# Phase 9.0 Autonomy
auto-off:
	@$(MAKE) flag VAR=AUTO_MODE VAL=off && docker compose restart bridge

auto-advice:
	@$(MAKE) flag VAR=AUTO_MODE VAL=advice && docker compose restart bridge

auto-auto:
	@$(MAKE) flag VAR=AUTO_MODE VAL=auto && docker compose restart bridge

auto-now:
	@node g/tools/services/ops_autonomy.cjs || true

show-auto-status:
	@cat g/state/ops_autonomy_status.json 2>/dev/null || echo '{"ok":false,"error":"no_status"}'

# optional: containerized loop (5-min) without docker socket
auto-loop:
	@echo "*/5 * * * * cd $(PWD) && AUTO_MODE=$${AUTO_MODE:-advice} node g/tools/services/ops_autonomy.cjs >> g/logs/ops_autonomy.log 2>&1" | crontab -
	@echo "Autonomy loop installed in cron (every 5 min)"

validate-zones:
	@echo "Validation logic for zones goes here"
# Phase 8.4 Config Center
config:
	@echo "Open https://ops.theedges.work/config to view configuration center"

config-dryrun:
	curl -s -X POST https://ops.theedges.work/api/config/apply -H 'content-type: application/json' -d '{"env":{"CFG_EDIT":"dryrun","OPS_CORRELATE_MODE":"shadow"},"mode":"dryrun"}' | jq .

config-apply:
	curl -s -X POST https://ops.theedges.work/api/config/apply -H 'content-type: application/json' -H 'x-confirm: yes' -d '{"env":{"CFG_EDIT":"on","OPS_CORRELATE_MODE":"shadow"},"mode":"on","confirm":true}' | jq .

config-view:
	curl -s https://ops.theedges.work/api/config/view | jq '.config.env'
