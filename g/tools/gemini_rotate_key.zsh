#!/usr/bin/env zsh
# Gemini API Key Rotation Executor
# Created: 2025-11-21
# Agent: Liam (Antigravity)
# Purpose: Safely rotate Gemini API key with rollback capability

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths
ENV_FILE="/Users/icmini/LocalProjects/02luka_local_g/.env.local"
ROTATION_LOG="/Users/icmini/02luka/g/ledger/gemini_rotation_log.jsonl"
REPO_ROOT="/Users/icmini/02luka"

echo "=== Gemini API Key Rotation Executor ==="
echo ""

# Validate GEMINI_API_KEY_NEW
if [[ -z "$GEMINI_API_KEY_NEW" ]]; then
    echo "${RED}❌ ERROR: GEMINI_API_KEY_NEW environment variable not set${NC}"
    echo ""
    echo "Usage:"
    echo "  GEMINI_API_KEY_NEW=\"AIzaSy...\" $0"
    exit 1
fi

# Validate key format
if [[ ! "$GEMINI_API_KEY_NEW" =~ ^AIza ]]; then
    echo "${RED}❌ ERROR: Invalid API key format (must start with 'AIza')${NC}"
    exit 1
fi

echo "${GREEN}✅ New API key validated${NC}"
echo ""

# Step 1: Backup current .env.local
BACKUP_FILE="${ENV_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
echo "${YELLOW}📦 Backing up current .env.local...${NC}"
cp "$ENV_FILE" "$BACKUP_FILE"
echo "${GREEN}✅ Backup created: $BACKUP_FILE${NC}"
echo ""

# Get old key fingerprint
OLD_KEY=$(grep "^GEMINI_API_KEY=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
OLD_KEY_LEN=${#OLD_KEY}
OLD_KEY_PREFIX="${OLD_KEY:0:6}"
OLD_KEY_SUFFIX="${OLD_KEY: -4}"
OLD_FINGERPRINT="${OLD_KEY_PREFIX}...${OLD_KEY_SUFFIX}"

# Get new key fingerprint
NEW_KEY_LEN=${#GEMINI_API_KEY_NEW}
NEW_KEY_PREFIX="${GEMINI_API_KEY_NEW:0:6}"
NEW_KEY_SUFFIX="${GEMINI_API_KEY_NEW: -4}"
NEW_FINGERPRINT="${NEW_KEY_PREFIX}...${NEW_KEY_SUFFIX}"

echo "${YELLOW}🔄 Rotating key...${NC}"
echo "  Old: $OLD_FINGERPRINT (len=$OLD_KEY_LEN)"
echo "  New: $NEW_FINGERPRINT (len=$NEW_KEY_LEN)"
echo ""

# Step 2: Replace key in .env.local
echo "GEMINI_API_KEY=\"$GEMINI_API_KEY_NEW\"" > "$ENV_FILE"
echo "${GREEN}✅ Key updated in .env.local${NC}"
echo ""

# Step 3: Test connector
echo "${YELLOW}🧪 Testing connector...${NC}"
cd "$REPO_ROOT"
source venv/bin/activate

if ! ./g/tools/test_gemini_connector.sh > /tmp/gemini_test.log 2>&1; then
    echo "${RED}❌ Connector test FAILED${NC}"
    echo "${YELLOW}📋 Rolling back...${NC}"
    cp "$BACKUP_FILE" "$ENV_FILE"
    echo "${GREEN}✅ Rolled back to previous key${NC}"
    echo ""
    echo "Test log:"
    cat /tmp/gemini_test.log
    exit 1
fi

echo "${GREEN}✅ Connector test passed${NC}"
echo ""

# Step 4: Test quota (optional, may fail due to model mismatch)
echo "${YELLOW}🧪 Testing quota (optional)...${NC}"
if python g/tools/check_quota.py > /tmp/gemini_quota.log 2>&1; then
    echo "${GREEN}✅ Quota check passed${NC}"
else
    echo "${YELLOW}⚠️  Quota check failed (may be model mismatch, not critical)${NC}"
fi
echo ""

# Step 5: Log rotation
echo "${YELLOW}📝 Logging rotation...${NC}"

# Determine rotation reason
ROTATION_REASON="${ROTATION_REASON:-manual_rotation}"

# Create log entry
LOG_ENTRY=$(cat <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","old_key_fingerprint":"$OLD_FINGERPRINT","new_key_fingerprint":"$NEW_FINGERPRINT","reason":"$ROTATION_REASON","status":"success","validator":"Liam-ATG"}
EOF
)

# Ensure ledger directory exists
mkdir -p "$(dirname "$ROTATION_LOG")"

# Append to rotation log
echo "$LOG_ENTRY" >> "$ROTATION_LOG"
echo "${GREEN}✅ Rotation logged to: $ROTATION_LOG${NC}"
echo ""

# Step 6: Cleanup (optional)
if [[ "${KEEP_BACKUP}" != "true" ]]; then
    echo "${YELLOW}🧹 Cleaning up backup...${NC}"
    rm -f "$BACKUP_FILE"
    echo "${GREEN}✅ Backup removed${NC}"
else
    echo "${YELLOW}📦 Backup kept: $BACKUP_FILE${NC}"
fi
echo ""

# Success summary
echo "=== Rotation Complete ==="
echo ""
echo "${GREEN}✅ SUCCESS${NC}"
echo ""
echo "Summary:"
echo "  Old key: $OLD_FINGERPRINT"
echo "  New key: $NEW_FINGERPRINT"
echo "  Reason: $ROTATION_REASON"
echo "  Log: $ROTATION_LOG"
echo ""
echo "Next steps:"
echo "  1. Test your applications with the new key"
echo "  2. Monitor API usage in Google Cloud Console"
echo "  3. Delete old key from Google Cloud Console"
echo ""
