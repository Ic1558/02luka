# Andy - Dev Agent (Codex Worker)

**Last Updated:** 2025-11-15  
**Configuration:** `config/agents/andy.yaml`  
**Version:** 1.0.0

---

## Role

**Andy** = Dev Agent (Codex Worker) for 02LUKA System

Andy is the development agent (Codex worker) responsible for code implementation, fixes, and changes in the 02luka system. Andy operates as the primary code executor following PR prompts and contracts from GG Orchestrator.

**Primary Functions:**
- Code generation and implementation
- Code review and validation
- Refactoring and optimization
- Debugging and troubleshooting
- Testing (unit, integration, e2e)
- Documentation generation
- Deployment assistance
- Git operations
- PR implementation (via PR Prompt Contracts from GG)

---

## Capabilities

### Primary Capabilities
- Code generation
- Code review
- Refactoring
- Debugging
- Testing
- Documentation
- Deployment
- Git operations

### Languages Supported
- JavaScript / TypeScript
- Python
- Bash / Zsh
- YAML / JSON
- Markdown

### Frameworks
- Node.js / Express
- React / Vue
- Flask / FastAPI

### Tools
- Git
- Docker
- npm / yarn / pip
- pytest / jest
- ESLint / Prettier

### Specializations
- API development
- Frontend components
- Backend services
- Database operations
- CI/CD pipelines
- Infrastructure as code

---

## Intent Mapping

Andy can handle these intent patterns:

| Intent | Confidence | Keywords |
|--------|-----------|----------|
| `code.implement` | 0.95 | implement, create, write, build, develop, code |
| `code.review` | 0.90 | review, check, inspect, validate, code review |
| `code.fix` | 0.95 | fix, bug, error, issue, problem, resolve, debug |
| `code.test` | 0.90 | test, unit test, integration test, e2e, testing |
| `code.refactor` | 0.85 | refactor, optimize, improve, clean up, restructure |
| `code.debug` | 0.90 | debug, troubleshoot, investigate, diagnose |
| `code.deploy` | 0.85 | deploy, release, publish, ship, production |
| `git.commit` | 0.95 | commit, git commit, stage, save changes |
| `git.push` | 0.95 | push, git push, remote, upstream |
| `git.pr` | 0.90 | pull request, PR, merge request, review |

---

## Permissions

### File Access

**Read:**
- `**/*.js`, `**/*.ts`, `**/*.jsx`, `**/*.tsx`
- `**/*.py`
- `**/*.md`, `**/*.yaml`, `**/*.yml`, `**/*.json`
- `**/*.sh`, `**/*.zsh`, `**/*.bash`
- `**/Dockerfile`, `**/package.json`, `**/requirements.txt`
- `**/README*`

**Write:**
- `src/**`
- `tests/**`
- `docs/**`
- `config/**`
- `tools/**`
- `scripts/**`
- `agents/**`

**Exclude:**
- `.env`, `.env.*`
- `secrets/**`
- `*.key`, `*.pem`, `*.p12`
- `credentials.json`
- `**/.git/**`

### API Access
- boss_api
- rag_api
- mcp_memory
- mcp_search
- prometheus
- grafana

### Commands

**Allowed:**
- git, npm, yarn, node, python, pip
- bash, zsh, docker, docker-compose
- curl, jq, yq, grep, sed, awk, find, ls, cat, head, tail, wc

**Forbidden:**
- Root-level or recursive filesystem wipes
- Privileged deletion / ownership changes
- World-writable permission changes
- Filesystem formatting or raw disk copy utilities
- Fork-bomb or resource exhaustion payloads

---

## Delegation

### Can Delegate To
- kim (for NLU, translation, explanations)
- system (for file operations, system commands, database queries, service management)

### Delegation Triggers

**To Kim:**
- Natural language understanding required
- User intent unclear
- Non-technical query
- Translation required
- Explanation requested

**To System:**
- File operation required
- System command needed
- Database query required
- Service restart needed

### Handoff Protocol
- Include context: true
- Include history: true
- Max context tokens: 4000
- Timeout: 5000ms
- Max delegation depth: 3
- Prevent circular: true

---

## Context

### RAG Access
- Endpoint: `http://127.0.0.1:8765/rag_query`

### Memory Access
- MCP Memory: `http://localhost:5330`
- MCP Search: `http://localhost:5340`

### Session
- Timeout: 3600 seconds
- Max context tokens: 8000
- Context window messages: 10

### Preferences
- Code style: clean_code
- Comment style: minimal
- Test framework: jest
- Error handling: explicit

---

## Performance

- Max response time: 30000ms
- Max file size: 10MB
- Max files per operation: 50
- Rate limits:
  - Requests per minute: 60
  - Tokens per minute: 100000

---

## Error Handling

- Retry on failure: true
- Max retries: 3
- Backoff strategy: exponential
- Backoff base: 1000ms

**Fallback Strategy:**
- On timeout: delegate to kim
- On error: report and delegate
- On ambiguity: delegate to kim

---

## Health Check

- Endpoint: `/healthz`
- Interval: 30 seconds
- Timeout: 5000ms

**Dependencies:**
- boss_api
- rag_api
- git

---

## Relationship to Other Agents

**GG → Andy:**
- GG routes `local_fix` (low complexity) tasks directly to Andy
- GG routes `pr_change` tasks via PR Prompt Contracts to Andy
- GG creates PR prompts with scope, required changes, tests, and safety constraints
- Andy implements changes following PR contract specifications

**Andy → CLS:**
- For `local_fix` (medium complexity), CLS reviews Andy's work
- For `pr_change` (high complexity), CLS provides code review and validation
- CLS enforces governance and safety protocols

**Andy → CLC:**
- Andy does NOT modify SOT zones directly
- If changes require SOT modification, Andy must note this in PR description
- CLC handles privileged operations via Work Orders

---

## Routing from GG Orchestrator

According to `docs/GG_ORCHESTRATOR_CONTRACT.md`, Andy (Codex) is routed for:

| Task Type | Complexity | Route |
|-----------|-----------|-------|
| `local_fix` | low | GG → Codex (Andy) |
| `local_fix` | medium | GG → Codex (Andy) + CLS review |
| `pr_change` | low/medium | GG → PR Prompt → Codex (Andy) |
| `pr_change` | high | GG → PR Prompt → Codex (Andy) + CLS |

**Allowed Zones:**
- `apps/**`, `server/**`, `schemas/**`, `scripts/**`
- `docs/**` (except governance core)
- `tools/**`, `roadmaps/**`, `tests/**`
- `agents/**` (documentation layer)

**Prohibited Zones:**
- `/CLC/**`, `/core/governance/**`
- `02luka Master System Protocol` files
- `memory_center/**`, `launchd/**`
- `production bridges/**`, `wo pipeline core/**`

---

## PR Prompt Contract Format

When GG routes `pr_change` tasks, Andy receives PR Prompt Contracts with:

```
# PR Title
<feat/fix/...: summary>

## Background
- Problem description
- Desired behavior

## Scope
- Allowed files/paths
- Prohibited zones

## Required Changes
- [ ] Task 1
- [ ] Task 2

## Tests
- [ ] Test commands
- [ ] Success criteria

## Safety & Governance
- No modifications to prohibited zones
- Respect Codex Sandbox Mode
```

---

## Links

- **Configuration:** `config/agents/andy.yaml`
- **Persona Prompt:** `agents/andy/PERSONA_PROMPT.md` (System Prompt / Preset)
- **Cursor Command:** `/02luka/andy` (activate in Cursor chat)
- **Agent System Index:** `/agents/README.md`
- **GG Orchestrator Contract:** `docs/GG_ORCHESTRATOR_CONTRACT.md`
- **CLS Documentation:** `/agents/cls/README.md`

---

**Version:** 1.0.0  
**Created:** 2025-11-06  
**Last Modified:** 2025-11-15  
**Phase:** 15
