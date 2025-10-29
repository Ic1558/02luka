---
title: Cloudflare AI Gateway & Agents Gateway Setup
tags: [cloudflare, ai-gateway, agents-gateway, configuration, manual]
created: 2025-10-13
updated: 2025-10-13
---

# Cloudflare Gateways Setup Manual

Complete guide for configuring Cloudflare AI Gateway and Agents Gateway for Luka Boss-API integration.

## Overview

Luka uses two Cloudflare gateways:
1. **AI Gateway** - Proxies LLM API calls (OpenAI, Anthropic, etc.) with caching, rate limiting, and logging
2. **Agents Gateway** - Routes inter-agent communication (Lisa, Mary, GG, etc.)

## Prerequisites

- Cloudflare account: `ittipong.c@gmail.com`
- Account ID: `2cf1e9eb0dfd2477af7b0bea5bcc53d6`
- Zone ID (theedges.work): `035e56800598407a107b362d40ef5c04`
- API Token with permissions:
  - Cloudflare Pages → Edit
  - Workers Scripts → Edit
  - AI Gateway → Edit
  - Agents Gateway → Edit
  - DNS → Edit

## Part 1: AI Gateway Setup

### Status: ✅ COMPLETE (2025-10-12)

**Gateway Created:**
- Gateway ID: `luka-ai-gateway`
- Created: 2025-10-12 17:56:30 UTC
- Gateway URL: `https://gateway.ai.cloudflare.com/v1/2cf1e9eb0dfd2477af7b0bea5bcc53d6/luka-ai-gateway`

**Configuration:**
```json
{
  "cache_ttl": 3600,
  "cache_invalidate_on_update": true,
  "collect_logs": true,
  "rate_limiting_interval": 60,
  "rate_limiting_limit": 100,
  "rate_limiting_technique": "sliding"
}
```

### Features Enabled
- ✅ Request caching (1 hour TTL)
- ✅ Automatic cache invalidation on model updates
- ✅ Request logging for analytics
- ✅ Rate limiting (100 requests per 60 seconds)
- ✅ Sliding window rate limit technique

### How to Use AI Gateway

**1. Direct API Calls (via curl):**
```bash
# OpenAI completion via AI Gateway
curl -X POST \
  "https://gateway.ai.cloudflare.com/v1/2cf1e9eb0dfd2477af7b0bea5bcc53d6/luka-ai-gateway/openai/v1/completions" \
  -H "Authorization: Bearer YOUR_OPENAI_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "model": "gpt-4o-mini",
    "prompt": "What is AI Gateway?",
    "max_tokens": 100
  }'

# Anthropic chat via AI Gateway
curl -X POST \
  "https://gateway.ai.cloudflare.com/v1/2cf1e9eb0dfd2477af7b0bea5bcc53d6/luka-ai-gateway/anthropic/v1/messages" \
  -H "x-api-key: YOUR_ANTHROPIC_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

**2. Via Boss-API (after codex integration):**
```javascript
// In boss-ui/apps/*.html
import { AI_BASE } from '../shared/api.js';

const response = await fetch(`${AI_BASE}/complete`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    model: 'gpt-4o-mini',
    prompt: 'Test prompt',
    temperature: 0.2,
    max_tokens: 1024
  })
});
```

**3. Environment Variables:**
```bash
# boss-api/.env
AI_GATEWAY_URL=https://gateway.ai.cloudflare.com/v1/2cf1e9eb0dfd2477af7b0bea5bcc53d6/luka-ai-gateway
AI_GATEWAY_KEY=DaRWAofhuC9GXJGNmyqJupUYwhhpCHal7YjR5MtN
```

**4. GitHub Secrets:**
```bash
# Already configured (2025-10-12)
gh secret list | grep AI_GATEWAY
# AI_GATEWAY_URL	2025-10-12T18:11:33Z
# AI_GATEWAY_KEY	2025-10-12T18:11:25Z
```

### Monitoring AI Gateway

**View Analytics:**
1. Go to: https://dash.cloudflare.com/2cf1e9eb0dfd2477af7b0bea5bcc53d6/ai/ai-gateway
2. Select: `luka-ai-gateway`
3. View:
   - Request count
   - Cache hit rate
   - Error rate
   - Latency metrics
   - Token usage

**API Monitoring:**
```bash
# Get gateway analytics
curl -s "https://api.cloudflare.com/client/v4/accounts/2cf1e9eb0dfd2477af7b0bea5bcc53d6/ai-gateway/gateways/luka-ai-gateway/analytics" \
  -H "Authorization: Bearer $AI_GATEWAY_KEY" | jq .
```

## Part 2: Agents Gateway Setup

### Status: ⏳ PENDING CONFIGURATION

**Current Workers:**
- `gg-gateway` - Exists, needs custom domain
- `lisa-agent` - Individual agent
- `mary-agent` - Individual agent
- `paula-agent` - Individual agent
- `claude-agent` - Individual agent

### Option A: Use Existing gg-gateway Worker (Quick)

**1. Find gg-gateway subdomain:**
```bash
curl -s "https://api.cloudflare.com/client/v4/accounts/2cf1e9eb0dfd2477af7b0bea5bcc53d6/workers/scripts/gg-gateway/subdomain" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq -r '.result'
```

**2. Test gg-gateway:**
```bash
# Replace <subdomain> with actual value
curl -s https://gg-gateway.<subdomain>.workers.dev/health
```

**3. Use in configuration:**
```bash
# boss-api/.env
AGENTS_GATEWAY_URL=https://gg-gateway.<subdomain>.workers.dev
AGENTS_GATEWAY_KEY=<generate-key>
```

### Option B: Create Custom Domain (Recommended)

**1. Create DNS record:**
```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/035e56800598407a107b362d40ef5c04/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "CNAME",
    "name": "agents",
    "content": "gg-gateway.<subdomain>.workers.dev",
    "ttl": 1,
    "proxied": true,
    "comment": "Agents Gateway routing"
  }'
```

**2. Add custom domain to worker:**
```bash
curl -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/2cf1e9eb0dfd2477af7b0bea5bcc53d6/workers/scripts/gg-gateway/subdomain/agents.theedges.work" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "zone_id": "035e56800598407a107b362d40ef5c04"
  }'
```

**3. Verify:**
```bash
curl -s https://agents.theedges.work/health
```

**4. Update configuration:**
```bash
# boss-api/.env
AGENTS_GATEWAY_URL=https://agents.theedges.work
AGENTS_GATEWAY_KEY=<generate-key>
```

### Option C: Deploy New Agents Gateway Worker

**1. Create worker script:**
```javascript
// agents-gateway-worker.js
export default {
  async fetch(request) {
    const url = new URL(request.url);

    // Health check
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok', timestamp: Date.now() }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Route to agents
    if (url.pathname === '/route') {
      const body = await request.json();
      const { agent, action, payload } = body;

      // Route to specific agent worker
      const agentUrls = {
        'lisa': 'https://lisa-agent.<subdomain>.workers.dev',
        'mary': 'https://mary-agent.<subdomain>.workers.dev',
        'gg': 'https://gg-gateway.<subdomain>.workers.dev',
        'paula': 'https://paula-agent.<subdomain>.workers.dev'
      };

      const agentUrl = agentUrls[agent];
      if (!agentUrl) {
        return new Response(JSON.stringify({ error: 'unknown_agent' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        });
      }

      // Forward request to agent
      const response = await fetch(agentUrl, {
        method: 'POST',
        headers: request.headers,
        body: JSON.stringify({ action, payload })
      });

      return response;
    }

    return new Response('Not Found', { status: 404 });
  }
}
```

**2. Deploy:**
```bash
npx wrangler deploy agents-gateway-worker.js --name agents-gateway
```

**3. Add custom domain:**
```bash
npx wrangler custom-domain add agents.theedges.work --worker agents-gateway
```

## Part 3: Boss-API Integration

### Environment Variables

**File:** `boss-api/.env`
```bash
# Server
HOST=127.0.0.1
PORT=4000
OLLAMA_PORT=11434

# AI Gateway (configured)
AI_GATEWAY_URL=https://gateway.ai.cloudflare.com/v1/2cf1e9eb0dfd2477af7b0bea5bcc53d6/luka-ai-gateway
AI_GATEWAY_KEY=DaRWAofhuC9GXJGNmyqJupUYwhhpCHal7YjR5MtN

# Agents Gateway (pending configuration)
AGENTS_GATEWAY_URL=https://agents.theedges.work
AGENTS_GATEWAY_KEY=<generate-separate-key>

# Cloudflare
CF_ACCOUNT_ID=2cf1e9eb0dfd2477af7b0bea5bcc53d6
CF_ZONE_ID=035e56800598407a107b362d40ef5c04
```

### GitHub Secrets (Production)

**Already configured:**
```bash
gh secret set AI_GATEWAY_URL < "https://gateway.ai.cloudflare.com/v1/2cf1e9eb0dfd2477af7b0bea5bcc53d6/luka-ai-gateway"
gh secret set AI_GATEWAY_KEY < "DaRWAofhuC9GXJGNmyqJupUYwhhpCHal7YjR5MtN"
gh secret set CF_ACCOUNT_ID < "2cf1e9eb0dfd2477af7b0bea5bcc53d6"
gh secret set CF_API_TOKEN < "DaRWAofhuC9GXJGNmyqJupUYwhhpCHal7YjR5MtN"
```

**To be added (after agents gateway configured):**
```bash
echo "https://agents.theedges.work" | gh secret set AGENTS_GATEWAY_URL
echo "<generate-key>" | gh secret set AGENTS_GATEWAY_KEY
```

## Part 4: Testing & Verification

### Test AI Gateway

**1. Direct API test:**
```bash
curl -X POST \
  "https://gateway.ai.cloudflare.com/v1/2cf1e9eb0dfd2477af7b0bea5bcc53d6/luka-ai-gateway/openai/v1/completions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "model": "gpt-4o-mini",
    "prompt": "ping",
    "max_tokens": 8
  }' | jq .
```

**2. Via Boss-API (after codex integration):**
```bash
# Start boss-api
cd boss-api
node server.cjs &

# Test endpoint
curl -X POST http://127.0.0.1:4000/api/ai/complete \
  -H "Content-Type: application/json" \
  --data '{
    "model": "gpt-4o-mini",
    "prompt": "ping",
    "max_tokens": 8
  }' | jq .
```

### Test Agents Gateway

**1. Health check:**
```bash
curl -s https://agents.theedges.work/health | jq .
# Expected: {"status": "ok", "timestamp": 1234567890}
```

**2. Route to agent:**
```bash
curl -X POST https://agents.theedges.work/route \
  -H "Authorization: Bearer $AGENTS_GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "agent": "lisa",
    "action": "analyze",
    "payload": {"text": "test"}
  }' | jq .
```

**3. Via Boss-API:**
```bash
curl -X POST http://127.0.0.1:4000/api/agents/route \
  -H "Content-Type: application/json" \
  --data '{
    "agent": "gg",
    "action": "search",
    "payload": {"query": "test"}
  }' | jq .
```

## Part 5: Troubleshooting

### AI Gateway Issues

**Problem: 503 Service Unavailable**
- Check: `AI_GATEWAY_URL` is set correctly
- Verify: Token has AI Gateway permissions
- Test: Direct API call without gateway

**Problem: Rate limit exceeded**
- Current limit: 100 requests per 60 seconds
- Solution: Increase limit in gateway settings
- Dashboard: https://dash.cloudflare.com/.../ai/ai-gateway/luka-ai-gateway

**Problem: Cache not working**
- Check: `cache_ttl` is set (default: 3600 seconds)
- Verify: Same request parameters
- Dashboard: View cache hit rate in analytics

### Agents Gateway Issues

**Problem: agents.theedges.work not found**
- Check: DNS record exists (`dig +short agents.theedges.work`)
- Verify: Custom domain added to worker
- Test: Worker directly at workers.dev subdomain

**Problem: Agent routing fails**
- Check: Agent name matches (lisa/mary/gg/paula)
- Verify: Target agent workers are deployed
- Test: Direct agent worker URL

**Problem: Authentication error**
- Check: `AGENTS_GATEWAY_KEY` is set
- Verify: Key matches worker configuration
- Test: Health endpoint (no auth required)

## Part 6: Maintenance

### Update AI Gateway Config

```bash
curl -X PATCH \
  "https://api.cloudflare.com/client/v4/accounts/2cf1e9eb0dfd2477af7b0bea5bcc53d6/ai-gateway/gateways/luka-ai-gateway" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "cache_ttl": 7200,
    "rate_limiting_limit": 200
  }'
```

### Rotate API Keys

**1. Generate new token:**
- Go to: https://dash.cloudflare.com/profile/api-tokens
- Create new token with same permissions

**2. Update everywhere:**
```bash
# Local
vim boss-api/.env  # Update AI_GATEWAY_KEY

# GitHub
echo "NEW_TOKEN" | gh secret set AI_GATEWAY_KEY
echo "NEW_TOKEN" | gh secret set CF_API_TOKEN
```

**3. Revoke old token:**
- Dashboard → API Tokens → Delete old token

### Monitor Gateway Health

**Daily checks:**
```bash
# AI Gateway analytics
curl -s "https://api.cloudflare.com/client/v4/accounts/2cf1e9eb0dfd2477af7b0bea5bcc53d6/ai-gateway/gateways/luka-ai-gateway/analytics" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq .

# Agents Gateway health
curl -s https://agents.theedges.work/health | jq .

# Workers status
curl -s "https://api.cloudflare.com/client/v4/accounts/2cf1e9eb0dfd2477af7b0bea5bcc53d6/workers/scripts" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.result[] | {id, modified_on}'
```

## Summary

### Completed ✅
1. AI Gateway created and configured
2. Local .env file created
3. GitHub Secrets updated
4. Documentation complete

### Pending ⏳
1. Agents Gateway custom domain (agents.theedges.work)
2. Agents Gateway authentication key generation
3. GitHub Secrets for agents gateway
4. Integration testing after codex completes code changes

### Resources
- **AI Gateway Dashboard:** https://dash.cloudflare.com/2cf1e9eb0dfd2477af7b0bea5bcc53d6/ai/ai-gateway
- **Workers Dashboard:** https://dash.cloudflare.com/2cf1e9eb0dfd2477af7b0bea5bcc53d6/workers
- **DNS Dashboard:** https://dash.cloudflare.com/2cf1e9eb0dfd2477af7b0bea5bcc53d6/theedges.work/dns
- **API Docs:** https://developers.cloudflare.com/api/

### Contact
- **Owner:** CLC
- **Date:** 2025-10-13
- **Status:** AI Gateway ready, Agents Gateway pending
