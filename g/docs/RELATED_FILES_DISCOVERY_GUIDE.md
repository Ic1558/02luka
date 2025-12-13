# Related Files Discovery Guide
**Purpose:** Identify all related files before starting any task  
**When:** Phase 0 - BEFORE planning  
**Why:** Each task affects the big picture. Missing related files = breaking things.

---

## 🎯 Principle

> **"Each task or action always affects the big picture. You must ensure at the beginning what the related files are. This will alert you to be concerned about all related files."**

---

## 📋 Discovery Checklist

### Step 1: Direct Files
- [ ] Files I will directly modify
- [ ] Files that import/use what I'm changing
- [ ] Configuration files that reference the code
- [ ] Test files for the code

### Step 2: Dependencies
- [ ] Files that depend on what I'm changing
- [ ] Files that are imported by what I'm changing
- [ ] Shared utilities or helpers
- [ ] Common libraries or modules

### Step 3: Related Patterns
- [ ] Similar code patterns elsewhere
- [ ] Files with similar names/functions
- [ ] Documentation that references this
- [ ] Examples or templates

### Step 4: Configuration & Integration
- [ ] Config files (.yaml, .json, .env)
- [ ] Build/deploy scripts
- [ ] CI/CD workflows
- [ ] Integration points

### Step 5: Documentation
- [ ] README files
- [ ] API documentation
- [ ] Architecture docs
- [ ] User guides

---

## 🔍 Discovery Methods

### Method 1: Grep Search
```bash
# Search for function/class names
grep -r "function_name" . --include="*.zsh" --include="*.py" --include="*.js"

# Search for file references
grep -r "filename" . --include="*.md" --include="*.yaml"

# Search for patterns
grep -r "pattern" . --include="*.zsh"
```

### Method 2: Git Search
```bash
# Find files that reference a function
git grep "function_name"

# Find recent changes to related files
git log --oneline --all -- "path/to/related/*"
```

### Method 3: Find Similar Files
```bash
# Find files with similar names
find . -name "*similar*" -o -name "*related*"

# Find files in same directory
find . -path "*/same/dir/*" -type f
```

### Method 4: Dependency Analysis
```bash
# Check imports/dependencies
grep -r "import.*module" . --include="*.py"
grep -r "source.*file" . --include="*.zsh"
```

### Method 5: Documentation Search
```bash
# Find documentation references
grep -r "feature_name" g/docs/ g/reports/
find g/docs -name "*.md" -exec grep -l "pattern" {} \;
```

---

## 📝 Related Files List Template

**Task:** [Task Name]  
**Date:** [YYYY-MM-DD]

### Direct Files (Will Modify)
- `path/to/file1.zsh` - [Reason]
- `path/to/file2.md` - [Reason]

### Dependencies (Might Be Affected)
- `path/to/dependent.zsh` - [How it's affected]
- `path/to/config.yaml` - [Impact]

### Related Patterns (Similar Code)
- `path/to/similar.zsh` - [Similarity]
- `path/to/pattern.py` - [Pattern]

### Configuration Files
- `.cursorrules` - [Impact]
- `config/settings.yaml` - [Impact]

### Documentation
- `g/docs/feature.md` - [Needs update]
- `README.md` - [Needs update]

### Tests
- `tests/test_feature.zsh` - [Might need update]

---

## ⚠️ Common Mistakes

**❌ Don't:**
- Start coding without discovering related files
- Assume only one file is affected
- Ignore configuration files
- Forget about documentation
- Skip dependency analysis

**✅ Do:**
- Discover related files FIRST (Phase 0)
- Document all related files
- Check impact on each related file
- Update documentation if needed
- Test related files after changes

---

## 🎯 Example: Adding a New Function

**Task:** Add `validate_input()` function to `tools/script.zsh`

**Discovery:**
1. **Direct:** `tools/script.zsh` (will modify)
2. **Dependencies:** 
   - `tools/other_script.zsh` (imports script.zsh)
   - `config/validation.yaml` (might need config)
3. **Related Patterns:**
   - `tools/validate_*.zsh` (similar validation functions)
4. **Documentation:**
   - `g/docs/script_guide.md` (references script.zsh)
5. **Tests:**
   - `tests/test_script.zsh` (needs new test)

**Result:** 6 files identified, not just 1!

---

## ✅ Verification

**Before proceeding to planning:**
- [ ] All related files identified
- [ ] Impact on each file understood
- [ ] Related files list documented
- [ ] Big picture impact clear

**Only then proceed to Phase 1: Planning**

---

**Remember:** Discovery prevents breaking things. Always do Phase 0 first.
