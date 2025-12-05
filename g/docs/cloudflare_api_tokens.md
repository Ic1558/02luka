# Cloudflare API Tokens

**Last Updated**: 2025-12-04  
**Storage**: `.env.local` (gitignored)

## Token Overview

Three API tokens are configured for different purposes:

### 1. CLOUDFLARE_API_TOKEN_DNS
- **Purpose**: Edit zone DNS
- **Permissions**: 
  - theedges.work - DNS:Edit
- **Token**: `[REDACTED - See .env.local CLOUDFLARE_API_TOKEN_DNS]`
- **Use Case**: DNS record management

### 2. CLOUDFLARE_API_TOKEN_LUKA
- **Purpose**: General 02luka operations
- **Permissions**:
  - AI Gateway:Edit
  - Cloudflare Pages:Edit
  - Account Analytics:Read
  - Cloudflare Tunnel:Edit
  - Workers Scripts:Edit
  - Account Settings:Read
  - All zones - DNS:Edit
- **Token**: `[REDACTED - See .env.local CLOUDFLARE_API_TOKEN_LUKA]`
- **TTL**: October 12, 2025 - September 1, 2026
- **Use Case**: General Cloudflare operations, Workers, Tunnels

### 3. CLOUDFLARE_API_TOKEN_TUNNEL
- **Purpose**: Cloudflare Tunnel management
- **Permissions**:
  - Cloudflare One Networks:Edit
  - Cloudflare One Connector: cloudflared:Edit
  - Load Balancing: Monitors And Pools:Edit
  - theedges.work - DNS:Edit
- **Token**: `[REDACTED - See .env.local CLOUDFLARE_API_TOKEN_TUNNEL]`
- **Use Case**: Tunnel configuration, Load Balancing

## Usage

All tokens are stored in `.env.local` and can be accessed via:

```bash
source ~/02luka/.env.local
echo $CLOUDFLARE_API_TOKEN_DNS
echo $CLOUDFLARE_API_TOKEN_LUKA
echo $CLOUDFLARE_API_TOKEN_TUNNEL
```

## Security

- ✅ All tokens stored in `.env.local` (gitignored)
- ✅ Never commit tokens to git
- ✅ Rotate tokens periodically (especially Luka token expires Sep 2026)

## Related Configuration

- Zone ID: `035e56800598407a107b362d40ef5c04`
- Account ID: `2cf1e9eb0dfd2477af7b0bea5bcc53d6`
- Domain: `theedges.work`

