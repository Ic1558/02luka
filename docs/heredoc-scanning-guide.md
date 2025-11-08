# Heredoc & Path Scanning Guide

## Quick Start

Scan your entire repository for heredoc and path issues:

```bash
./tools/scan_heredoc_issues.sh
```

Review and fix issues interactively:

```bash
./tools/fix_heredoc_issues.sh /tmp/heredoc-scan-report.txt
```

---

## What This Scans For

### 1. **HIGH Priority**: Single-quoted heredocs with variables

**Problem:**
```bash
# ❌ WRONG - Variables won't expand
cat <<'EOF'
Hello $USER, today is $(date)
GitHub PR: ${{ github.event.number }}
EOF
```

**Output:**
```
Hello $USER, today is $(date)
GitHub PR: ${{ github.event.number }}
```

**Fix:**
```bash
# ✅ CORRECT - Variables will expand
USERNAME="$USER"
TODAY="$(date)"
PR_NUM="${{ github.event.number }}"

cat <<EOF
Hello ${USERNAME}, today is ${TODAY}
GitHub PR: ${PR_NUM}
EOF
```

**Output:**
```
Hello john, today is Thu Nov 6 10:30:00 UTC 2025
GitHub PR: 123
```

---

### 2. **MEDIUM Priority**: Shell variable expansion issues

Detects when shell variables (`$VAR`, `${VAR}`, `$(cmd)`) are in single-quoted heredocs.

---

### 3. **LOW Priority**: Code in unquoted heredocs

**Note:** This is actually often INTENTIONAL, but scanner flags it for review.

```bash
# Intentional: Static Python code should be quoted
cat > script.py <<'PYTHON'
#!/usr/bin/env python3
import sys

def main():
    print("Hello World")  # $() won't expand here

if __name__ == "__main__":
    main()
PYTHON
```

---

### 4. **INFO**: Hardcoded paths

Detects absolute paths like `/home/username/` that might break on other systems.

**Fix:** Use environment variables or relative paths:
```bash
# Instead of:
cd /home/john/myproject

# Use:
cd "${HOME}/myproject"
# or
cd "${REPO_ROOT}"
```

---

## Heredoc Quoting Reference

| Pattern | Variables Expand? | Use Case | Example |
|---------|-------------------|----------|---------|
| `<<EOF` | ✅ YES | Dynamic content with variables | Logs, templated output |
| `<<'EOF'` | ❌ NO | Static content, code blocks | Python scripts, SQL, docs |
| `<<"EOF"` | ✅ YES | Same as unquoted | Rare usage |
| `<<-EOF` | ✅ YES | Tab-indented heredoc | Legacy scripts |
| `<<-'EOF'` | ❌ NO | Tab-indented static | Legacy scripts |

---

## Common Patterns

### ✅ GitHub Actions Variable Expansion

```yaml
- name: Create release
  run: |
    # Extract GHA variables to shell first
    TAG="${{ steps.version.outputs.tag }}"
    TITLE="${{ github.event.pull_request.title }}"
    BODY="${{ github.event.pull_request.body }}"

    # Use unquoted heredoc
    cat > release.md <<EOF
    ## Release ${TAG}

    **PR**: ${TITLE}

    ${BODY}
    EOF

    gh release create "${TAG}" --notes-file release.md
```

### ✅ Embedded Python Script

```bash
# Use single quotes to prevent shell expansion
cat > analyze.py <<'PYTHON'
#!/usr/bin/env python3
import sys
import json

def analyze(data):
    # Shell won't try to expand $(...)
    result = sum([x for x in data])
    return result

if __name__ == "__main__":
    print(analyze([1, 2, 3]))
PYTHON

chmod +x analyze.py
python3 analyze.py
```

### ✅ SQL with Dynamic Timestamp

```bash
# Unquoted - need $(date) to expand
sqlite3 db.sqlite <<SQL
INSERT INTO logs (timestamp, message)
VALUES ('$(date -u +"%Y-%m-%dT%H:%M:%SZ")', 'System started');
SQL
```

### ✅ JSON Template with Variables

```bash
API_KEY="secret123"
USER_ID="user456"

# Unquoted for variable expansion
cat > config.json <<JSON
{
  "apiKey": "${API_KEY}",
  "userId": "${USER_ID}",
  "timestamp": "$(date -u +%s)"
}
JSON
```

---

## Manual Fix Steps

When the scanner finds issues:

### For GitHub Actions Files

1. **Identify all GHA variables** (`${{ ... }}`)

2. **Extract to shell variables** before heredoc:
   ```yaml
   VAR_NAME="${{ github.context.value }}"
   ```

3. **Change heredoc delimiter** from `<<'EOF'` to `<<EOF`

4. **Use shell variable syntax** inside heredoc:
   ```yaml
   cat <<EOF
   Value: ${VAR_NAME}
   EOF
   ```

### For Shell Scripts

1. **Determine intent**: Do you WANT variable expansion?

2. **If YES**: Use unquoted heredoc `<<EOF`
   - Extract variables before heredoc
   - Use `${VAR}` syntax inside

3. **If NO**: Keep single quotes `<<'EOF'`
   - For static content
   - For embedded code (Python, SQL, etc.)

---

## Testing Your Fixes

After applying fixes:

```bash
# Run scanner again
./tools/scan_heredoc_issues.sh

# Test in GitHub Actions (for workflow files)
git add .
git commit -m "fix: heredoc variable expansion"
git push

# Monitor workflow run for proper variable expansion
```

---

## Examples from This Repo

### Fixed Issue: `.github/workflows/auto-tag-phase.yml`

**Before (Broken):**
```yaml
- run: |
    cat > /tmp/release.md <<'EOF'
    ## Phase ${{ steps.phase.outputs.number }}
    PR: #${{ github.event.pull_request.number }}
    EOF
```

**After (Fixed):**
```yaml
- run: |
    PHASE="${{ steps.phase.outputs.number }}"
    PR_NUM="${{ github.event.pull_request.number }}"

    cat > /tmp/release.md <<EOF
    ## Phase ${PHASE}
    PR: #${PR_NUM}
    EOF
```

**Commits:** `5d86bb3`, `2fcf0f3`

---

## Best Practices

1. **Default to single quotes** for static content
2. **Only remove quotes** when you need variable expansion
3. **Extract variables first** before heredoc (especially GHA variables)
4. **Use `${VAR}` syntax** inside heredocs for clarity
5. **Test your changes** in actual execution environment

---

## Troubleshooting

### Variables not expanding?

- Check heredoc delimiter has NO quotes: `<<EOF` not `<<'EOF'`
- Verify variables are defined before heredoc
- Use `${VAR}` not `$VAR` for clarity

### Code being interpreted as commands?

- Use single quotes: `<<'EOF'`
- Escape problematic characters
- Consider alternative approaches (separate file, printf, etc.)

### Path not found errors?

- Use environment variables: `${HOME}`, `${REPO_ROOT}`
- Use relative paths when possible
- Check path exists before use: `[[ -d "$PATH" ]]`

---

## Quick Reference

```bash
# Scan entire repo
./tools/scan_heredoc_issues.sh

# Scan specific directory
./tools/scan_heredoc_issues.sh .github/workflows

# Custom report location
REPORT_FILE=/tmp/my-scan.txt ./tools/scan_heredoc_issues.sh

# Fix issues interactively
./tools/fix_heredoc_issues.sh /tmp/heredoc-scan-report.txt

# Review report manually
cat /tmp/heredoc-scan-report.txt
less /tmp/heredoc-scan-report.txt
```

---

## See Also

- Bash Heredoc Documentation: `man bash` (search for "Here Documents")
- GitHub Actions Context: https://docs.github.com/en/actions/learn-github-actions/contexts
- Commits: `5d86bb3`, `2fcf0f3` (heredoc fix examples)
