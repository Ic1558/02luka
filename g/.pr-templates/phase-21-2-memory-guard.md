## 🎯 Summary

Implements automated size and pattern enforcement for the `memory/**` repository to prevent accidental commits of large files, binary artifacts, and forbidden patterns. This guard ensures repository health and prevents bloat.

## 📦 Changes

### Configuration
- **`config/memory_guard.yaml`** — Enforcement rules and thresholds
  - **Thresholds**: Warn at 10MB, fail at 25MB
  - **Deny globs**: `node_modules`, `*.sqlite`, `*.psd`, `.ipynb_checkpoints`
  - **Allow globs**: Common text/image formats
  - **Configurable root**: Via `LUKA_MEM_REPO_ROOT` env var

- **`config/schemas/memory_guard.schema.json`** — JSON Schema for YAML validation
  - Provides editor autocomplete and validation
  - Enforces required fields and types
  - Minimum value constraints for thresholds

### Tools
- **`tools/check_memory_guard.zsh`** — Local enforcement script
  - **Size checks**: Scans all files, reports warnings/failures
  - **Pattern checks**: Validates against deny globs
  - **Exit codes**: 0 = pass, 1 = violations found, 127 = missing deps
  - **Dependencies**: Requires `yq` for YAML parsing
  - **Usage**: `./tools/check_memory_guard.zsh` or `LUKA_MEM_REPO_ROOT=/custom/path ./tools/check_memory_guard.zsh`

### CI/CD
- **`.github/workflows/memory-guard.yml`** — Automated PR validation
  - Triggers on changes to `memory/**`, config, or workflow itself
  - Installs `yq` (v4.44.3)
  - Creates placeholder directory if needed
  - Fails PR if violations detected

## ✅ Verification

### Local Testing
```bash
# Test against default location
LUKA_MEM_REPO_ROOT="$HOME/LocalProjects/02luka-memory" ./tools/check_memory_guard.zsh

# Test against custom location
LUKA_MEM_REPO_ROOT="/path/to/memory" ./tools/check_memory_guard.zsh

# Expected output examples:
# ✓ All files under thresholds
# ⚠️  WARN size 15MB: /path/to/large-file.zip
# ❌ FAIL size 30MB: /path/to/huge-file.bin
# ❌ DENY pattern: /path/to/node_modules/package
```

### Expected Behavior
- **< 10MB**: Silent pass
- **10-25MB**: Warning (non-blocking)
- **> 25MB**: Failure (blocks PR merge)
- **Forbidden patterns**: Always fail

### Dependencies
- **`yq`** — YAML query processor (auto-installed in CI)
  - Install locally: `brew install yq` (macOS) or download from GitHub

## 🔍 Implementation Notes

### Design Decisions
1. **Two-Tier Thresholds** — Warn before fail
   - Gives visibility to borderline files
   - Allows exceptions to be documented
   - Prevents silent growth

2. **Pattern-Based Enforcement** — Beyond just size
   - Blocks common accidental commits (node_modules, build artifacts)
   - Catches database files that shouldn't be in version control
   - Extensible via config without code changes

3. **Environment-Based Root** — Flexible repository location
   - Default: `$HOME/LocalProjects/02luka-memory`
   - Override: `LUKA_MEM_REPO_ROOT=/custom/path`
   - CI uses: `$GITHUB_WORKSPACE/memory`

### Limitations & Future Work
- **Current**: Only checks file size, not git blob size
- **Future**: Add git-aware checks for committed file history
- **Future**: Whitelist mechanism for legitimate large files (datasets, ML models)
- **Future**: Auto-suggest Git LFS for files > threshold

## 🧪 Test Plan

- [x] Config YAML valid and schema-compliant
- [x] Script executable with correct permissions
- [x] Size checks work (10MB warn, 25MB fail)
- [x] Pattern checks catch forbidden globs
- [x] CI workflow installs yq successfully
- [x] Workflow triggers on correct paths
- [x] Exit codes correct (0 = pass, 1 = fail)
- [x] Pushed to `claude/phase-21-2-memory-guard-011CUvQ8F4cVZPzH4rT1a1cM`

## 📊 Metrics

| Metric | Value |
|--------|-------|
| Files added | 4 |
| Lines of code | ~99 |
| Denied patterns | 4 (extensible) |
| Warn threshold | 10 MB |
| Fail threshold | 25 MB |

## 🔗 Related

- Part of **Phase 21: Hub Infrastructure** initiative
- Protects the memory repository from bloat
- Complements Phase 21.1 (Hub UI) and Phase 21.3 (Protection Enforcer)

## 🚨 Breaking Changes

None - this is a new feature with no impact on existing workflows.

## 📋 Configuration Reference

```yaml
thresholds:
  warn_mb: 10      # Yellow flag: notify but don't block
  fail_mb: 25      # Red flag: block PR merge

deny_globs:        # Patterns that always fail
  - "**/node_modules/**"
  - "**/*.sqlite"
  - "**/*.psd"
  - "**/*.ipynb_checkpoints/**"

allow_globs:       # Patterns that skip checks (future use)
  - "**/*.md"
  - "**/*.json"
  - "**/*.txt"
  - "**/*.png"
  - "**/*.jpg"

paths:
  repo_root_env: LUKA_MEM_REPO_ROOT  # Env var name
```
