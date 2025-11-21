#!/bin/zsh
# Gemini API Key Leak Scanner
# Created: 2025-11-21
# Agent: Liam (Antigravity)
# Purpose: Forensic scan for leaked Gemini API keys across both repos

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Repos to scan
REPO_1="/Users/icmini/02luka"
REPO_2="/Users/icmini/LocalProjects/02luka_local_g"

# Default .env.local location
ENV_FILE="${REPO_2}/.env.local"

echo "=== Gemini API Key Leak Scanner ==="
echo ""

# Check if .env.local exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "${RED}❌ .env.local not found at: $ENV_FILE${NC}"
    exit 1
fi

# Read the current Gemini API key
GEMINI_KEY=$(grep "^GEMINI_API_KEY=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")

if [[ -z "$GEMINI_KEY" ]]; then
    echo "${RED}❌ GEMINI_API_KEY not found in .env.local${NC}"
    exit 1
fi

# Compute safe fingerprint
KEY_LEN=${#GEMINI_KEY}
KEY_PREFIX="${GEMINI_KEY:0:6}"
KEY_SUFFIX="${GEMINI_KEY: -4}"
FINGERPRINT="${KEY_PREFIX}...${KEY_SUFFIX} (len=${KEY_LEN})"

echo "${YELLOW}🔍 Scanning for key fingerprint: ${FINGERPRINT}${NC}"
echo ""

# Directories to exclude
EXCLUDE_DIRS=(
    ".git"
    "venv"
    ".venv"
    "node_modules"
    "__pycache__"
    ".n8n"
    "_archive"
    ".pytest_cache"
    ".backup"
    "dist"
    "build"
    ".tmp"
    "tmp"
    "logs"
)

# File patterns to exclude
EXCLUDE_FILES=(
    "*.log"
    "*.sqlite"
    "*.db"
    "*.pyc"
    "*.pyo"
    "*.swp"
    "*.bak"
)

# Build rg exclude arguments
RG_EXCLUDES=()
for dir in "${EXCLUDE_DIRS[@]}"; do
    RG_EXCLUDES+=(--glob "!${dir}/**")
done
for pattern in "${EXCLUDE_FILES[@]}"; do
    RG_EXCLUDES+=(--glob "!${pattern}")
done

# Function to scan a repo
scan_repo() {
    local repo_path="$1"
    local repo_name="$2"
    
    echo "${YELLOW}📂 Scanning: ${repo_name}${NC}"
    echo "   Path: ${repo_path}"
    echo ""
    
    if [[ ! -d "$repo_path" ]]; then
        echo "${RED}   ⚠️  Directory not found, skipping${NC}"
        echo ""
        return 0
    fi
    
    # Use ripgrep to search for the exact key
    local matches=0
    
    if command -v rg &> /dev/null; then
        # Using ripgrep
        while IFS= read -r line; do
            echo "${RED}   🚨 FOUND: ${line}${NC}"
            ((matches++))
        done < <(rg --fixed-strings --line-number --no-heading \
            "${RG_EXCLUDES[@]}" \
            "$GEMINI_KEY" "$repo_path" 2>/dev/null || true)
    else
        # Fallback to grep
        while IFS= read -r line; do
            echo "${RED}   🚨 FOUND: ${line}${NC}"
            ((matches++))
        done < <(grep -r -n -F "$GEMINI_KEY" "$repo_path" \
            --exclude-dir="{${(j:,:)EXCLUDE_DIRS}}" \
            2>/dev/null || true)
    fi
    
    if [[ $matches -eq 0 ]]; then
        echo "${GREEN}   ✅ No matches found${NC}"
    else
        echo ""
        echo "${RED}   ❌ Found ${matches} occurrence(s)${NC}"
    fi
    
    echo ""
    return $matches
}

# Scan both repos
total_matches=0

scan_repo "$REPO_1" "02luka"
repo1_matches=$?
((total_matches += repo1_matches))

scan_repo "$REPO_2" "02luka_local_g"
repo2_matches=$?
((total_matches += repo2_matches))

# Summary
echo "=== Scan Complete ==="
echo ""
if [[ $total_matches -eq 0 ]]; then
    echo "${GREEN}✅ No leaked keys found in tracked files${NC}"
    echo ""
    echo "Key fingerprint: ${FINGERPRINT}"
    echo "Status: SAFE (key only in .env.local)"
    exit 0
else
    echo "${RED}❌ SECURITY ALERT: Found ${total_matches} occurrence(s) of the leaked key${NC}"
    echo ""
    echo "Key fingerprint: ${FINGERPRINT}"
    echo "Action required: Clean up the files listed above"
    echo ""
    echo "Next steps:"
    echo "  1. Review each file and replace key with \${GEMINI_API_KEY} placeholder"
    echo "  2. Commit the cleanup"
    echo "  3. Rotate the API key at Google Cloud Console"
    echo "  4. Update .env.local with new key"
    exit 1
fi
