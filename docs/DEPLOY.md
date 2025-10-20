# Deployment Guide

## Overview
This assistant stack is deployable to multiple targets with the same artifact. The API is an Express server, the UI is static assets, and all dependencies run offline by default.

## Cloudflare Pages + Worker Proxy
1. Build static assets (already plain HTML/CSS/JS) and upload to Pages project.
2. Deploy API via Cloudflare Worker or Pages Function using `apps/assistant-api/server.js` adapted to Worker runtime (TODO template forthcoming).
3. Configure environment variables:
   - `OPS_ATOMIC_URL`
   - `OPS_ATOMIC_TOKEN`
   - Connector secrets (`SLACK_TOKEN`, `CRM_TOKEN`, etc.) when ready.
4. Enable Zero Trust policies to restrict API routes by identity provider groups.
5. Run post-deploy hardening (see below).

## Ops Atomic Gate (OPS_ATOMIC_URL/TOKEN)
- CI workflow contains an Ops Atomic step. Provide secrets in GitHub repo settings (`Settings` → `Secrets and variables` → `Actions`).
- Optional CLI bootstrap:
  ```bash
  gh secret set OPS_ATOMIC_URL --body "https://ops.atomic/gate"
  gh secret set OPS_ATOMIC_TOKEN --body "<token>"
  ```
- When absent on non-main branches, the step emits a warning and continues. On `main`, the workflow fails until configured.

## GitHub Pages Mirror
1. Fork or mirror static UI to `gh-pages` branch.
2. Use `scripts/dev_server.sh` locally to generate assets and confirm functionality.
3. Configure GitHub Actions deployment job to copy `apps/assistant-ui/public` into `gh-pages` artifact.
4. Protect API endpoints with Basic Auth or Cloudflare Tunnel when exposing publicly.

## Vercel/Netlify Quick Path
- Deploy UI folder as static site.
- Use serverless function to wrap `apps/assistant-api/server.js` (requires light adaptation for request/response format).
- Set environment variables in project dashboard (Ops Atomic, connectors, RBAC settings).
- Configure health check on `/healthz` and uptime monitors.

## Local Zero-Install Server
1. Run `bash scripts/dev_server.sh` to launch API + UI locally.
2. Access `http://localhost:4000`.
3. Optional: configure `PORT` and `RATE_LIMIT_MAX` environment variables.

## Post-Deploy Hardening Checklist
- [ ] Enforce HTTPS/TLS termination.
- [ ] Configure OPS Atomic secrets and validate gating webhook.
- [ ] Provision RBAC roles in identity provider; map to API scopes.
- [ ] Enable request logging to centralized log sink.
- [ ] Schedule `memory.cleanup` and `memory.decay` jobs.
- [ ] Enable WAF rate limiting and anomaly detection.
- [ ] Document incident response contacts in `g/reports/ASSISTANT_IMPLEMENTATION_README.md`.

## Cost Controls & Monitoring
- Track latency and throughput via `/capabilities` diagnostics.
- Add Cloudflare Workers KV/Queues for asynchronous tasks (optional).
- Configure budgets in hosting provider dashboards and alerts for cost anomalies.
