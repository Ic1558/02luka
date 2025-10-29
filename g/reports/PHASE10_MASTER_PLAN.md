# Phase 10 Master Plan – Public Mirror & Publishing Stack

## Objective
Establish a reliable public-facing mirror of operational data and documentation. Phase 10 combines four coordinated workflows—mirror generation, status visualization, documentation publishing, and integrity verification—to provide transparent, self-healing, and observable outputs for stakeholders.

## Workstreams Overview
| Phase | Focus | Primary Assets | Schedule (ICT) | Status |
|-------|-------|----------------|----------------|--------|
| **10.1** | Ops Mirror Pipeline | `run/generate_ops_status.cjs`, `.github/workflows/ops-mirror.yml`, `dist/ops/` artifacts | 02:50 daily | ✅ Live |
| **10.2** | Live Ops Status Board | `run/generate_ops_status.cjs`, `.github/workflows/ops-status.yml`, `dist/ops/status.html` | 03:10 daily | ✅ Live |
| **10.3** | Public Docs Publisher | `run/publish_docs.cjs`, `.github/workflows/public-docs.yml`, `dist/docs/` | 03:20 daily | ✅ Live |
| **10.4** | Mirror Integrity Monitor | `run/verify_mirror_integrity.cjs`, `.github/workflows/mirror-integrity.yml`, `dist/ops/integrity.*` | 04:00 daily | ✅ Live |

## Milestones & Dependencies
1. **Mirror Foundation (10.1)**
   - Generates latest OPS JSON/TSV and health endpoints in `dist/ops/`.
   - Must finish before downstream jobs trigger (`ops-status`, `public-docs`).
2. **Visualization Layer (10.2)**
   - Consumes `dist/ops/jobs.json` and manifest files to build the status dashboard.
   - Requires GitHub token for live data; falls back to cached metrics.
3. **Documentation Publishing (10.3)**
   - Converts Markdown from `docs/` and `g/manuals/` into static HTML, CSS, and JS.
   - Waits for mirror data to update so cross-links remain consistent.
4. **Integrity Enforcement (10.4)**
   - Crawls `/ops/*` and `/docs/*` endpoints, hashing and validating responses.
   - Emits alerts into `g/state/alerts/` and logs to `g/logs/ops_alerts.log`.

## Operational Cadence
- **Sequential Scheduling**: Workflows are spaced ten minutes apart to guarantee artifact availability (02:50 → 03:10 → 03:20 → 04:00 ICT).
- **Manual Overrides**: Each workflow supports `gh workflow run ... --ref main` for emergency redeploys.
- **Caching Strategy**: Mirror and docs generators include cache fallbacks so Phase 10 can succeed when upstream APIs are degraded.

## Runbook
1. **Pre-Flight (weekly or after incidents)**
   - `make ops-mirror-test`, `make ops-status-test`, `make docs-publish-test`, `make mirror-test` to ensure scripts succeed locally.
   - Verify Pages output by opening `dist/ops/_health.html` and `dist/docs/index.html` locally.
2. **Daily Monitoring**
   - Inspect `dist/ops/manifest.json` and `dist/docs/index.html` timestamps after workflows complete.
   - Review `g/logs/ops_alerts.log` for integrity failures; triage alerts stored under `g/state/alerts/`.
3. **Incident Response**
   - Re-run failed workflow with `gh workflow run` and check logs via `gh run view <id> --log`.
   - If mirror artifacts are corrupt, rebuild from cache using `./g/tools/build_ops_mirror.zsh --from-cache` before redeploying.
   - For documentation regressions, re-run `node run/publish_docs.cjs --dry-run` to inspect generated HTML before publishing.

## Observability & Reporting
- **Dashboards**: Phase 10.2 outputs `dist/ops/status.html` for live visualization; embed within ops portal if needed.
- **Telemetry**: Integrity monitor writes JSON/TSV plus alerts that feed into `g/tools/services/ops_digest.cjs` for daily digests.
- **Public Verification**: `_health.html`, `manifest.json`, and `integrity.json` provide external signals confirming latest publication time and hash health.

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Upstream API outage during 10.1 | Stale data cascades through phases | Use cache mode (`--from-cache`) and note fallback in daily digest. |
| GitHub rate limits for status board | Dashboard shows placeholder data | Provide `GITHUB_TOKEN` via secrets; retries with exponential backoff already implemented. |
| Large documentation delta | Longer publish times and potential link churn | Run `node run/publish_docs.cjs --dry-run` during large merges; integrity monitor will flag broken links. |
| Alert fatigue from integrity monitor | Missed critical failures | Tune severity routing in `g/tools/services/ops_digest.cjs` and aggregate duplicate alerts. |

## Completion Checklist
- [x] All four workflows green on `main`.
- [x] GitHub Pages hosts `/ops/` and `/docs/` outputs from latest builds.
- [x] Integrity reports stored under `dist/ops/integrity.*` with corresponding alerts in `g/state/alerts/`.
- [x] Phase 10 documentation cross-linked (`docs/OPS_MIRROR_PIPELINE.md`, `docs/OPS_STATUS_BOARD.md`, `docs/PUBLIC_DOCS_PUBLISHER.md`, `docs/MIRROR_INTEGRITY_MONITOR.md`).
- [x] Monitoring hooks integrated into Ops digest and alerting pathways.

## Change Log
- **2025-10-29** – Initial master plan captured: schedules, dependencies, runbook, and risk matrix documented.
