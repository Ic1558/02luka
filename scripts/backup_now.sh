#!/usr/bin/env bash
set -euo pipefail

# Atomic Backup Script for CLS Migration
# Creates tarball snapshot of critical system components

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="/Volumes/lukadata/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

echo "🗄️  02luka Atomic Backup"
echo "======================="
echo ""

# Check external volume
if [[ ! -d "/Volumes/lukadata" ]]; then
    echo "❌ External volume /Volumes/lukadata not mounted"
    echo "   Please mount the volume and try again"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "📁 Backup location: $BACKUP_DIR"
echo ""

# Directories to backup
BACKUP_TARGETS=(
    "g"
    "knowledge"
    "api"
    "agents"
    "packages"
    "scripts"
    "config"
    ".github/workflows"
)

echo "📦 Creating backup tarball..."
cd "$REPO_ROOT"

# Create tarball with progress
tar -czf "$BACKUP_DIR/02luka_backup.tar.gz" \
    --exclude="node_modules" \
    --exclude=".git" \
    --exclude="dist" \
    --exclude="*.log" \
    --exclude="tmp" \
    "${BACKUP_TARGETS[@]}" 2>&1 | grep -v "Removing leading" || true

# Verify tarball
if [[ -f "$BACKUP_DIR/02luka_backup.tar.gz" ]]; then
    SIZE=$(du -h "$BACKUP_DIR/02luka_backup.tar.gz" | awk '{print $1}')
    echo "✅ Backup created: $SIZE"

    # Test extraction (verify integrity)
    echo ""
    echo "🔍 Verifying backup integrity..."
    if tar -tzf "$BACKUP_DIR/02luka_backup.tar.gz" >/dev/null 2>&1; then
        echo "✅ Backup integrity verified"
    else
        echo "❌ Backup verification failed"
        exit 1
    fi
else
    echo "❌ Backup creation failed"
    exit 1
fi

# Create manifest
echo ""
echo "📋 Creating backup manifest..."
cat > "$BACKUP_DIR/manifest.txt" <<EOF
Backup Timestamp: $TIMESTAMP
Backup Date: $(date -Iseconds)
Repository: 02luka
Hostname: $(hostname)
User: $(whoami)
Backup Size: $SIZE

Backed up directories:
$(printf '  - %s\n' "${BACKUP_TARGETS[@]}")

Verification: PASSED
EOF

echo "✅ Manifest created"

# Clean old backups (keep last 10)
echo ""
echo "🧹 Cleaning old backups..."
cd "$BACKUP_ROOT"
ls -t | tail -n +11 | xargs -I {} rm -rf "{}" 2>/dev/null || true
BACKUP_COUNT=$(ls -1 | wc -l | tr -d ' ')
echo "✅ Keeping last $BACKUP_COUNT backups"

# Summary
echo ""
echo "=============================="
echo "✅ Backup Complete"
echo ""
echo "Location: $BACKUP_DIR"
echo "Size: $SIZE"
echo "Manifest: $BACKUP_DIR/manifest.txt"
echo ""
echo "To restore:"
echo "  cd $REPO_ROOT"
echo "  tar -xzf $BACKUP_DIR/02luka_backup.tar.gz"
echo "=============================="
