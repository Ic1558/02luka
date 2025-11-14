# Feature PLAN: PR #279 Conflict Resolution

**Date:** 2025-11-15  
**Feature:** Resolve merge conflicts in PR #279  
**Branch:** `codex/fix-security-by-removing-auth-token-endpoint`

---

## Phase 1: Preparation & Analysis

### Tasks
1. ✅ Clean working directory (stash/commit local changes)
2. ✅ Fetch latest main branch
3. ✅ Identify all conflicting files
4. ✅ Analyze differences between branches
5. ✅ Document security fixes to preserve

### Commands
```bash
# Clean working directory
git stash push -m "temp work before conflict resolution"
git fetch origin main

# Identify conflicts
git merge origin/main --no-commit --no-ff
git status | grep "Unmerged"
```

### Output
- List of all conflicting files
- Diff analysis showing what to keep vs integrate

---

## Phase 2: Conflict Resolution Strategy

### Tasks
1. **For `g/apps/dashboard/wo_dashboard_server.js`:**
   - Keep: Security module imports (`./security/woId`)
   - Keep: `sanitizeWoId()`, `woStatePath()`, `assertValidWoId()` usage
   - Keep: `canonicalizeWoState()` function
   - Keep: Auth token endpoint removal
   - Keep: Security-focused comments
   - Integrate: Any Redis config improvements from main (if non-conflicting)
   - Integrate: Any bug fixes from main (if non-conflicting)

2. **Resolution approach:**
   - Use PR #279 version as base (has all security fixes)
   - Manually integrate any valid main branch changes
   - Verify all security functions are intact

### Key Preservation Points
```javascript
// MUST KEEP:
const { woStatePath, assertValidWoId, sanitizeWoId } = require('./security/woId');
// ... canonicalizeWoState() function
// ... auth token endpoint removal
// ... sanitizeWoId() calls in handlers
```

---

## Phase 3: Manual Conflict Resolution

### Tasks
1. Open conflicting file in editor
2. Identify conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
3. For each conflict:
   - Choose PR #279 version (security fixes)
   - Manually add any valid main branch changes
   - Remove conflict markers
4. Verify security functions are preserved

### Resolution Steps for `wo_dashboard_server.js`

**Step 1: Imports Section**
- Keep: `const { woStatePath, assertValidWoId, sanitizeWoId } = require('./security/woId');`
- This is from PR #279 and is required for security

**Step 2: Functions Section**
- Keep: `canonicalizeWoState()` function (PR #279)
- Keep: `readStateFile()` with security validation (PR #279)
- Keep: `writeStateFile()` with canonicalization (PR #279)

**Step 3: Route Handlers**
- Keep: Auth token endpoint removal (PR #279)
- Keep: `sanitizeWoId()` calls in all handlers (PR #279)
- Keep: Security validation before file operations (PR #279)

**Step 4: Comments**
- Keep: "SECURITY FIXED: Path traversal prevention + auth-token endpoint removed" (PR #279)

### Commands
```bash
# After manual resolution
git add g/apps/dashboard/wo_dashboard_server.js
git status  # Verify no more conflicts
```

---

## Phase 4: Verification & Testing

### Tasks
1. Syntax check resolved file
2. Verify all imports resolve
3. Check security functions are callable
4. Verify no broken references

### Commands
```bash
# Syntax check
node -c g/apps/dashboard/wo_dashboard_server.js

# Check imports
node -e "require('./g/apps/dashboard/wo_dashboard_server.js')" 2>&1 | head -10

# Verify security module exists
ls -la g/apps/dashboard/security/woId.js
```

### Validation Checklist
- [ ] No syntax errors
- [ ] All imports resolve
- [ ] Security module accessible
- [ ] No undefined functions
- [ ] Auth token endpoint removed
- [ ] Security functions present

---

## Phase 5: Commit & Push

### Tasks
1. Stage resolved files
2. Commit with descriptive message
3. Push to PR branch
4. Verify PR status updates

### Commit Message
```
fix(merge): resolve conflicts in wo_dashboard_server.js for PR #279

- Preserve all security fixes from PR #279:
  * Path traversal prevention (woStatePath, assertValidWoId, sanitizeWoId)
  * Auth token endpoint removal
  * State write canonicalization
- Integrate compatible changes from main branch
- Resolve merge conflicts while maintaining security improvements

Related: PR #279
```

### Commands
```bash
git add g/apps/dashboard/wo_dashboard_server.js
git commit -m "fix(merge): resolve conflicts in wo_dashboard_server.js for PR #279

- Preserve all security fixes from PR #279
- Integrate compatible changes from main
- Maintain security improvements"
git push origin codex/fix-security-by-removing-auth-token-endpoint
```

---

## Phase 6: PR Verification

### Tasks
1. Check PR #279 status on GitHub
2. Verify merge conflicts are resolved
3. Confirm PR is now mergeable
4. Review diff to ensure security fixes intact

### Commands
```bash
gh pr view 279 --json mergeable,mergeStateStatus
gh pr checks 279
```

---

## Test Strategy

### Manual Testing
1. ✅ Syntax validation (Node.js)
2. ✅ Import verification
3. ✅ Security module accessibility
4. ✅ No broken references

### Integration Testing (Optional)
- If server is running, verify endpoints work
- Test security functions with sample inputs
- Verify auth token endpoint is removed

### Validation
- [ ] Code compiles
- [ ] All imports work
- [ ] Security functions present
- [ ] PR is mergeable
- [ ] No regressions

---

## Rollback Plan

If conflict resolution breaks something:

1. **Revert commit:**
   ```bash
   git revert HEAD
   git push origin codex/fix-security-by-removing-auth-token-endpoint
   ```

2. **Alternative:** Reset to before merge attempt
   ```bash
   git reset --hard HEAD~1
   ```

3. **Restore stashed work:**
   ```bash
   git stash pop
   ```

---

## Timeline

- **Phase 1:** 5 min (preparation)
- **Phase 2:** 5 min (strategy)
- **Phase 3:** 15 min (manual resolution)
- **Phase 4:** 5 min (verification)
- **Phase 5:** 2 min (commit & push)
- **Phase 6:** 3 min (PR verification)

**Total:** ~35 minutes

---

## Risk Mitigation

### High Priority
- **Risk:** Accidentally removing security fixes
- **Mitigation:** Line-by-line review, keep all `./security/woId` imports and usage

### Medium Priority
- **Risk:** Breaking API compatibility
- **Mitigation:** Test syntax and imports, verify function signatures

### Low Priority
- **Risk:** Missing valid main branch improvements
- **Mitigation:** Review main branch changes, integrate non-conflicting ones

---

**Status:** ✅ PLAN Complete  
**Next:** Execute conflict resolution
