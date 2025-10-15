# Codex Developer Runbook

**Status:** ✅ Ready for Development
**Last Updated:** 2025-10-15
**Maintainer:** Luka Dev / Codex Core

---

## 1) Core Services

- **boss-api** – REST endpoints on port 4000
- **MCP gateway** – local FS and proxy bridge on port 5012
- **MCP FS** – file operations via MCP server on port 8765

---

## 2) Health & Smoke

Run quick verification anytime:

```bash
bash ./run/smoke_api_ui.sh
```

**Expected:**
- ✅ API Capabilities
- ✅ UI Index
- ✅ MCP FS (optional, may warn in devcontainer)
- ✅ Stub mode endpoints

---

## 3) Gateway Configuration (Optional)

Environment variables (in `.env.local`):

```bash
AI_GATEWAY_URL=
AI_GATEWAY_KEY=
AGENTS_GATEWAY_URL=
AGENTS_GATEWAY_KEY=
```

Default: Local-only mode (no external gateways required)

---

## 4) Quick Verification Commands

```bash
# Health check
curl -s http://127.0.0.1:4000/healthz | jq .

# Capabilities
curl -s http://127.0.0.1:4000/api/capabilities | jq .keys

# Plan endpoint (stub mode)
curl -s http://127.0.0.1:4000/api/plan \
  -H 'Content-Type: application/json' \
  -d '{"goal":"ping","stub":true}' | jq .

# Reports summary
curl -s http://127.0.0.1:4000/api/reports/summary | jq .

# MCP Docker health
curl -s http://127.0.0.1:5012/health | jq .
```

---

## 5) CI/CD (Optional)

Smoke tests can run inside CI:

```yaml
# .github/workflows/docs-smoke.yml
run: bash ./run/smoke_api_ui.sh
```

Manual workflow triggers available for testing.

---

## 6) Duplicate Clone Prevention

**Problem:** Multiple repository clones can cause confusion and stale code execution.

**Check for duplicates before development:**

```bash
# Preflight automatically detects duplicates
bash ./.codex/preflight.sh

# Manual check
source ./scripts/repo_root_resolver.sh
echo "${DUPLICATE_CLONES[@]}"
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

---

## 7) Developer Workflow

1. **Start services:** Follow docs/02luka.md morning routine
2. **Run smoke tests:** Verify all critical services
3. **Make changes:** Follow atomic commit guidelines
4. **Pre-push:** Ensure smoke tests still pass
5. **Create PR:** Use `gh pr create` with proper formatting

---

## 8) Documentation

- **API Endpoints:** `docs/api_endpoints.md`
- **System Overview:** `docs/02luka.md`
- **Context Engineering:** `docs/CONTEXT_ENGINEERING.md`

---

## Purpose

A living quick-reference for daily engineering—paired with formal Ops readiness docs.

**For deployment checkpoints and operational gates, see:**
👉 **[CODEX_MASTER_READINESS.md](./CODEX_MASTER_READINESS.md)**
