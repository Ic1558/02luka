# Codex Master Readiness

**Status:** ✅ Ready for development

## 1) Core Services
- ✅ boss-api server (port 4000)
- ✅ API health check (`/healthz`)
- ✅ Capabilities endpoint (`/api/capabilities`)
- ✅ MCP Docker gateway (port 5012)
- ✅ MCP FS server (port 8765)

## 2) Health & Smoke
- **Runbook:** `bash ./run/smoke_api_ui.sh`
- **Expected:** PASS on critical services (API, UI, MCP)
- **Optional services:** May show WARN status (Paula, Ollama)

## 3) Gateway Configuration (Optional)
- **AI Gateway:** Set `AI_GATEWAY_URL` and `AI_GATEWAY_KEY` environment variables
- **Agents Gateway:** Set `AGENTS_GATEWAY_URL` and `AGENTS_GATEWAY_KEY` environment variables
- Default: Local-only mode (no external gateways required)

## 4) Documentation
- **API Endpoints:** `docs/api_endpoints.md`
- **System Overview:** `docs/02luka.md`
- **Context Engineering:** `docs/CONTEXT_ENGINEERING.md`

## 5) Quick Verification Commands
```bash
# Health check
curl -s http://127.0.0.1:4000/healthz | jq .

# Capabilities
curl -s http://127.0.0.1:4000/api/capabilities | jq .keys

# MCP Docker health
curl -s http://127.0.0.1:5012/health | jq .

# Full smoke test
bash ./run/smoke_api_ui.sh
```

## 6) Development Workflow
1. **Start services:** Follow docs/02luka.md morning routine
2. **Run smoke tests:** Verify all critical services
3. **Make changes:** Follow atomic commit guidelines
4. **Pre-push:** Ensure smoke tests still pass

## 7) CI/CD (Optional)
- Manual workflow triggers available
- Smoke tests can be automated via GitHub Actions
- See `.github/workflows/` for examples

## 8) Duplicate Clone Prevention

**Problem:** Multiple repository clones can cause confusion and stale code execution.

**Check for duplicates before development:**
```bash
# Preflight automatically detects duplicates
bash ./.codex/preflight.sh

# Manual check
bash ./scripts/repo_root_resolver.sh
```

**Common duplicate locations:**
- `~/dev/02luka-repo` (legacy clone)
- `~/local-repos/02luka-repo` (local testing)
- `~/Desktop/02luka-repo` (temporary clone)
- `~/Downloads/02luka-repo` (from archive)
- `/workspaces/02luka-repo` (devcontainer)

**Risks of duplicate clones:**
- ⚠️ LaunchAgents may execute code from stale clone
- ⚠️ Debugging shows different code than what's running
- ⚠️ Changes sync back to wrong clone causing merge conflicts

**Remediation:**
```bash
# Update outdated clone
git -C ~/local-repos/02luka-repo pull

# Or remove outdated clone
rm -rf ~/local-repos/02luka-repo
```

**Prevention:**
- Only maintain ONE active clone on your system
- Use `bash ./.codex/preflight.sh` before each session
- LaunchAgents use `scripts/repo_root_resolver.sh` to find canonical location
