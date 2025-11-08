# Heredoc & Path Scanner

## Quick Start

```bash
# Scan entire repository
./tools/scan_heredoc_issues.sh

# Scan specific directory
./tools/scan_heredoc_issues.sh .github/workflows

# View detailed report
cat /tmp/heredoc-scan-report.txt
```

## What It Scans

### ✅ All Heredoc Issues Detected

1. **HIGH**: Single-quoted heredocs with GitHub Actions variables
   - Pattern: `<<'EOF'` with `${{ ... }}` inside
   - Impact: Variables won't expand in GitHub Actions
   - Fix: Change to `<<EOF` and extract variables

2. **MEDIUM**: Single-quoted heredocs with shell variables
   - Pattern: `<<'EOF'` with `$VAR` or `$(cmd)` inside
   - Impact: Variables won't expand
   - Fix: Change to `<<EOF` or keep intentional

3. **INFO**: Hardcoded paths
   - Pattern: `/Users/username` or `/home/username`
   - Impact: Not portable across systems
   - Fix: Use `${HOME}` or environment variables

## Your Repository Status

✅ **Heredoc Issues**: NONE (already fixed in commits 5d86bb3, 2fcf0f3)

ℹ️ **Hardcoded Paths**: 12 found
- `./compose-up.sh:22`
- `./scripts/env_setup.sh:4,5`
- `./docker-compose.yml:65,102,139`
- Config files in prometheus/grafana

## Quick Fixes

### For GitHub Actions Files

**Before:**
```yaml
cat <<'EOF'
## Release ${{ steps.version.outputs.tag }}
EOF
```

**After:**
```yaml
TAG="${{ steps.version.outputs.tag }}"
cat <<EOF
## Release ${TAG}
EOF
```

### For Hardcoded Paths

**Before:**
```bash
cd /Users/icmini/project
```

**After:**
```bash
cd "${HOME}/project"
```

## Files Created

- `tools/scan_heredoc_issues.sh` - Scanner script
- `tools/fix_heredoc_issues.sh` - Interactive fixer
- `docs/heredoc-scanning-guide.md` - Comprehensive guide

## See Also

- Full documentation: `docs/heredoc-scanning-guide.md`
- Bash heredoc syntax: `man bash` (search "/Here Documents")
- Fixed examples: commits `5d86bb3`, `2fcf0f3`
