# Cloudflare Transform Rule - ops.theedges.work

**Created**: 2025-12-04  
**Status**: Active  
**Purpose**: Add X-Relay-Key header for health server authentication

## Rule Configuration

- **Rule Name**: `Add X-Relay-Key to ops.theedges.work`
- **Type**: Modify Request Header (Transform Rule)
- **Status**: Active

### Condition
- **When**: Hostname equals `ops.theedges.work`

### Action
- **Action Type**: Set static header
- **Header Name**: `X-Relay-Key`
- **Header Value**: `[REDACTED - See .env.local RELAY_KEY]`

## Related Configuration

- **RELAY_KEY in .env.local**: `[REDACTED - See .env.local]`
- **Health Server**: `misc/health_server.cjs` (port 4000)
- **Cloudflare Tunnel**: `8c87acc7-e77b-4487-a3fa-8f851005b96c`
- **DNS**: `ops.theedges.work` → Cloudflare → Tunnel → `localhost:4000`

## How It Works

1. Request comes to `https://ops.theedges.work/ping`
2. Cloudflare Transform Rule adds `X-Relay-Key` header
3. Cloudflare Tunnel forwards request to `localhost:4000` with header
4. Health server validates `X-Relay-Key` matches `RELAY_KEY` from `.env.local`
5. If valid → 200 OK, if invalid → 401 Unauthorized

## Management

- **Dashboard**: https://dash.cloudflare.com/2cf1e9eb0dfd2477af7b0bea5bcc53d6/theedges.work/rules/transform
- **Zone ID**: `035e56800598407a107b362d40ef5c04`
- **Account ID**: `2cf1e9eb0dfd2477af7b0bea5bcc53d6`

## Notes

- Rule is managed via Cloudflare Dashboard (not API, due to token permissions)
- If `RELAY_KEY` is rotated, update both:
  1. `.env.local` (for health server)
  2. Cloudflare Transform Rule (via Dashboard)

