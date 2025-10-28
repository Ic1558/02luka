# 02luka Project Summary

## Overview
02luka delivers a deployable local AI agent gateway with a complementary Boss workspace. The system exposes HTTP-accessible services for agent capability discovery, a Vite-based Boss UI, and automation to synchronize multi-agent memory stores. The repository is structured to support both backend APIs and operational tooling for coordinating Claude Code and Cursor AI contexts.

## Key Components
- **Gateway & UI Assets**: Entry points such as `luka.html` and `index.html` provide the lightweight agent interface alongside the Vite-powered Boss UI found under `boss-ui/`.
- **Boss API Backend**: `boss-api/` contains the Node.js server and supporting modules used by the Boss workspace for task orchestration.
- **Dual Memory System**: Memory sources of truth live under `memory/` for each agent while `a/` retains Claude Code (CLC) protocols and hybrid memory bridges for synchronizing with Cursor AI.
- **Automation & Tooling**: The `g/` directory centralizes operational scripts, reports, and bridge services, enabling autosave routines, health audits, and integration helpers.

## Development Routines
Common developer flows include one-command startup scripts (`./run_local.sh`, `./run/dev_morning.sh`) and health checks (`./run/smoke_api_ui.sh`) described in the top-level README. These scripts coordinate local gateways, port forwarding, and automated morning setup for consistent environments.

## Repository Organization
The repository follows the "Hybrid Spine" structure described in `docs/REPOSITORY_STRUCTURE.md`, emphasizing:
- Dedicated zones for agent logic (`a/`), human workflow (`boss/`), and system foundations (`f/`).
- Auto-generated catalogs for reports and memory that keep the Boss workspace in sync with authoritative data.
- Guardrails that enforce memory session placement under `memory/` through pre-commit hooks.

## Usage Highlights
Developers can access the live demo at `https://ic1558.github.io/02luka/` or run local services via direct HTTP access to ports 4000 (API), 5173 (UI), and 8765 (MCP FS stub). Optional tunneling scripts automate public access when needed. Health and audit scripts within `g/tools/` support continuous monitoring of agent states and task events.
