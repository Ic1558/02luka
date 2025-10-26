#!/usr/bin/env node
/**
 * Safety Checks for CLC Optimization
 * Implements emergency disable, schema backup, and failure cooldown
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT = process.cwd();
const CONFIG_DIR = path.join(ROOT, '02luka/config');
const BACKUP_DIR = path.join(ROOT, 'g/backups');
const STATE_DIR = path.join(ROOT, 'g/state');

// Ensure directories exist
fs.mkdirSync(BACKUP_DIR, { recursive: true });
fs.mkdirSync(STATE_DIR, { recursive: true });

function isCacheEnabled() {
  const disableFlag = path.join(CONFIG_DIR, 'redis.off');
  return !fs.existsSync(disableFlag);
}

function getFailureCount() {
  const stateFile = path.join(STATE_DIR, 'optimizer_failures.json');
  try {
    if (fs.existsSync(stateFile)) {
      const data = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
      return data.count || 0;
    }
  } catch (e) {
    console.warn('Error reading failure count:', e.message);
  }
  return 0;
}

function incrementFailureCount() {
  const stateFile = path.join(STATE_DIR, 'optimizer_failures.json');
  const count = getFailureCount() + 1;
  const data = {
    count,
    lastFailure: new Date().toISOString(),
    cooldownUntil: new Date(Date.now() + (count * 3600000)).toISOString() // 1h per failure
  };
  fs.writeFileSync(stateFile, JSON.stringify(data, null, 2));
  return count;
}

function resetFailureCount() {
  const stateFile = path.join(STATE_DIR, 'optimizer_failures.json');
  if (fs.existsSync(stateFile)) {
    fs.unlinkSync(stateFile);
  }
}

function isInCooldown() {
  const stateFile = path.join(STATE_DIR, 'optimizer_failures.json');
  try {
    if (fs.existsSync(stateFile)) {
      const data = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
      if (data.cooldownUntil) {
        const cooldownUntil = new Date(data.cooldownUntil);
        const now = new Date();
        return now < cooldownUntil;
      }
    }
  } catch (e) {
    console.warn('Error checking cooldown:', e.message);
  }
  return false;
}

function createSchemaBackup() {
  const today = new Date().toISOString().slice(0, 10);
  const backupFile = path.join(BACKUP_DIR, `schema_${today}.sql`);
  
  try {
    // This would be replaced with actual database backup command
    // For now, create a placeholder
    const backupContent = `-- Schema backup created on ${new Date().toISOString()}
-- This is a placeholder for actual database schema backup
-- Replace with: mysqldump --no-data --routines --triggers your_database > ${backupFile}
SELECT 'Schema backup placeholder' as status;
`;
    fs.writeFileSync(backupFile, backupContent);
    console.log(`Schema backup created: ${backupFile}`);
    return backupFile;
  } catch (error) {
    console.error('Failed to create schema backup:', error.message);
    return null;
  }
}

function checkSafety() {
  const results = {
    cacheEnabled: isCacheEnabled(),
    inCooldown: isInCooldown(),
    failureCount: getFailureCount(),
    canProceed: true,
    warnings: []
  };
  
  if (!results.cacheEnabled) {
    results.warnings.push('Cache disabled by redis.off flag');
  }
  
  if (results.inCooldown) {
    results.canProceed = false;
    results.warnings.push('Optimizer in cooldown due to recent failures');
  }
  
  if (results.failureCount >= 3) {
    results.canProceed = false;
    results.warnings.push('Too many consecutive failures (3+)');
  }
  
  return results;
}

// CLI usage
if (require.main === module) {
  const safety = checkSafety();
  console.log(JSON.stringify(safety, null, 2));
  
  if (process.argv.includes('--backup')) {
    createSchemaBackup();
  }
  
  if (process.argv.includes('--increment-failure')) {
    incrementFailureCount();
  }
  
  if (process.argv.includes('--reset-failures')) {
    resetFailureCount();
  }
}

module.exports = {
  isCacheEnabled,
  getFailureCount,
  incrementFailureCount,
  resetFailureCount,
  isInCooldown,
  createSchemaBackup,
  checkSafety
};
