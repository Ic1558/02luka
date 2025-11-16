# 02luka Docker Services

**Production-ready Docker Compose configuration for 02luka Redis infrastructure**

[![Docker](https://img.shields.io/badge/docker-20.10+-blue.svg)](https://www.docker.com/)
[![Redis](https://img.shields.io/badge/redis-7.0+-red.svg)](https://redis.io/)
[![Node.js](https://img.shields.io/badge/node.js-20+-green.svg)](https://nodejs.org/)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Services](#services)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Security](#security)
- [Maintenance](#maintenance)

---

## 🎯 Overview

This Docker Compose configuration provides a complete Redis-based pub/sub infrastructure for the 02luka system, including:

- **Redis Server** - High-performance pub/sub messaging
- **HTTP Redis Bridge** - REST API for Redis operations
- **CLC Listener** - Export mode event processor
- **Ops Health Watcher** - Service monitoring and health checks

### Key Features

- ✅ Production-ready with health checks
- ✅ Resource limits and reservations
- ✅ Network isolation (02luka-net)
- ✅ Automatic restarts
- ✅ Persistent data storage
- ✅ Localhost-only binding (secure)
- ✅ Complete observability

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     02luka-net (172.22.0.0/16)              │
│                                                             │
│  ┌──────────┐    ┌────────────────┐    ┌──────────────┐   │
│  │  Redis   │◄───┤ HTTP Bridge    │◄───┤ External     │   │
│  │  :6379   │    │ :8788          │    │ Requests     │   │
│  └────┬─────┘    └────────────────┘    └──────────────┘   │
│       │                                                     │
│       │          ┌────────────────┐                        │
│       ├─────────►│ CLC Listener   │                        │
│       │          │ (pub/sub)      │                        │
│       │          └────────────────┘                        │
│       │                                                     │
│       │          ┌────────────────┐                        │
│       └─────────►│ Ops Health     │──► ops.theedges.work  │
│                  │ Watcher        │                        │
│                  └────────────────┘                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Network Design

- **Internal Network**: `02luka-net` (172.22.0.0/16)
- **Redis Aliases**: `redis`, `02luka-redis`
- **Port Exposure**: Localhost only (127.0.0.1)
- **Inter-Container**: Full connectivity via Docker bridge

---

## 🐳 Services

### 1. Redis Server

**Image**: `redis:7-alpine`
**Port**: `127.0.0.1:6379`
**Purpose**: Central pub/sub message broker

**Configuration**:
- AOF persistence enabled
- 256MB max memory
- LRU eviction policy
- Automatic snapshots (RDB)

**Resource Limits**:
- CPU: 0.25-0.5 cores
- Memory: 256-512MB

**Health Check**:
```bash
redis-cli ping  # Expected: PONG
```

---

### 2. HTTP Redis Bridge

**Image**: `02luka-node-services:latest`
**Port**: `127.0.0.1:8788`
**Purpose**: HTTP → Redis API gateway

**Features**:
- REST API for pub/sub operations
- Authentication required
- Health endpoint: `http://localhost:8788/health`

**Resource Limits**:
- CPU: 0.1-0.25 cores
- Memory: 128-256MB

**Environment Variables**:
- `REDIS_URL=redis://02luka-redis:6379`
- `BRIDGE_PORT=8788`
- `NODE_ENV=production`

---

### 3. CLC Listener

**Image**: `02luka-node-services:latest`
**Purpose**: Listen to CLC export mode events

**Configuration**:
- Channel: `gg:clc:export_mode`
- Read/Write volume mount for event processing

**Resource Limits**:
- CPU: 0.1-0.25 cores
- Memory: 128-256MB

---

### 4. Ops Health Watcher

**Image**: `02luka-node-services:latest`
**Purpose**: Monitor ops.theedges.work endpoints

**Monitoring Targets**:
- `/ping` - Basic health check
- `/state` - System state
- `/metrics` - Prometheus metrics

**Check Interval**: 5 minutes (300s)

**Resource Limits**:
- CPU: 0.1-0.25 cores
- Memory: 128-256MB

---

## 📦 Prerequisites

### Required

1. **Docker & Docker Compose**
   ```bash
   docker --version  # 20.10+
   docker-compose --version  # 1.29+
   ```

2. **Docker Image**
   ```bash
   # Build if not exists
   docker build -t 02luka-node-services:latest .

   # Or pull from registry
   docker pull 02luka-node-services:latest
   ```

3. **Redis Data Volume**
   ```bash
   docker volume create luka-ops_redis_data
   ```

4. **Application Directory**
   ```bash
   ls -la /Users/icmini/LocalProjects/02luka_local_g/g
   ```

### Optional

5. **Secrets Configuration**
   ```bash
   # Setup credentials
   mkdir -p ~/.config/02luka/secrets
   # See Security section for details
   ```

---

## 🚀 Quick Start

### Method 1: Using compose-up.sh (Recommended)

```bash
# Make executable
chmod +x compose-up.sh

# Run deployment
./compose-up.sh

# Follow interactive prompts
```

### Method 2: Manual Steps

```bash
# 1. Verify prerequisites
docker volume ls | grep luka-ops_redis_data
docker images | grep 02luka-node-services

# 2. Start services
docker-compose up -d

# 3. Check status
docker-compose ps

# 4. View logs
docker-compose logs -f

# 5. Verify health
docker-compose ps --format "table {{.Name}}\t{{.Status}}"
```

### Method 3: Using Management Script

```bash
# If you have the management script
~/02luka/docker_services.sh start
~/02luka/docker_services.sh status
```

---

## ⚙️ Configuration

### Environment Variables

Create `.env` file in the same directory:

```bash
# Redis Configuration
REDIS_URL=redis://02luka-redis:6379
REDIS_MAX_MEMORY=256mb

# HTTP Bridge
BRIDGE_PORT=8788
NODE_ENV=production

# CLC Listener
CLC_EXPORT_MODE_CHANNEL=gg:clc:export_mode

# Ops Health Watcher
OPS_HEALTH_URL=https://ops.theedges.work
CHECK_INTERVAL=300000
```

### Volume Mounts

**Redis Data**: Named volume (persistent)
```yaml
volumes:
  - luka-ops_redis_data:/data
```

**Application Code**: Bind mount
```yaml
volumes:
  - /Users/icmini/LocalProjects/02luka_local_g/g:/app/g
```

**Note**: For production, consider read-only mounts:
```yaml
volumes:
  - /path/to/app:/app/g:ro
```

### Network Configuration

**Subnet**: `172.22.0.0/16`
**Gateway**: `172.22.0.1`
**Bridge Name**: `br-02luka`

**DNS Resolution**:
- Services can reach Redis via:
  - `redis:6379`
  - `02luka-redis:6379`

---

## 📊 Monitoring

### Health Checks

**Check All Services**:
```bash
docker-compose ps
```

**Individual Health Status**:
```bash
# Redis
docker exec redis redis-cli PING

# HTTP Bridge
curl http://localhost:8788/health

# Ops endpoints (public)
curl https://ops.theedges.work/ping
curl https://ops.theedges.work/state
curl https://ops.theedges.work/metrics
```

### Logs

**View All Logs**:
```bash
docker-compose logs -f
```

**Service-Specific Logs**:
```bash
docker-compose logs -f redis
docker-compose logs -f http_redis_bridge
docker-compose logs -f clc_listener
docker-compose logs -f ops_health_watcher
```

**Last N Lines**:
```bash
docker-compose logs --tail=50 redis
```

### Resource Usage

```bash
# Container stats
docker stats

# Disk usage
docker system df

# Network info
docker network inspect 02luka-net
```

### Prometheus Metrics

Available at: `https://ops.theedges.work/metrics`

**Example Metrics**:
- `process_uptime_seconds`
- `process_memory_bytes`
- Custom application metrics

---

## 🐛 Troubleshooting

### Service Won't Start

**Check logs**:
```bash
docker-compose logs [service_name]
```

**Check dependencies**:
```bash
docker-compose ps
# Ensure Redis is healthy before other services start
```

**Restart service**:
```bash
docker-compose restart [service_name]
```

---

### DNS Resolution Issues (ENOTFOUND)

**Problem**: Services can't resolve `02luka-redis`

**Solution**:
```bash
# 1. Check network aliases
docker inspect redis | jq '.NetworkSettings.Networks["02luka-net"].Aliases'

# Expected output: ["redis", "02luka-redis"]

# 2. Test DNS from container
docker exec http_redis_bridge getent hosts 02luka-redis

# 3. Restart services if needed
docker-compose restart
```

---

### Port Conflicts

**Problem**: Port already in use

**Find conflicting process**:
```bash
lsof -i :6379  # Redis
lsof -i :8788  # HTTP Bridge
lsof -i :4000  # Health Server
```

**Solutions**:
- Stop conflicting service
- Change port in `docker-compose.yml`
- Remove old containers: `docker ps -a | grep redis`

---

### Volume Issues

**Check volume exists**:
```bash
docker volume ls | grep luka-ops_redis_data
```

**Inspect volume**:
```bash
docker volume inspect luka-ops_redis_data
```

**Create if missing**:
```bash
docker volume create luka-ops_redis_data
```

---

### Connection Refused

**Problem**: Can't connect to services

**Checklist**:
1. ✅ Services running: `docker-compose ps`
2. ✅ Health checks passing: `docker inspect --format='{{.State.Health.Status}}' redis`
3. ✅ Correct network: `docker network inspect 02luka-net`
4. ✅ Firewall rules: `iptables -L` (run from an administrator shell, never via embedded elevation)

---

## 🔐 Security

### Port Binding

**All services bound to localhost only**:
- Redis: `127.0.0.1:6379` (not accessible from network)
- HTTP Bridge: `127.0.0.1:8788` (not accessible from network)

**External Access**:
- Only through Cloudflare Tunnel (ops.theedges.work)
- Requires authentication

### Credentials Management

**Store secrets securely**:
```bash
# Create secrets directory
mkdir -p ~/.config/02luka/secrets
chmod 700 ~/.config/02luka/secrets

# Create secret files
cat > ~/.config/02luka/secrets/cloudflare.env << 'EOF'
CLOUDFLARE_API_TOKEN=your_token_here
CLOUDFLARE_ZONE_ID=your_zone_id
EOF

chmod 600 ~/.config/02luka/secrets/*.env
```

**Load secrets in scripts**:
```bash
source ~/.config/02luka/secrets/cloudflare.env
echo $CLOUDFLARE_API_TOKEN  # Use in scripts
```

**⚠️ NEVER commit secrets to git**

### Network Isolation

- Services communicate via internal `02luka-net`
- No direct external access
- Ingress only through Cloudflare Tunnel

### Volume Security

**Consider read-only mounts for code**:
```yaml
volumes:
  - /path/to/app:/app/g:ro  # Read-only
```

**Set proper permissions**:
```bash
chmod 750 /path/to/app
chown -R user:docker /path/to/app
```

---

## 🔧 Maintenance

### Update Services

**Rebuild with new image**:
```bash
# Pull latest image
docker pull 02luka-node-services:latest

# Recreate containers
docker-compose up -d --force-recreate

# Verify
docker-compose ps
```

### Backup Redis Data

**Manual backup**:
```bash
# Trigger Redis save
docker exec redis redis-cli SAVE

# Copy RDB file
docker cp redis:/data/dump.rdb ~/02luka/backups/redis-$(date +%Y%m%d).rdb
```

**Automated backup script**:
```bash
#!/bin/bash
BACKUP_DIR="$HOME/02luka/backups"
mkdir -p "$BACKUP_DIR"

docker exec redis redis-cli SAVE
docker cp redis:/data/dump.rdb "$BACKUP_DIR/redis-$(date +%Y%m%d_%H%M%S).rdb"
echo "Backup complete: $BACKUP_DIR"
```

### Restore Redis Data

```bash
# Stop Redis
docker-compose stop redis

# Copy backup to volume
docker run --rm -v luka-ops_redis_data:/data -v ~/02luka/backups:/backup \
  alpine sh -c "cp /backup/redis-YYYYMMDD.rdb /data/dump.rdb"

# Start Redis
docker-compose start redis

# Verify
docker exec redis redis-cli DBSIZE
```

### Clean Up

**Remove stopped containers**:
```bash
docker-compose rm -f
```

**Remove unused images**:
```bash
docker image prune -f
```

**Clean system** (⚠️ careful):
```bash
docker system prune -a --volumes
```

### Log Rotation

**Configure Docker log rotation** in `/etc/docker/daemon.json`:
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

Restart Docker (requires admin shell): `systemctl restart docker`

---

## 📚 Additional Resources

### Documentation
- **Quick Reference**: `DOCKER_QUICK_REF.md`
- **Migration Guide**: `DOCKER_MIGRATION_SUMMARY.md`
- **Full Documentation**: `DOCKER_SERVICES.md`
- **Secrets Guide**: `~/.config/02luka/secrets/README.md`

### External Links
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Redis Documentation](https://redis.io/documentation)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

### Management Tools

<!-- Sanitized for Codex Sandbox Mode (2025-11) -->
- **Management Script**: `~/02luka/docker_services.sh`
- **Health Server**: `~/02luka/monitoring/health_server.cjs`
- **Deployment Script**: `compose-up.sh`

---

## 🤝 Contributing

When making changes:

1. **Test locally** with `docker-compose up`
2. **Update documentation** if needed
3. **Commit with clear messages**
4. **Create PR** to `main` branch

### Branch Naming
- Feature: `feature/description`
- Fix: `fix/description`
- Infrastructure: `infra/description`

---

## 📝 Changelog

### v1.0.0 (2025-10-31)
- Initial Docker Compose configuration
- Added all four core services
- Implemented health checks
- Configured resource limits
- Network isolation setup
- Complete documentation

---

## 📄 License

Proprietary - 02luka Internal Use Only

---

## 💬 Support

For issues or questions:
1. Check logs: `docker-compose logs [service]`
2. Review troubleshooting section above
3. Check network: `docker network inspect 02luka-net`
4. Consult full documentation in `DOCKER_SERVICES.md`

---

**Status**: ✅ Production Ready
**Last Updated**: 2025-10-31
**Maintainer**: 02luka Infrastructure Team


## Environment Variables

### BRIDGE_TOKEN Configuration

The `http_redis_bridge` service requires a `BRIDGE_TOKEN` for authentication. This token is stored securely and must be loaded before deployment.

**Location**: `~/.config/02luka/secrets/bridge.env`

**Usage**:
```bash
# Load token before deployment
source ~/.config/02luka/secrets/bridge.env
export BRIDGE_TOKEN

# Deploy with token
docker-compose up -d
```

**Deployment Script**:
The `compose-up.sh` script handles token loading automatically. However, for manual deployment:

```bash
# Manual deployment with token
cd ~/LocalProjects/02luka_local_g/g
source ~/.config/02luka/secrets/bridge.env
export BRIDGE_TOKEN
docker-compose up -d
```

**Security**:
- File permissions: `600` (owner read/write only)
- Never commit to git
- Token is a 256-bit hex string (64 characters)
- Used for HTTP Bearer authentication on port 8788

**Regenerate Token** (if compromised):
```bash
TOKEN=$(openssl rand -hex 32)
echo "BRIDGE_TOKEN=$TOKEN" > ~/.config/02luka/secrets/bridge.env
chmod 600 ~/.config/02luka/secrets/bridge.env

# Restart bridge service
cd ~/LocalProjects/02luka_local_g/g
source ~/.config/02luka/secrets/bridge.env
export BRIDGE_TOKEN
docker-compose restart http_redis_bridge
```
