## 🚨 GIT SAFETY - CRITICAL PROTOCOL

**NEVER use `git clean` directly in 02luka repo!**

### Why?
- Can permanently delete 300+ recovered files
- Can wipe workspace data
- Can destroy tools and scripts
- **NO UNDO** for deleted files

### ✅ SAFE Alternative (ALWAYS USE THIS)

**Step 1: Preview (REQUIRED FIRST STEP)**
```bash
zsh ~/02luka/tools/safe_git_clean.zsh -n   # Dry-run, shows what WOULD be deleted
```

**Step 2: Clean (after reviewing output)**
```bash
zsh ~/02luka/tools/safe_git_clean.zsh -f   # Actually deletes files (with confirmation)
```

### Setup (Add to ~/.zshrc)
```bash
# Git safety wrapper - prevents accidental git clean
source ~/02luka/.git_aliases.zsh
```

**What it does:**
- Intercepts `git clean` commands in 02luka repo
- Shows warning with safe alternative
- Requires confirmation for destructive operations

### Shell Aliases
```bash
git-safe-clean        # Dry-run (safe preview)
git-safe-clean-force  # Force clean (with confirmation)
```

---

- MLS Path Structure:

  MLS Capture Tool:
  ~/02luka/tools/mls_capture.zsh

  MLS Database:
  ~/02luka/g/knowledge/mls_lessons.jsonl

  MLS Index:
  ~/02luka/g/knowledge/mls_index.json

  MLS Reports:
  ~/02luka/g/reports/mls/
  ~/02luka/g/reports/mls/sessions/