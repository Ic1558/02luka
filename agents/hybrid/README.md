# Hybrid - Luka/Hybrid CLI Agent

**Last Updated:** 2025-11-15  
**Status:** CLI Operations Agent

---

## Role

**Hybrid** = Luka/Hybrid CLI Agent

Hybrid is the CLI agent responsible for executing real system commands, connecting to services, and running scripts in the 02luka system.

**Primary Functions:**
- Execute shell commands and scripts
- Connect to Redis (127.0.0.1:6379)
- Manage Docker containers
- Control LaunchAgents (launchctl)
- Follow predefined playbooks
- Execute system-level operations

---

## Capabilities

### CLI Operations
- **Shell commands:** Execute bash/zsh scripts and commands
- **Redis operations:** Connect to Redis, publish/subscribe to channels
- **Docker management:** Run docker/docker-compose commands
- **LaunchAgent control:** Manage macOS LaunchAgents via launchctl
- **Service management:** Start/stop/restart system services
- **File operations:** Read/write files in allowed zones

### Redis Integration
- **Host:** 127.0.0.1:6379
- **Password:** gggclukaic (Homebrew Redis, not Docker)
- **Channels:**
  - `shell` - Shell command channel
  - `gg:nlp` - NLP intent channel
- **Monitoring:** `tools/redis_status.zsh`

### Agent Services
Based on repo rules, Hybrid manages:
- **shell_subscriber:** Executes commands from Redis shell channel
- **gg_nlp_bridge:** Maps NLP intents to shell commands
- **redis_chain_status:** Monitors Redis pub/sub health

---

## Relationship to Other Agents

**GG → Hybrid:**
- GG routes `agent_action` tasks to Hybrid
- GG creates playbooks/commands for Hybrid to execute
- Hybrid executes commands in allowed zones

**Hybrid → System:**
- Direct execution of system commands
- Redis pub/sub operations
- Docker and service management

---

## Allowed Operations

Hybrid can execute commands in:
- `apps/**`
- `server/**`
- `tools/**`
- `scripts/**`
- `tests/**`
- Redis operations
- Docker operations
- LaunchAgent management (via playbooks)

---

## Prohibited Operations

Hybrid **must not** execute commands that:
- Modify SOT zones (`core/`, `CLC/`, `docs/`, governance)
- Touch memory center, bridges, launchd core
- Bypass governance rules
- Execute privileged operations (delegate to CLC instead)

---

## Usage Pattern

1. **GG routes task** to Hybrid for CLI execution
2. **Hybrid receives** command/playbook from GG
3. **Hybrid validates** command against allowed zones
4. **Hybrid executes** command in safe context
5. **Hybrid returns** results to GG

---

## Links

- **Agent System Index:** `/agents/README.md`
- **GG Orchestrator:** `/agents/gg_orch/README.md`
- **GG Contract:** `docs/GG_ORCHESTRATOR_CONTRACT.md`
- **Redis Status:** `tools/redis_status.zsh`

---

**Note:** Implementation paths TBD. Hybrid operates as CLI executor following playbooks from GG.
