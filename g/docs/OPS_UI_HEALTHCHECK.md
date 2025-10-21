# 02LUKA Ops UI — Health Check & Runbook

This guide keeps the **Cloudflare-fronted Ops UI** healthy:
- Stack: **Worker (ops.theedges.work)** ⇄ **cloudflared tunnel** ⇄ **HTTP→Redis bridge** ⇄ **Redis** ⇄ **CLC listener** (+ **nightly verify**).
- Control: `make up | logs | ps | deploy-worker | test-*`.

---

## 0) Fast facts

- **UI**: https://ops.theedges.work/
- **Bridge**: `/bridge` (private via cloudflared; requires `BRIDGE_TOKEN`)
- **Nightly verify**: 02:15 (TZ: Asia/Bangkok), writes report under `g/reports/*verification_precise*`
- **State file**: `g/state/clc_export_mode.env`
- **Metrics**: `g/metrics/clc_export_mode.json`

---

## 1) Day-0 / Post-deploy sanity

Run after `make up` + `make deploy-worker`:

```bash
# Stack status & logs
make ps
make logs

# Edge check (Worker alive)
curl -s https://ops.theedges.work/api/ping | jq .

# Flip CLC mode via Worker → Bridge → Redis → Listener
curl -s -X POST https://ops.theedges.work/api/clc/mode \
  -H 'content-type: application/json' -d '{"mode":"off"}' | jq .
grep -H . g/state/clc_export_mode.env

# Bridge local (optional)
curl -s -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/state | jq .
curl -s -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/metrics | jq .

# Nightly job (one-off invoke)
docker compose exec nightly sh -lc 'node /app/g/tools/services/nightly_verify_and_notify.cjs'
ls -1t g/reports/ | head

Expected:
	•	/api/ping returns { ok: true }
	•	clc_export_mode.env updates instantly
	•	New verification report appears in g/reports/

⸻

2) Day-1 routine (ops on call)

Do these once after first full night:

# Nightly timer ran?
docker compose logs nightly | tail -n 80

# Latest precise report
ls -1t g/reports/ | grep verification_precise_ | head -n1 | xargs -I{} sh -lc 'echo {}; sed -n "1,120p" g/reports/{}'

# Service health
make ps
docker compose logs --since=1h bridge clc_listener redis

Green signals:
	•	Nightly logs show "PASS"
	•	No restarts flapping
	•	Bridge logs show requests proxied from Worker

⸻

3) Daily quick checks (5 mins)
	1.	Edge OK

curl -s https://ops.theedges.work/api/ping | jq .   # HTTP 200 & ok:true


	2.	State & metrics readable

curl -s https://ops.theedges.work/api/state   | jq .
curl -s https://ops.theedges.work/api/metrics | jq .


	3.	Containers healthy

make ps


	4.	Nightly reports

ls -1t g/reports/ | head



⸻

4) Weekly deeper checks
	•	Review g/logs/* growth and rotate if needed.
	•	Verify tunnel uptime in Cloudflare Dashboard (Named Tunnel).
	•	Re-deploy Worker (make deploy-worker) only if config/code changed.
	•	Run end-to-end flip test:

curl -s -X POST https://ops.theedges.work/api/clc/mode \
  -H 'content-type: application/json' -d '{"mode":"drive"}' | jq .
grep -H . g/state/clc_export_mode.env



⸻

5) SLOs & alerts (lightweight)
	•	Availability (UI /api/ping): ≥ 99.5%
	•	Mode flip latency (UI→state): ≤ 2s p95
	•	Nightly run: must produce a fresh report by 02:20 daily

Alert when:
	•	/api/ping non-200 for 3 consecutive probes (1-min interval)
	•	No new verification_precise_* report by 02:20
	•	Bridge or listener container restarts >3 times within 15 minutes

(Integrate with your preferred monitor later; for now, cron + curl + Slack/Email is fine.)

⸻

6) Common issues → fixes

A) UI 502 "bridge error"
	•	Check tunnel/token and bridge:

docker compose logs cloudflared | tail -n 80
docker compose logs bridge | tail -n 120


	•	Confirm Worker var: BRIDGE_URL=https://ops.theedges.work/bridge
	•	Secret matches: wrangler secret put BRIDGE_TOKEN == .env BRIDGE_TOKEN

B) Mode doesn't flip (state not changing)
	•	Listener attached to Redis?

docker compose logs clc_listener | tail -n 120
docker compose exec redis redis-cli PUBSUB CHANNELS


	•	Publish directly to test:

docker exec -it redis redis-cli PUBLISH gg:clc:export_mode '{"mode":"off"}'



C) Nightly missing / failing
	•	Inspect log:

docker compose logs nightly | tail -n 200


	•	Run one-off:

docker compose exec nightly sh -lc 'node /app/g/tools/services/nightly_verify_and_notify.cjs'



D) Worker route mismatch
	•	Verify Workers Triggers → Route bound to ops.theedges.work/*
	•	Re-deploy Worker:

(cd ~/ops-02luka-worker && wrangler deploy)



⸻

7) Rollback & recovery
	•	Restart a svc:

docker compose restart bridge clc_listener nightly


	•	Recreate from scratch:

docker compose down && docker compose up -d --build


	•	Worker rollback: keep previous version in Workers (Dashboard → Deployments → Roll back).

⸻

8) Security hygiene
	•	Rotate BRIDGE_TOKEN quarterly or on suspicion of leak:
	•	Update .env (Compose) + wrangler secret put BRIDGE_TOKEN (Worker)
	•	docker compose up -d
	•	wrangler deploy
	•	Keep Redis closed from WAN (only internal Docker network).
	•	Guard ops.theedges.work with Cloudflare Access.

⸻

9) Operator quick commands

# Lifecycle
make up
make down
make ps
make logs

# Worker
make deploy-worker

# Tests
make test-state
make test-bridge

# E2E flip
curl -s -X POST https://ops.theedges.work/api/clc/mode \
  -H 'content-type: application/json' -d '{"mode":"local","dir":"/app/.exports_local"}' | jq .
grep -H . g/state/clc_export_mode.env


⸻

10) Change management

When changing bridge/Worker:
	1.	Update code → commit → docker compose up -d --build (for bridge)
	2.	wrangler deploy (for Worker)
	3.	Run Day-0 sanity again
	4.	Note the change in your ops log (date, what changed, quick outcome)

⸻

Appendix: Files & Paths
	•	Repo: ${REPO_HOST_PATH}
	•	State: g/state/clc_export_mode.env
	•	Metrics: g/metrics/clc_export_mode.json
	•	Nightly reports: g/reports/251021_verification_precise_*.md
	•	Docker compose: docker-compose.yml, .env, Makefile
	•	Worker: ~/ops-02luka-worker/{ops-worker.js, wrangler.toml}

