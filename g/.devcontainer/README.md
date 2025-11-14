# 02Luka Development Container

## Auto-Start Services

When you open this project in a devcontainer, the following services automatically start:

### 1. Boss API Stub (Port 4000)
- **Endpoint**: `http://localhost:4000`
- **Health**: `GET /health` or `GET /api/health`
- **Status**: `GET /api/status`
- **Capabilities**: `GET /api/capabilities`
- **Logs**: `logs/boss_api_stub.err.log`, `logs/boss_api_stub.out.log`

### 2. Health Proxy Stub (Port 3002)
- **Endpoint**: `http://localhost:3002`
- **Health**: `GET /health` or `GET /status`
- **Metrics**: `GET /metrics`
- **Logs**: `logs/health_proxy_stub.err.log`, `logs/health_proxy_stub.out.log`

### 3. MCP Bridge Stub (Port 3003)
- **Endpoint**: `http://localhost:3003`
- **Health**: `GET /health` or `GET /status`
- **Tools**: `GET /mcp/tools`
- **MCP Status**: `GET /mcp/status`
- **Logs**: `logs/mcp_bridge_stub.err.log`, `logs/mcp_bridge_stub.out.log`

## Environment Variables

The following environment variables are automatically configured:

```bash
WORKDIR=/workspaces/g
BOSS_PORT=4000
HEALTH_PORT=3002
MCP_PORT=3003
REDIS_HOST=host.docker.internal
REDIS_PORT=6379
REDIS_PASSWORD=changeme-02luka
NODE_ENV=development
```

## Verifying Services

After the container starts, verify all services are running:

```bash
# Check environment
echo "$WORKDIR"                           # Should show: /workspaces/g

# Check devcontainer logs
tail "$WORKDIR/logs/devcontainer.log"

# Test services
curl http://localhost:4000/health         # Boss API
curl http://localhost:3002/status         # Health Proxy
curl http://localhost:3003/health         # MCP Bridge

# Check service logs
tail "$WORKDIR/logs/boss_api_stub.err.log"
tail "$WORKDIR/logs/health_proxy_stub.err.log"
tail "$WORKDIR/logs/mcp_bridge_stub.err.log"
```

## Stopping Services

Services run in the background. To stop them:

```bash
# Find processes
ps aux | grep stub

# Kill by port
lsof -ti:4000 | xargs kill
lsof -ti:3002 | xargs kill
lsof -ti:3003 | xargs kill
```

## Rebuilding

To rebuild the container with updated configuration:

1. Press **Cmd+Shift+P** (Command Palette)
2. Select **Dev Containers: Rebuild and Reopen in Container**
3. Wait 1-2 minutes for rebuild

## Troubleshooting

**Services not starting?**
```bash
# Check if stub files exist
ls -la "$WORKDIR/run"/*.cjs

# Manually start a service
cd "$WORKDIR"
node run/boss_api_stub.cjs

# Check for port conflicts
lsof -i :4000
```

**Redis connection issues?**
```bash
# Verify Redis is accessible from container
nc -zv host.docker.internal 6379

# Test Redis auth
redis-cli -h host.docker.internal -p 6379 -a changeme-02luka PING
```

---

**Created**: 2025-10-31
**Last Updated**: 2025-10-31
