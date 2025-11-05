# Repository Size Blocker – Git Push Limit Exceeded

**Date:** 2025-11-06
**Status:** 🔶 Open (Non-blocking)
**Impact:** Parent repo push blocked; g/ submodule pushes OK
**Severity:** Medium (does not affect system operation)

## Problem Statement

Git push to parent repository (`github.com:Ic1558/02luka.git`) fails with pack size exceeding GitHub's 2GB limit.

```
remote: fatal: pack exceeds maximum allowed size (2.00 GiB)
error: remote unpack failed: index-pack failed
To github.com:Ic1558/02luka.git
 ! [remote rejected] clc/cursor-cls-integration -> clc/cursor-cls-integration (failed)
error: failed to push some refs to 'github.com:Ic1558/02luka.git'
```

## Root Cause Analysis

### Current Repository State

```bash
$ git count-objects -vH
count: 58
size: 244.00 KiB
in-pack: 11096
packs: 1
size-pack: 6.47 GiB  ← EXCEEDS 2GB GitHub LIMIT
```

**Key Finding:** Repository pack is **6.47 GiB** (pre-existing condition, not caused by Phase 13 changes)

### Timeline

- **Pre-Phase 13:** Repository already at 6.47 GiB
- **Phase 13.1:** Added MCP servers (memory: 22MB, search: minimal)
- **Phase 13.2:** Added bridge script and config (<1MB)
- **Git Push Attempt:** Failed due to pre-existing size issue

### Scope

- ✅ **g/ submodule**: Pushes successfully to `main` branch
- ❌ **Parent repo**: Cannot push due to pack size
- ✅ **Local operation**: All systems fully functional

## Impact Assessment

### System Operation: ✅ ZERO IMPACT

- All Phase 13 deployments operational
- MCP ecosystem running (4 servers)
- Cross-agent binding active
- Documentation safely stored in g/ submodule (pushed to GitHub)

### Git Workflow: ⚠️ LIMITED IMPACT

**What Works:**
- Local commits
- g/ submodule pushes
- Local branch management
- Documentation via g/ submodule

**What Doesn't Work:**
- Pushing parent repo to remote
- Sharing MCP server code via GitHub parent repo
- Remote backup of parent repo changes

## Workarounds

### Current (Acceptable for Now)

1. **Continue development locally**
   - All deployments work
   - Phase 13.1 & 13.2 complete
   - System fully operational

2. **Document via g/ submodule**
   - Reports pushed successfully
   - Phase completion records on GitHub
   - SOT maintained

3. **Defer cleanup to maintenance window**
   - Not urgent (local operation unaffected)
   - Can be addressed in scheduled maintenance
   - Requires careful planning (irreversible)

## Proposed Solutions

### Option A: BFG Repo-Cleaner (Recommended)

**Removes large files from Git history**

```bash
# 1. Fresh clone for safety
git clone --mirror github.com:Ic1558/02luka.git repo.git
cd repo.git

# 2. Install BFG
brew install bfg

# 3. Analyze large objects
git verify-pack -v .git/objects/pack/pack-*.idx | sort -k3 -n | tail -20
git rev-list --objects --all | grep <SHA>

# 4. Remove large artifacts
java -jar /opt/homebrew/opt/bfg/libexec/bfg.jar \
  --delete-folders node_modules \
  --delete-files '*.{zip,tar.gz,dmg}' \
  --strip-blobs-bigger-than 10M \
  --no-blob-protection

# 5. Cleanup and repack
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 6. Force push (DESTRUCTIVE - coordinate with team)
git push --force
```

**Pros:**
- Permanently reduces repo size
- Proven solution for this issue
- Preserves Git history (minus removed files)

**Cons:**
- Irreversible (requires backup)
- Force push required (coordination needed)
- May break existing clones

### Option B: Git LFS for Future Large Files

**Use Git Large File Storage for binaries**

```bash
# 1. Install Git LFS
brew install git-lfs
git lfs install

# 2. Track large file patterns
git lfs track "*.dmg"
git lfs track "*.zip"
git lfs track "**/node_modules/**"
git add .gitattributes

# 3. Commit and push
git commit -m "feat: Enable Git LFS for large files"
git push
```

**Pros:**
- Prevents future size issues
- Transparent to users (after setup)
- Supported by GitHub

**Cons:**
- Doesn't fix existing history
- Requires LFS setup on all clones
- GitHub LFS has storage/bandwidth limits

### Option C: Split Repository

**Separate MCP servers into dedicated repo**

```bash
# 1. Extract mcp/ directory to new repo
git subtree split -P mcp -b mcp-servers
git push <new-repo-url> mcp-servers:main

# 2. Add as submodule or subtree
git submodule add <new-repo-url> mcp

# 3. Remove from parent history (BFG)
java -jar bfg.jar --delete-folders mcp
```

**Pros:**
- Clean separation of concerns
- Smaller parent repo
- MCP servers independently versioned

**Cons:**
- Architectural change
- More complex workflow
- Requires submodule management

### Option D: .gitignore Improvements (Prevention Only)

**Prevent future accidental adds**

```gitignore
# Add to .gitignore
**/node_modules/
**/.npm/
**/.cache/
*.dmg
*.zip
*.tar.gz
**/*.log
**/build/
**/dist/
```

**Pros:**
- Easy to implement
- Prevents future issues
- Best practice

**Cons:**
- Doesn't fix existing problem
- Only prevents new additions

## Recommended Approach

### Phase 1: Immediate (Completed ✅)

- [x] Continue local development (Phase 13)
- [x] Document issue in SOT (this file)
- [x] Push documentation via g/ submodule
- [x] No system downtime

### Phase 2: Analysis (Before Cleanup)

```bash
# 1. Identify largest objects
git verify-pack -v .git/objects/pack/pack-*.idx | \
  sort -k3 -n | tail -50 > large_objects.txt

# 2. Map SHAs to file paths
while read sha size; do
  git rev-list --objects --all | grep $sha
done < <(awk '{print $1,$3}' large_objects.txt)

# 3. Use git-sizer for comprehensive analysis
brew install git-sizer
git-sizer --verbose > repo_analysis.txt
```

### Phase 3: Cleanup (Maintenance Window)

**Prerequisites:**
- [ ] Coordinate with team (if any)
- [ ] Create full backup
- [ ] Test on mirror clone first
- [ ] Schedule downtime window
- [ ] Document rollback procedure

**Execution:**
1. Run BFG Repo-Cleaner on mirror
2. Verify size reduction
3. Test clone and operations
4. Force push with notification
5. Update all local clones

### Phase 4: Prevention (After Cleanup)

- [ ] Add comprehensive .gitignore
- [ ] Enable Git LFS for large files
- [ ] Document "never commit" patterns
- [ ] Add pre-commit hooks (size checks)
- [ ] Monitor repo size regularly

## Files Likely Contributing to Size

### Common Culprits (Hypothesis)

1. **node_modules/** - Multiple MCP server installations
   - mcp-memory: 22MB
   - Other historical npm installs

2. **Build artifacts** - Compiled binaries, bundles
   - Docker images (if committed)
   - Build outputs

3. **Large reports/logs** - Accidentally committed
   - Historical log files
   - Large data dumps

4. **Binary files** - Images, archives
   - `.dmg`, `.zip`, `.tar.gz` files
   - Screenshots, videos

### Verification Commands

```bash
# Top 20 largest files in history
git rev-list --objects --all | \
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
  sed -n 's/^blob //p' | sort -k2 -n | tail -20

# Files by extension
git ls-tree -r HEAD --name-only | rev | cut -d. -f1 | rev | sort | uniq -c | sort -rn | head -20
```

## Decision Matrix

| Solution | Effort | Risk | Impact | Timeline |
|----------|--------|------|--------|----------|
| **Continue Local** | ✅ None | ✅ None | 🔶 Limited Git remote sync | Ongoing |
| **BFG Cleanup** | 🔶 Medium | ⚠️ High | ✅ Fixes problem | 2-4 hours |
| **Git LFS** | ✅ Low | ✅ Low | 🔶 Prevention only | 30 min |
| **Split Repo** | ⚠️ High | 🔶 Medium | ✅ Long-term solution | 4-8 hours |
| **.gitignore** | ✅ Low | ✅ None | 🔶 Prevention only | 10 min |

## Recommendation

**Short-term (Now):** ✅ IMPLEMENTED
- Continue Phase 13 development locally
- Document via g/ submodule
- No operational impact

**Medium-term (Next maintenance window):**
1. Run analysis (git-sizer, verify-pack)
2. Create backup
3. Execute BFG Repo-Cleaner on mirror
4. Test thoroughly
5. Force push with coordination

**Long-term (Ongoing):**
- Improve .gitignore
- Consider Git LFS for future binaries
- Monitor repo size monthly
- Document commit guidelines

## Quick Reference

### Check Current Size
```bash
git count-objects -vH
```

### Analyze Large Objects
```bash
git verify-pack -v .git/objects/pack/pack-*.idx | sort -k3 -n | tail -20
```

### Safe Testing
```bash
# Always test on mirror first
git clone --mirror <repo-url> test.git
cd test.git
# Run BFG or other cleanup
# Verify size reduction
# Test clone and operations
```

---

**Status:** 🔶 Open (Non-blocking)
**Priority:** Medium (cleanup when convenient)
**Risk:** Low (system operates normally)
**Next Action:** Schedule maintenance window for BFG cleanup

**Key Point:** This is a Git history issue, not a system issue. All Phase 13 deployments are operational and documented.

---

**Maintainer:** GG Core (02LUKA Automation)
**Opened:** 2025-11-06
**Category:** Git Repository Maintenance
**Verified by:** CDC / CLC / GG SOT Audit Layer
