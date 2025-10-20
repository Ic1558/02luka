# 🚀 GitHub Secrets Setup - Web UI Method (Fastest)

## ❌ Issue Identified: Token Permissions

**Problem:** Your current GitHub PAT has insufficient permissions for Actions/Secrets/Variables APIs.

**Error:** `HTTP 403` on `actions/secrets/public-key` endpoint

**Root Cause:** Classic tokens often lack fine-grained permissions for Actions APIs.

## ✅ Solution: Web UI Setup (Fastest Path)

### **Step 1: Configure Repository Secrets**

**Go to:** https://github.com/Ic1558/02luka/settings/secrets/actions

**Click "New repository secret" and add:**

| Name | Value |
|------|-------|
| `OPS_ATOMIC_URL` | `https://boss-api.ittipong-c.workers.dev` |
| `OPS_ATOMIC_TOKEN` | `NA` (placeholder) |

### **Step 2: Configure Repository Variables**

**Go to:** https://github.com/Ic1558/02luka/settings/variables/actions

**Click "New repository variable" and add:**

| Name | Value |
|------|-------|
| `OPS_GATE_OVERRIDE` | `0` |

### **Step 3: Test CI**

```bash
# Trigger CI workflow
gh workflow run ci.yml --repo Ic1558/02luka

# Watch the run
gh run watch --repo Ic1558/02luka
```

## 🔧 Alternative: Fine-Grained PAT (For Future CLI Use)

### **Step 1: Generate Fine-Grained PAT**

**Go to:** https://github.com/settings/personal-access-tokens

**Configure:**
- **Type:** Fine-grained personal access token
- **Repository access:** Only selected → select `Ic1558/02luka`
- **Permissions (Repository):**
  - ✅ **Actions:** Read and write
  - ✅ **Secrets:** Read and write  
  - ✅ **Variables:** Read and write
  - ✅ **Contents:** Read and write
  - ✅ **Metadata:** Read-only (required)

### **Step 2: Authenticate with New Token**

```bash
# Login with new fine-grained token
gh auth login --hostname github.com --with-token
# Paste your new fine-grained token when prompted
```

### **Step 3: Configure via CLI**

```bash
# Set secrets
echo "https://boss-api.ittipong-c.workers.dev" | gh secret set OPS_ATOMIC_URL --repo Ic1558/02luka
echo "NA" | gh secret set OPS_ATOMIC_TOKEN --repo Ic1558/02luka

# Set variable
gh variable set OPS_GATE_OVERRIDE --repo Ic1558/02luka --body "0"
```

### **Step 4: Verify Configuration**

```bash
# List secrets and variables
gh secret list --repo Ic1558/02luka
gh variable list --repo Ic1558/02luka

# Trigger and watch CI
gh workflow run ci.yml --repo Ic1558/02luka
gh run watch --repo Ic1558/02luka
```

## 📋 Expected Results

After configuration:
- ✅ **ops-gate job:** Will pass with proper secrets
- ✅ **auto-update-branch:** Will run without exit code 128
- ✅ **All CI workflows:** Will run successfully
- ✅ **No more 403 errors:** Proper permissions configured

## 🚨 Important Notes

### **SSO Authorization (If Applicable)**
If the repository is under an organization with SSO:
- Make sure the token is SSO-authorized for that org
- GitHub will show an "Authorize" banner on the token page

### **Token Scope Requirements**
The 403 error occurs because classic tokens often lack:
- `actions:write` - Required for secrets/variables
- `secrets:write` - Required for secret management
- `variables:write` - Required for variable management

## 🎯 Recommended Approach

**For immediate fix:** Use Web UI (5 minutes)
**For future automation:** Set up Fine-Grained PAT with proper permissions

---

**Status:** Ready for Web UI configuration
**ETA:** 5 minutes (Web UI method)
**Impact:** All CI failures will be resolved
