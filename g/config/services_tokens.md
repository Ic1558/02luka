# 02luka Services - Tokens & Configuration

**Generated:** 2025-10-31  
**Status:** ✅ PRODUCTION

## HTTP Redis Bridge

- **Service:** http_redis_bridge
- **Port:** 8788
- **Token:** `ff33a258edc8867d6c1366ab19408797`

### Usage

```bash
curl -H "x-auth-token: ff33a258edc8867d6c1366ab19408797" \
  http://localhost:8788/ping
```

## Redis Configuration

- **Host:** `02luka-redis` (Docker network alias)
- **Port:** 6379
- **Password:** None (no authentication required)
- **URL:** `redis://02luka-redis:6379`

## Service Containers

| Container | Network | Status |
|-----------|---------|--------|
| http_redis_bridge | 02luka-net | ✅ Running |
| clc_listener | 02luka-net | ✅ Running |
| ops_health_watcher | 02luka-net | ✅ Running |

## Environment Variables

Add to your shell (~/.zshrc):

```bash
export BRIDGE_TOKEN=ff33a258edc8867d6c1366ab19408797
```

Or source from project:

```bash
source ~/LocalProjects/02luka_local_g/.env.services
```

## Regenerate Token

If compromised:

```bash
NEW_TOKEN=$(openssl rand -hex 16)
docker stop http_redis_bridge
docker rm http_redis_bridge
# Then recreate with new token
```
