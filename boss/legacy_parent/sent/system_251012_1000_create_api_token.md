---
project: dashboard-deployment
tags: [cloudflare,api-token,instructions]
---

# Create Cloudflare API Token for Pages Management

**Date:** 2025-10-12 10:00
**Purpose:** Generate API token with permissions to complete dashboard deployment

## Current Situation

**Tunnel API Token Analysis:**
- Token ID: `fbde88c3db6945c938efce6268c2e566`
- Status: ✅ Valid and active
- Permissions:
  - ✅ Zone → DNS → Edit (working)
  - ❌ Account → Cloudflare Pages → Edit (missing)

**Result:** Can manage DNS records but cannot register Pages custom domains.

## Step-by-Step: Create New API Token

### 1. Navigate to API Tokens Page
Go to: https://dash.cloudflare.com/profile/api-tokens

### 2. Create Custom Token
Click: **"Create Token"** → **"Create Custom Token"**

### 3. Configure Token

**Token Name:**
```
Pages and DNS Management
```

**Permissions (Required):**
| Resource | Permission | Access |
|----------|-----------|--------|
| Account | Cloudflare Pages | Edit |
| Account | Account Settings | Read |
| Zone | DNS | Edit |

**Set Permissions:**
1. Click "+ Add more" under Permissions
2. Select: **Account** → **Cloudflare Pages** → **Edit**
3. Click "+ Add more" again
4. Select: **Account** → **Account Settings** → **Read**
5. Click "+ Add more" again
6. Select: **Zone** → **DNS** → **Edit**

**Account Resources:**
- Include → Specific account → **ittipong.c@gmail.com's Account** (`2cf1e9eb0dfd2477af7b0bea5bcc53d6`)

**Zone Resources:**
- Include → Specific zone → **theedges.work** (`035e56800598407a107b362d40ef5c04`)

**Client IP Address Filtering (Optional):**
- Leave blank for all IPs
- OR restrict to your IP for security

**TTL (Optional):**
- Leave blank for no expiration
- OR set expiration date

### 4. Review and Create
1. Click: **"Continue to summary"**
2. Verify permissions are correct
3. Click: **"Create Token"**

### 5. Copy Token
⚠️ **IMPORTANT:** Copy the token immediately - it will only be shown once!

```
Example token (yours will be different):
abc123XYZ789_COPY_THIS_ENTIRE_STRING_def456
```

## Apply the Token

### Method 1: Via GitHub Secrets (Automated)

```bash
# Update GitHub secret
echo "YOUR_NEW_TOKEN_HERE" | gh secret set CF_API_TOKEN

# Trigger workflow
gh workflow run "Add Pages Custom Domain" \
  -f domain=dashboard.theedges.work \
  -f project=theedges-dashboard

# Monitor execution
gh run watch
```

### Method 2: Test Locally First

```bash
# Test token permissions
curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_NEW_TOKEN_HERE" | jq .

# Test Pages API access
curl -s "https://api.cloudflare.com/client/v4/accounts/2cf1e9eb0dfd2477af7b0bea5bcc53d6/pages/projects/theedges-dashboard" \
  -H "Authorization: Bearer YOUR_NEW_TOKEN_HERE" | jq .success
# Should return: true

# Add custom domain
curl -X POST \
  "https://api.cloudflare.com/client/v4/accounts/2cf1e9eb0dfd2477af7b0bea5bcc53d6/pages/projects/theedges-dashboard/domains" \
  -H "Authorization: Bearer YOUR_NEW_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  --data '{"name": "dashboard.theedges.work"}' | jq .
```

## Verification

After adding the custom domain:

```bash
# Check domain status
curl -s "https://api.cloudflare.com/client/v4/accounts/2cf1e9eb0dfd2477af7b0bea5bcc53d6/pages/projects/theedges-dashboard/domains" \
  -H "Authorization: Bearer YOUR_NEW_TOKEN_HERE" | \
  jq -r '.result[] | "\(.name): \(.status)"'

# Expected output:
# dashboard.theedges.work: active

# Test dashboard access
curl -sL https://dashboard.theedges.work | grep "02LUKA UI"
# Should return: <title>02LUKA UI</title>
```

## Alternative: Manual via Dashboard (Fastest)

If you prefer not to create a new API token:

1. Go to: https://dash.cloudflare.com/2cf1e9eb0dfd2477af7b0bea5bcc53d6/pages
2. Select: **theedges-dashboard**
3. Click: **"Custom domains"** tab
4. Click: **"Set up a custom domain"**
5. Enter: `dashboard.theedges.work`
6. Click: **"Continue"**
7. Cloudflare will detect the existing CNAME
8. Click: **"Activate domain"**

Done! Dashboard will be live at https://dashboard.theedges.work within 30 seconds.

## Security Best Practices

**Token Storage:**
- ✅ GitHub Secrets (encrypted)
- ✅ Environment variables (local development)
- ❌ Never commit tokens to git
- ❌ Never share tokens publicly

**Token Rotation:**
- Rotate tokens every 90 days
- Delete unused tokens immediately
- Create separate tokens for different purposes

**Monitoring:**
- Check token usage in Cloudflare dashboard
- Review API logs regularly
- Revoke compromised tokens immediately

## Summary

**Current Token:** ✅ Valid but missing Pages permissions
**Required:** New token with Pages + DNS + Account Settings
**Time:** 3-5 minutes to create and apply
**Result:** 100% CLI-automated dashboard deployment

**Files:**
- Instructions: `g/reports/251012_1000_create_api_token.md`
- Workflow: `.github/workflows/add_pages_domain.yml`
- Test script: `/tmp/test_api_token_permissions.sh`
