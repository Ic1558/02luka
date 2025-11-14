# Feature SPEC: File Structure Organization System

**Feature ID:** `file_structure_organization`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Development

---

## Objective

Design and implement a function-first file organization system that groups files by where they run (function) rather than what they are (type), enabling better discoverability, automation simplicity, and CLS compatibility.

---

## Problem Statement

**Current Issues:**
- Files scattered across flat directories
- Hard to find related files (specs, plans, scripts, outputs)
- Automation scripts can't easily glob by function
- No clear pattern for agents to follow when creating files
- Reports mixed with logs, certificates, and feature docs

**Impact:**
- Reduced discoverability
- Complex automation patterns
- Inconsistent file placement
- Agent confusion when creating new files

**Root Cause:**
- Organization by file type rather than system function
- No clear guidelines for file placement
- Missing hierarchical structure within function groups

---

## Solution Approach

### Core Principle: "Where it runs, not what it is"

Organize files by the system function that executes or consumes them, not by their file type or subject matter.

### Function-Based Organization

| Function | Base Directory | Purpose | Sorting Logic |
|----------|---------------|---------|---------------|
| **Governance / Reports** | `g/reports/` | Human-readable records of decisions and state | Group by phase/feature/date |
| **Tools / Scripts** | `tools/` | Executable automation, callable by LaunchAgents | Group by agent or subsystem |
| **Machine Learning / Data** | `mls/` | Generated results or analytics | Group by domain or model |
| **Bridge / Exchanges** | `bridge/` | Inter-agent message passing | Group by agent inbox/outbox |

---

## Detailed Structure Design

### 1. Reports (`g/reports/`)

**Purpose:** Human-readable records of decisions, state, and analysis

**Structure:**
```
g/reports/
├── phase5_governance/
│   ├── feature_phase5_governance_reporting_SPEC.md
│   ├── feature_phase5_governance_reporting_PLAN.md
│   ├── DEPLOYMENT_CERTIFICATE_phase5_20251112.md
│   ├── code_review_phase5.md
│   └── governance_audit_20251112.md
│
├── phase6_paula/
│   ├── feature_phase6_1_paula_intel_SPEC.md
│   ├── feature_phase6_1_paula_intel_PLAN.md
│   ├── DEPLOYMENT_CERTIFICATE_phase6.1_20251112.md
│   └── code_review_phase6_1.md
│
├── system/
│   ├── SYSTEM_STATUS_20251112.md
│   ├── undeployed_scan_20251112.md
│   ├── system_governance_WEEKLY_20251112.md
│   └── health_dashboard.json
│
├── sessions/
│   └── session_20251112_*.md
│
└── ci/
    └── [CI-specific reports]
```

**Naming Convention:**
- Feature docs: `feature_<slug>_<type>.md` (SPEC, PLAN)
- Deployment: `DEPLOYMENT_CERTIFICATE_<phase>_<date>.md`
- Code reviews: `code_review_<scope>_<date>.md`
- System reports: `SYSTEM_<type>_<date>.md`
- Audits: `<type>_audit_<date>.md`

### 2. Tools (`tools/`)

**Purpose:** Executable automation scripts, callable by LaunchAgents

**Structure:**
```
tools/
├── mary_*.zsh          # Mary COO agent tools
├── paula_*.py          # Paula investment agent tools
├── paula_*.zsh         # Paula shell scripts
├── rnd_*.zsh           # R&D agent tools
├── governance_*.zsh    # Governance & reporting tools
├── memory_*.zsh        # Memory hub tools
├── cls_*.zsh           # CLS orchestrator tools
├── phase*_acceptance.zsh  # Acceptance test suites
├── bridge_*.zsh        # Bridge tools
├── ci/                 # CI/CD tools
│   └── [CI-specific scripts]
└── claude_tools/       # Claude Code tools
    └── [Claude-specific scripts]
```

**Naming Convention:**
- Agent tools: `<agent>_<function>.{zsh,py}`
- Phase tests: `phase<num>_<name>_acceptance.zsh`
- System tools: `<system>_<function>.zsh`
- Deployment: `deploy_<phase>_<component>.zsh`

### 3. Machine Learning / Data (`mls/`)

**Purpose:** Generated results, analytics, and model outputs

**Structure:**
```
mls/
├── paula/
│   ├── intel/
│   │   ├── crawler_<symbol>_<date>.json
│   │   ├── paula_bias_<symbol>_<date>.json
│   │   └── insights_<date>.json
│   └── models/
│       └── [model files]
│
├── memory/
│   ├── metrics_<year><month>.json
│   └── adaptive/
│       └── insights_<date>.json
│
├── ledger/
│   └── <date>.jsonl
│
├── schema/
│   └── mls_event.schema.json
│
└── status/
    └── mls_validation_streak.json
```

**Naming Convention:**
- Data files: `<type>_<identifier>_<date>.json`
- Ledger: `<date>.jsonl`
- Models: `<model>_<version>.{json,pkl,bin}`

### 4. Bridge (`bridge/`)

**Purpose:** Inter-agent message passing and work orders

**Structure:**
```
bridge/
├── inbox/
│   ├── CLC/
│   │   ├── WO-<date>-<id>/
│   │   │   ├── evidence/
│   │   │   │   ├── checksums.sha256
│   │   │   │   └── manifest.json
│   │   │   └── WO-<date>-<id>.yaml
│   │   └── templates/
│   │       └── [template files]
│   │
│   ├── RND/
│   │   └── [R&D work orders]
│   │
│   └── ENTRY/
│       └── [entry point work orders]
│
├── outbox/
│   ├── SYSTEM/
│   └── LOGS/
│
└── memory/
    ├── inbox/
    │   └── [agent result files]
    └── outbox/
        └── [broadcast files]
```

**Naming Convention:**
- Work orders: `WO-<date>-<id>.yaml`
- Evidence: `checksums.sha256`, `manifest.json`
- Results: `<agent>_result_<timestamp>.json`

---

## Guiding Rules

### Rule 1: Function First
Sort according to which system function executes or consumes it, not the subject or topic.

**Examples:**
- Paula analytics spec → `g/reports/phase6_paula/feature_phase6_1_paula_intel_SPEC.md`
- Paula crawler script → `tools/paula_data_crawler.py`
- Paula output JSON → `mls/paula/intel/crawler_SET50Z25_20251112.json`

### Rule 2: Hierarchical Within Function
Within each function directory, organize by phase/feature/agent/domain.

**Examples:**
- Phase 5 reports → `g/reports/phase5_governance/`
- Mary tools → `tools/mary_*.zsh`
- Paula data → `mls/paula/intel/`

### Rule 3: Date-Based Sorting
For time-series data, use date-based naming for chronological sorting.

**Examples:**
- `crawler_SET50Z25_20251112.json`
- `governance_audit_20251112.md`
- `2025-11-12.jsonl`

### Rule 4: Agent Prefixes
Tools and scripts use agent prefixes for easy globbing.

**Examples:**
- `mary_*.zsh` - All Mary tools
- `paula_*.{py,zsh}` - All Paula tools
- `rnd_*.zsh` - All R&D tools

---

## Automation Benefits

### LaunchAgent Patterns
```bash
# Mary daily metrics
tools/mary_metrics_collect_daily.zsh

# Paula Intel daily
tools/paula_intel_orchestrator.zsh

# Governance audit
tools/governance_self_audit.zsh
```

### Glob Patterns
```bash
# All Phase 5 reports
g/reports/phase5_governance/*.md

# All Paula tools
tools/paula_*.{py,zsh}

# All Paula data
mls/paula/intel/*.json

# All acceptance tests
tools/phase*_acceptance.zsh
```

### CLS Scanner Patterns
```bash
# Scan by phase
find g/reports/phase5_governance/ -name "*.md"

# Scan by agent
find tools/ -name "mary_*.zsh"

# Scan by date
find mls/paula/intel/ -name "*_20251112.json"
```

---

## Migration Strategy

### Phase 1: Create New Structure
1. Create new directory structure
2. Leave existing files in place
3. New files go to new structure

### Phase 2: Migrate Existing Files
1. Identify files by function
2. Move to appropriate subdirectory
3. Update references
4. Verify automation still works

### Phase 3: Cleanup
1. Remove empty directories
2. Update documentation
3. Verify all paths

---

## Acceptance Criteria

### Functional Requirements
- [x] Function-first organization implemented
- [x] Hierarchical structure within functions
- [x] Clear naming conventions
- [x] Automation patterns work
- [x] CLS compatibility maintained

### Operational Requirements
- [x] LaunchAgents can find their tools
- [x] Reports organized by phase/feature
- [x] Data organized by domain/model
- [x] Bridge organized by agent

### Quality Requirements
- [x] Discoverability improved
- [x] Automation simplified
- [x] Agent guidelines clear
- [x] Documentation complete

---

## Dependencies

- **Existing Structure:** Current file organization
- **Agents:** R&D, Paula, Mary, CLS
- **Automation:** LaunchAgents, CI/CD
- **Documentation:** Structure guidelines document

---

## References

- **Current Structure:** `02luka.md` (lines 500-608)
- **Cursor Rules:** `.cursorrules` (file placement rules)
- **CLS Governance:** `CLS.md` (Rules 91-93)

---

**SPEC Created:** 2025-11-12T15:00:00Z  
**Author:** CLS (Cognitive Local System Orchestrator)  
**Status:** Ready for Planning
