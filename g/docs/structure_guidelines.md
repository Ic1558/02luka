# 02Luka File Structure Guidelines

**Version:** 1.0.0  
**Last Updated:** 2025-11-12  
**Status:** Active

---

## Core Principle

**"Where it runs, not what it is."**

Organize files by the system function that executes or consumes them, not by their file type or subject matter.

---

## Function-Based Organization

| Function | Base Directory | Purpose | Sorting Logic |
|----------|---------------|---------|---------------|
| **Governance / Reports** | `g/reports/` | Human-readable records of decisions and state | Group by phase/feature/date |
| **Tools / Scripts** | `tools/` | Executable automation, callable by LaunchAgents | Group by agent or subsystem |
| **Machine Learning / Data** | `mls/` | Generated results or analytics | Group by domain or model |
| **Bridge / Exchanges** | `bridge/` | Inter-agent message passing | Group by agent inbox/outbox |

---

## Directory Structure

### 1. Reports (`g/reports/`)

**Purpose:** Human-readable records of decisions, state, and analysis

```
g/reports/
├── phase5_governance/          # Phase 5: Governance & Reporting
│   ├── feature_phase5_governance_reporting_SPEC.md
│   ├── feature_phase5_governance_reporting_PLAN.md
│   ├── DEPLOYMENT_CERTIFICATE_phase5_20251112.md
│   ├── code_review_phase5.md
│   └── governance_audit_20251112.md
│
├── phase6_paula/               # Phase 6: Paula Data Intelligence
│   ├── feature_phase6_1_paula_intel_SPEC.md
│   ├── feature_phase6_1_paula_intel_PLAN.md
│   ├── DEPLOYMENT_CERTIFICATE_phase6.1_20251112.md
│   └── code_review_phase6_1.md
│
├── system/                     # System-wide reports
│   ├── SYSTEM_STATUS_20251112.md
│   ├── undeployed_scan_20251112.md
│   ├── system_governance_WEEKLY_20251112.md
│   └── health_dashboard.json
│
├── sessions/                   # Session reports
│   └── session_20251112_*.md
│
└── ci/                        # CI/CD reports
    └── [CI-specific reports]
```

**Naming Conventions:**
- Feature docs: `feature_<slug>_<type>.md` (SPEC, PLAN)
- Deployment: `DEPLOYMENT_CERTIFICATE_<phase>_<date>.md`
- Code reviews: `code_review_<scope>_<date>.md`
- System reports: `SYSTEM_<type>_<date>.md`
- Audits: `<type>_audit_<date>.md`

### 2. Tools (`tools/`)

**Purpose:** Executable automation scripts, callable by LaunchAgents

```
tools/
├── mary_*.zsh                 # Mary COO agent tools
├── paula_*.py                 # Paula investment agent tools (Python)
├── paula_*.zsh                # Paula investment agent tools (Shell)
├── rnd_*.zsh                  # R&D agent tools
├── governance_*.zsh           # Governance & reporting tools
├── memory_*.zsh              # Memory hub tools
├── cls_*.zsh                 # CLS orchestrator tools
├── phase*_acceptance.zsh     # Acceptance test suites
├── bridge_*.zsh              # Bridge tools
├── ci/                       # CI/CD tools
│   └── [CI-specific scripts]
└── claude_tools/             # Claude Code tools
    └── [Claude-specific scripts]
```

**Naming Conventions:**
- Agent tools: `<agent>_<function>.{zsh,py}`
- Phase tests: `phase<num>_<name>_acceptance.zsh`
- System tools: `<system>_<function>.zsh`
- Deployment: `deploy_<phase>_<component>.zsh`

### 3. Machine Learning / Data (`mls/`)

**Purpose:** Generated results, analytics, and model outputs

```
mls/
├── paula/                     # Paula domain data
│   ├── intel/                # Intelligence outputs
│   │   ├── crawler_<symbol>_<date>.json
│   │   ├── paula_bias_<symbol>_<date>.json
│   │   └── insights_<date>.json
│   └── models/               # Model files
│       └── [model files]
│
├── memory/                    # Memory domain data
│   ├── metrics_<year><month>.json
│   └── adaptive/             # Adaptive insights
│       └── insights_<date>.json
│
├── ledger/                    # MLS ledger (append-only)
│   └── <date>.jsonl
│
├── schema/                    # MLS schemas
│   └── mls_event.schema.json
│
└── status/                    # MLS status files
    └── mls_validation_streak.json
```

**Naming Conventions:**
- Data files: `<type>_<identifier>_<date>.json`
- Ledger: `<date>.jsonl`
- Models: `<model>_<version>.{json,pkl,bin}`

### 4. Bridge (`bridge/`)

**Purpose:** Inter-agent message passing and work orders

```
bridge/
├── inbox/                     # Incoming work orders
│   ├── CLC/                  # Claude Code work orders
│   │   ├── WO-<date>-<id>/   # Work order directory
│   │   │   ├── evidence/     # Evidence files
│   │   │   │   ├── checksums.sha256
│   │   │   │   └── manifest.json
│   │   │   └── WO-<date>-<id>.yaml
│   │   └── templates/        # Work order templates
│   │
│   ├── RND/                  # R&D work orders
│   └── ENTRY/                # Entry point work orders
│
├── outbox/                   # Outgoing messages
│   ├── SYSTEM/
│   └── LOGS/
│
└── memory/                   # Memory bridge
    ├── inbox/                # Agent results
    └── outbox/               # Broadcast messages
```

**Naming Conventions:**
- Work orders: `WO-<date>-<id>.yaml`
- Evidence: `checksums.sha256`, `manifest.json`
- Results: `<agent>_result_<timestamp>.json`

---

## File Placement Decision Tree

### Step 1: Identify Function

**Question:** Which system function executes or consumes this file?

- **Governance/Reports** → `g/reports/`
- **Executable Script** → `tools/`
- **Generated Data** → `mls/`
- **Inter-Agent Message** → `bridge/`

### Step 2: Identify Category

**For Reports (`g/reports/`):**
- **Phase-specific** → `g/reports/phase<num>_<name>/`
- **System-wide** → `g/reports/system/`
- **Session** → `g/reports/sessions/`
- **CI/CD** → `g/reports/ci/`

**For Tools (`tools/`):**
- **Agent-specific** → `tools/<agent>_*.{zsh,py}`
- **System-wide** → `tools/<system>_*.zsh`
- **Phase tests** → `tools/phase*_acceptance.zsh`
- **Subsystem** → `tools/<subsystem>/`

**For Data (`mls/`):**
- **Domain-specific** → `mls/<domain>/`
- **Ledger** → `mls/ledger/`
- **Schema** → `mls/schema/`
- **Status** → `mls/status/`

**For Bridge (`bridge/`):**
- **Inbox** → `bridge/inbox/<agent>/`
- **Outbox** → `bridge/outbox/<system>/`
- **Memory** → `bridge/memory/<direction>/`

### Step 3: Apply Naming Convention

Use the appropriate naming convention for the file type and location.

---

## Examples

### Example 1: Paula Analytics Spec

**Question:** Where does it run?
- **Answer:** It's a report about Phase 6.1 Paula feature
- **Location:** `g/reports/phase6_paula/feature_phase6_1_paula_intel_SPEC.md`

### Example 2: Paula Crawler Script

**Question:** Where does it run?
- **Answer:** It's an executable tool for Paula agent
- **Location:** `tools/paula_data_crawler.py`

### Example 3: Paula Output JSON

**Question:** Where does it run?
- **Answer:** It's generated data from Paula analytics
- **Location:** `mls/paula/intel/crawler_SET50Z25_20251112.json`

### Example 4: Governance Audit Report

**Question:** Where does it run?
- **Answer:** It's a report from Phase 5 governance
- **Location:** `g/reports/phase5_governance/governance_audit_20251112.md`

### Example 5: Mary Metrics Tool

**Question:** Where does it run?
- **Answer:** It's an executable tool for Mary agent
- **Location:** `tools/mary_metrics_collect_daily.zsh`

---

## Automation Patterns

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

## Common Mistakes to Avoid

### ❌ Don't Organize by File Type

**Bad:**
```
docs/
  ├── specs/
  ├── plans/
  └── certificates/
```

**Good:**
```
g/reports/
  ├── phase5_governance/
  │   ├── feature_*.md
  │   └── DEPLOYMENT_*.md
```

### ❌ Don't Mix Functions

**Bad:**
```
tools/
  ├── paula_data.json        # Data file in tools/
  └── paula_spec.md          # Report in tools/
```

**Good:**
```
tools/
  └── paula_data_crawler.py  # Executable script

mls/
  └── paula/intel/data.json  # Generated data

g/reports/
  └── phase6_paula/spec.md   # Report
```

### ❌ Don't Use Generic Names

**Bad:**
```
tools/script1.zsh
g/reports/report1.md
```

**Good:**
```
tools/paula_intel_orchestrator.zsh
g/reports/phase6_paula/feature_phase6_1_paula_intel_PLAN.md
```

---

## Agent Guidelines

### For R&D Agent

**Creating a new feature:**
1. Create SPEC: `g/reports/phase<num>_<name>/feature_<slug>_SPEC.md`
2. Create PLAN: `g/reports/phase<num>_<name>/feature_<slug>_PLAN.md`
3. Create tools: `tools/<agent>_<function>.{zsh,py}`
4. Create tests: `tools/phase<num>_<name>_acceptance.zsh`

### For Paula Agent

**Creating analytics:**
1. Create script: `tools/paula_<function>.py`
2. Output data: `mls/paula/intel/<type>_<symbol>_<date>.json`
3. Create reports: `g/reports/phase6_paula/<type>_<date>.md`

### For CLS Orchestrator

**Creating reports:**
1. System reports: `g/reports/system/SYSTEM_<type>_<date>.md`
2. Scans: `g/reports/system/<type>_scan_<date>.md`
3. Audits: `g/reports/system/<type>_audit_<date>.md`

### For Mary COO

**Creating tools:**
1. Agent tools: `tools/mary_<function>.zsh`
2. Reports: `g/reports/system/mary_<type>_<date>.md`
3. Metrics: `mls/memory/metrics_<year><month>.json`

---

## Migration Guide

### For Existing Files

1. **Identify Function:**
   - Which system function uses this file?
   - Where does it run?

2. **Identify Category:**
   - Which phase/agent/domain?
   - Which subsystem?

3. **Move to New Location:**
   - Create directory if needed
   - Move file
   - Update references

4. **Update References:**
   - Search for old paths
   - Update to new paths
   - Test functionality

---

## Validation

### Structure Validation

```bash
# Verify directory structure
find g/reports/ -type d
find tools/ -name "*_*.{zsh,py}" | head -20
find mls/ -type d
```

### Naming Validation

```bash
# Check naming conventions
find g/reports/ -name "feature_*_SPEC.md"
find tools/ -name "<agent>_*.zsh"
find mls/ -name "*_<date>.json"
```

### Automation Validation

```bash
# Test LaunchAgent paths
launchctl list | grep -E "(mary|paula|governance)"

# Test glob patterns
ls tools/paula_*.{py,zsh}
ls g/reports/phase5_governance/*.md
```

---

## Repository Strategy

### Single Repository (02luka/)

**Principle:** Use single repository for all system components.

**Rationale:**
- `02luka-memory` was experimental and is now redundant
- Current system has `shared_memory/` + Redis Hub
- Self-auditing and daily digest already in main repo
- No need for separate memory repository

**Structure:**
- All memory, digest, and reports in `02luka/`
- Weekly push to remote for backup (via cron/LaunchAgent)
- No separate memory repository needed

### Manual vs Automated Files

**Principle:** Manual and automated files use same structure and naming.

**Guidelines:**
- Manual reports follow same function-based structure
- Use same naming conventions
- Use same date patterns
- Don't mix manual/auto in separate folders

**Examples:**
| Type | Location | Example Name |
|------|----------|--------------|
| Weekly Governance (manual) | `g/reports/system/` | `system_governance_WEEKLY_20251116.md` |
| R&D Summary (manual) | `g/reports/phaseX_rnd/` | `feature_phaseX_rnd_summary_20251116.md` |
| Paula Performance (manual) | `g/reports/phase6_paula/` | `paula_weekly_performance_20251116.md` |
| Mary Ops Digest (manual) | `g/reports/system/` | `mary_ops_digest_20251116.md` |

## Weekly Recap System

### Purpose

Aggregate daily digests into weekly governance reports for better system overview.

### Structure

**Daily Reports:**
```
g/reports/system/daily_digest_20251110.md
g/reports/system/daily_digest_20251111.md
...
```

**Weekly Recap (Auto-generated):**
```
g/reports/system/system_governance_WEEKLY_20251116.md
```

### Generation

**Tool:** `tools/weekly_recap_generator.zsh`

**Schedule:** Sunday 08:00 (via LaunchAgent)

**Process:**
1. Collects all daily digests from past week
2. Extracts key sections and summaries
3. Aggregates metrics
4. Generates weekly report

### Governance Flow

```
Daily (07:05)
  ├─ memory_daily_digest.zsh
  ├─ paula_intel_orchestrator.zsh
  └─ mary_metrics_collect_daily.zsh
      ↓
Weekly (Sunday 08:00)
  ├─ weekly_recap_generator.zsh ← Aggregate daily digests
  ├─ governance_self_audit.zsh ← Audit report integrity
      ↓
Monthly
  ├─ memory_metrics_collector.zsh
  └─ governance_report_generator.zsh
```

## References

- **SPEC:** `g/reports/feature_file_structure_organization_SPEC.md`
- **PLAN:** `g/reports/feature_file_structure_organization_PLAN.md`
- **Current Structure:** `02luka.md` (lines 500-608)
- **Cursor Rules:** `.cursorrules`
- **Migration Script:** `tools/fsorg_migrate.zsh`
- **Weekly Recap:** `tools/weekly_recap_generator.zsh`

---

**Guidelines Created:** 2025-11-12T15:10:00Z  
**Last Updated:** 2025-11-12T15:30:00Z  
**Author:** CLS (Cognitive Local System Orchestrator)  
**Status:** Active
