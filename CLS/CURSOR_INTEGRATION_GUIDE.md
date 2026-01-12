# CLS (Cursor Language Server) Integration Guide

## Overview

CLS is the AI agent running in [Cursor IDE](https://cursor.com). This directory contains integration files for CLS to work effectively with the 02luka project.

## Configuration

### Primary Configuration
- **`.cursorrules`** - Main rules file at repository root
- **`CLS/`** - This directory for extended context

### Agent Identity
- Agent ID: `CLS` (Cursor Language Server)
- Role: Senior developer with full read/write access
- Governance: Follows same lane governance as other agents

## Directory Structure

```
CLS/
├── CURSOR_INTEGRATION_GUIDE.md  # This file
└── context/                      # Extended context (optional)

memory/cls/                       # CLS session memory
└── sessions/                     # Session logs
```

## Workflow

1. **Read** `.cursorrules` for project conventions
2. **Follow** lane governance (dev/qa/prod lanes)
3. **Use** tools from `tools/` directory when available
4. **Log** significant actions to `g/reports/`

## Key Paths

| Purpose | Path |
|---------|------|
| SOT Root | `/Users/icmini/02luka` |
| Working | `/Users/icmini/02luka/g` |
| Tools | `~/02luka/tools/` |
| Agents | `~/02luka/agents/` |
| Reports | `~/02luka/g/reports/` |

## Integration with Other Agents

- **GMX** (Gemini CLI) - Primary execution agent
- **CLC** (Claude Code) - Code review and planning
- **LAC** (Local Agent Coordinator) - Autonomous worker
- **Mary** (Router) - Work order routing

---
*Generated: 2026-01-13*
