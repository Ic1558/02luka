# Phase 21: Hub Infrastructure — PR Templates

This directory contains comprehensive PR body templates for Phase 21 implementation.

## Quick Start

```bash
# Display all PR creation info
./tools/create_phase21_prs.zsh

# Or manually visit these URLs:
```

## PRs in This Phase

### 1. Phase 21.1 — Hub Mini UI
**Branch**: `claude/phase-21-1-hub-mini-ui-011CUvQ8F4cVZPzH4rT1a1cM`
**Template**: `phase-21-1-hub-mini-ui.md`
**PR URL**: https://github.com/Ic1558/02luka/pull/new/claude/phase-21-1-hub-mini-ui-011CUvQ8F4cVZPzH4rT1a1cM

**Summary**: Lightweight static web dashboard for hub status visualization

**Key Features**:
- 3-card dashboard (Index, Registry, Health)
- Vanilla JS async JSON fetcher
- Zero dependencies, ~4KB total
- Dev server helper script
- CI validation workflow

---

### 2. Phase 21.2 — Memory Guard
**Branch**: `claude/phase-21-2-memory-guard-011CUvQ8F4cVZPzH4rT1a1cM`
**Template**: `phase-21-2-memory-guard.md`
**PR URL**: https://github.com/Ic1558/02luka/pull/new/claude/phase-21-2-memory-guard-011CUvQ8F4cVZPzH4rT1a1cM

**Summary**: Automated size and pattern enforcement for memory repository

**Key Features**:
- Two-tier thresholds (10MB warn, 25MB fail)
- Pattern-based deny list (node_modules, SQLite, etc.)
- YAML configuration with JSON schema
- Local enforcement script
- CI workflow integration

---

### 3. Phase 21.3 — Protection Enforcer
**Branch**: `claude/phase-21-3-protection-enforcer-011CUvQ8F4cVZPzH4rT1a1cM`
**Template**: `phase-21-3-protection-enforcer.md`
**PR URL**: https://github.com/Ic1558/02luka/pull/new/claude/phase-21-3-protection-enforcer-011CUvQ8F4cVZPzH4rT1a1cM

**Summary**: Branch protection rule validator with auto-commenting

**Key Features**:
- Validates required checks vs. actual workflow jobs
- Auto-comments on PRs when mismatches detected
- Nightly schedule + PR triggers
- Canonical config in JSON
- Local validation script

---

## How to Create PRs

### Option 1: Web UI (Recommended)

1. Click the PR URL for each phase above
2. Open the corresponding template file in this directory
3. Copy the entire content
4. Paste into the PR body field
5. Review and click "Create pull request"

### Option 2: Command Line (requires `gh` CLI)

```bash
# Phase 21.1
gh pr create --title "feat(phase-21.1): Hub Mini UI (static status & API shim)" \
  --body-file .pr-templates/phase-21-1-hub-mini-ui.md \
  --head claude/phase-21-1-hub-mini-ui-011CUvQ8F4cVZPzH4rT1a1cM

# Phase 21.2
gh pr create --title "feat(phase-21.2): Memory repo size/pattern guard" \
  --body-file .pr-templates/phase-21-2-memory-guard.md \
  --head claude/phase-21-2-memory-guard-011CUvQ8F4cVZPzH4rT1a1cM

# Phase 21.3
gh pr create --title "feat(phase-21.3): Branch protection enforcer & PR comment" \
  --body-file .pr-templates/phase-21-3-protection-enforcer.md \
  --head claude/phase-21-3-protection-enforcer-011CUvQ8F4cVZPzH4rT1a1cM
```

### Option 3: Use Helper Script

```bash
./tools/create_phase21_prs.zsh
```

This displays all URLs, titles, and commands in a formatted view.

---

## Testing Before PR

Each phase includes local verification commands:

```bash
# Phase 21.1 - Hub UI
./tools/hub_http.zsh
open http://localhost:8080/ui/index.html

# Phase 21.2 - Memory Guard
LUKA_MEM_REPO_ROOT="$HOME/LocalProjects/02luka-memory" ./tools/check_memory_guard.zsh

# Phase 21.3 - Protection Enforcer
node tools/required_checks_assert.mjs
```

---

## File Inventory

| Phase | Files Added | LOC | Dependencies |
|-------|-------------|-----|--------------|
| 21.1  | 5           | 109 | 0            |
| 21.2  | 4           | 99  | yq (CI only) |
| 21.3  | 3           | 61  | 0            |
| **Total** | **12**  | **269** | **minimal** |

---

## PR Checklist

Before creating each PR, ensure:

- [ ] All files committed and pushed to branch
- [ ] Branch name matches session ID: `*-011CUvQ8F4cVZPzH4rT1a1cM`
- [ ] Local tests passing
- [ ] Template content reviewed for accuracy
- [ ] Title follows conventional commit format: `feat(phase-21.X): ...`

---

## Related Documentation

- Phase 21 main spec: *(link to design doc if available)*
- Hub infrastructure overview: *(link to architecture doc)*
- Branch protection settings: https://github.com/Ic1558/02luka/settings/branches

---

**Generated**: 2025-11-08
**Session ID**: 011CUvQ8F4cVZPzH4rT1a1cM
**Implementation**: Claude Code (Sonnet 4.5)
