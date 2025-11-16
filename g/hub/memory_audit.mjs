#!/usr/bin/env node

/**
 * Memory Consistency & Checksum Auditor
 * Phase 21.2 - Verifies SOT memory against index with SHA-256 checksums
 */

import { readFileSync, writeFileSync, readdirSync, statSync, existsSync, mkdirSync, appendFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve, join, dirname } from 'node:path';
import { parse as yamlParse } from 'yaml';

// Constants
const ROOT = process.env.LUKA_ROOT || process.cwd();
const CONFIG_PATH = join(ROOT, 'config/memory_audit.yaml');
const TIMESTAMP = new Date().toISOString();

// Utilities
function log(level, msg, meta = {}) {
  const entry = {
    timestamp: TIMESTAMP,
    level,
    message: msg,
    ...meta
  };
  console.log(`[${level.toUpperCase()}] ${msg}`, meta);
  return entry;
}

function ensureDir(path) {
  const dir = dirname(path);
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
}

function sha256(filePath) {
  try {
    const content = readFileSync(filePath);
    return createHash('sha256').update(content).digest('hex');
  } catch (err) {
    return null;
  }
}

function readJSON(filePath) {
  try {
    return JSON.parse(readFileSync(filePath, 'utf-8'));
  } catch {
    return null;
  }
}

function readJSONL(filePath) {
  try {
    const lines = readFileSync(filePath, 'utf-8').split('\n').filter(l => l.trim());
    return lines.map(line => {
      try {
        return JSON.parse(line);
      } catch {
        return null;
      }
    }).filter(Boolean);
  } catch {
    return [];
  }
}

function walkDir(dir, pattern = null) {
  const files = [];

  function walk(currentDir) {
    try {
      const entries = readdirSync(currentDir);
      for (const entry of entries) {
        const fullPath = join(currentDir, entry);
        try {
          const stat = statSync(fullPath);
          if (stat.isDirectory()) {
            walk(fullPath);
          } else if (stat.isFile()) {
            if (!pattern || fullPath.match(pattern)) {
              files.push(fullPath);
            }
          }
        } catch {
          // Skip inaccessible files
        }
      }
    } catch {
      // Skip inaccessible directories
    }
  }

  walk(dir);
  return files;
}

// Load configuration
function loadConfig() {
  try {
    const configContent = readFileSync(CONFIG_PATH, 'utf-8');
    const config = yamlParse(configContent);
    return config.audit;
  } catch (err) {
    console.error(`Failed to load config from ${CONFIG_PATH}:`, err.message);
    process.exit(1);
  }
}

// Scan memory files and calculate checksums
function scanMemoryFiles(config) {
  const memoryRoot = join(ROOT, config.sot.memory_root);
  const results = {
    index_files: [],
    snapshot_files: [],
    attestation_files: [],
    all_files: []
  };

  // Scan index files
  for (const indexFile of config.sot.index_files) {
    const fullPath = join(ROOT, indexFile);
    if (existsSync(fullPath)) {
      const checksum = sha256(fullPath);
      const stat = statSync(fullPath);
      results.index_files.push({
        path: indexFile,
        full_path: fullPath,
        checksum,
        size: stat.size,
        modified: stat.mtime.toISOString(),
        exists: true
      });
    } else {
      results.index_files.push({
        path: indexFile,
        full_path: fullPath,
        checksum: null,
        size: 0,
        modified: null,
        exists: false
      });
    }
  }

  // Scan snapshot directories
  for (const snapshotDir of config.sot.snapshot_dirs) {
    const fullPath = join(ROOT, snapshotDir);
    if (existsSync(fullPath)) {
      const files = walkDir(fullPath);
      for (const file of files) {
        const relativePath = file.replace(ROOT + '/', '');
        const checksum = sha256(file);
        const stat = statSync(file);

        const entry = {
          path: relativePath,
          full_path: file,
          checksum,
          size: stat.size,
          modified: stat.mtime.toISOString(),
          exists: true
        };

        if (file.includes('snapshots/snap_')) {
          results.snapshot_files.push(entry);
        } else if (file.includes('attestations/attest_')) {
          results.attestation_files.push(entry);
        }

        results.all_files.push(entry);
      }
    }
  }

  return results;
}

// Verify index integrity
function verifyIndexIntegrity(scannedFiles, config) {
  const issues = {
    missing_required: [],
    checksum_mismatches: [],
    orphaned_files: [],
    broken_references: []
  };

  // Check required files
  for (const requiredFile of config.validation.required_files) {
    const found = scannedFiles.index_files.find(f => f.path === requiredFile);
    if (!found || !found.exists) {
      issues.missing_required.push(requiredFile);
    }
  }

  // Check for snapshot integrity
  const snapshots = scannedFiles.snapshot_files.filter(f => f.path.endsWith('metadata.json'));
  for (const snapshot of snapshots) {
    const metadata = readJSON(snapshot.full_path);
    if (metadata) {
      // Check if state.hash exists for this snapshot
      const snapshotDir = dirname(snapshot.full_path);
      const hashFile = join(snapshotDir, 'state.hash');

      if (!existsSync(hashFile)) {
        issues.broken_references.push({
          snapshot: snapshot.path,
          missing: 'state.hash',
          reason: 'Hash file missing for snapshot'
        });
      } else {
        // Verify hash file content
        const storedHash = readFileSync(hashFile, 'utf-8').trim();
        const stateFile = join(snapshotDir, 'state.txt');

        if (existsSync(stateFile)) {
          const calculatedHash = sha256(stateFile);
          if (storedHash !== calculatedHash) {
            issues.checksum_mismatches.push({
              file: snapshot.path.replace('metadata.json', 'state.txt'),
              stored_hash: storedHash,
              calculated_hash: calculatedHash,
              reason: 'Checksum mismatch'
            });
          }
        }
      }
    }
  }

  return issues;
}

// Generate audit report
function generateReport(scannedFiles, issues, config) {
  const report = {
    audit_id: `audit_${Date.now()}`,
    timestamp: TIMESTAMP,
    version: config.version,
    summary: {
      total_files: scannedFiles.all_files.length,
      index_files: scannedFiles.index_files.length,
      snapshot_files: scannedFiles.snapshot_files.length,
      attestation_files: scannedFiles.attestation_files.length,
      missing_required: issues.missing_required.length,
      checksum_mismatches: issues.checksum_mismatches.length,
      broken_references: issues.broken_references.length,
      orphaned_files: issues.orphaned_files.length
    },
    files: {
      index_files: scannedFiles.index_files,
      snapshot_files: scannedFiles.snapshot_files,
      attestation_files: scannedFiles.attestation_files
    },
    issues,
    status: 'pass',
    alerts: []
  };

  // Determine status and alerts
  const totalIssues =
    issues.missing_required.length +
    issues.checksum_mismatches.length +
    issues.broken_references.length +
    issues.orphaned_files.length;

  if (totalIssues > config.alerts.mismatch_threshold) {
    report.status = 'fail';
    report.alerts.push({
      level: 'error',
      message: `Memory consistency check failed: ${totalIssues} issues found`,
      threshold: config.alerts.mismatch_threshold,
      actual: totalIssues
    });
  }

  if (issues.missing_required.length > config.alerts.missing_file_threshold) {
    report.alerts.push({
      level: 'error',
      message: `Missing required files: ${issues.missing_required.length}`,
      files: issues.missing_required
    });
  }

  if (issues.checksum_mismatches.length > config.alerts.checksum_change_threshold) {
    report.alerts.push({
      level: 'warning',
      message: `Checksum mismatches detected: ${issues.checksum_mismatches.length}`,
      details: issues.checksum_mismatches
    });
  }

  return report;
}

// Write output files
function writeOutput(report, config) {
  const reportFile = join(ROOT, config.output.report_file);
  const logFile = join(ROOT, config.output.log_file);
  const telemetryFile = join(ROOT, config.output.telemetry_file);

  // Write JSON report
  ensureDir(reportFile);
  writeFileSync(reportFile, JSON.stringify(report, null, 2));
  log('info', `Report written to ${reportFile}`);

  // Write log entry
  ensureDir(logFile);
  const logEntry = {
    timestamp: TIMESTAMP,
    action: 'memory_audit',
    outcome: report.status,
    meta: report.summary
  };
  appendFileSync(logFile, JSON.stringify(logEntry) + '\n');
  log('info', `Log entry written to ${logFile}`);

  // Write telemetry
  ensureDir(telemetryFile);
  const telemetryEntry = {
    ts: TIMESTAMP,
    event: 'memory_audit_completed',
    audit_id: report.audit_id,
    status: report.status,
    total_files: report.summary.total_files,
    issues: report.summary.missing_required + report.summary.checksum_mismatches + report.summary.broken_references,
    alerts: report.alerts.length
  };
  appendFileSync(telemetryFile, JSON.stringify(telemetryEntry) + '\n');
  log('info', `Telemetry written to ${telemetryFile}`);
}

// Main execution
async function main() {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🔍 Memory Consistency & Checksum Auditor');
  console.log('   Phase 21.2 - SOT Memory Verification');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');

  try {
    // Load configuration
    log('info', 'Loading configuration...');
    const config = loadConfig();
    log('info', `Configuration loaded: v${config.version}`);

    // Scan memory files
    log('info', 'Scanning memory files...');
    const scannedFiles = scanMemoryFiles(config);
    log('info', `Scanned ${scannedFiles.all_files.length} files`);

    // Verify integrity
    log('info', 'Verifying index integrity...');
    const issues = verifyIndexIntegrity(scannedFiles, config);

    const totalIssues =
      issues.missing_required.length +
      issues.checksum_mismatches.length +
      issues.broken_references.length +
      issues.orphaned_files.length;

    log('info', `Found ${totalIssues} integrity issues`);

    // Generate report
    log('info', 'Generating audit report...');
    const report = generateReport(scannedFiles, issues, config);

    // Write output
    log('info', 'Writing output files...');
    writeOutput(report, config);

    // Summary
    console.log('');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`📊 Audit Summary`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`   Status: ${report.status.toUpperCase()}`);
    console.log(`   Total Files: ${report.summary.total_files}`);
    console.log(`   Index Files: ${report.summary.index_files}`);
    console.log(`   Snapshot Files: ${report.summary.snapshot_files}`);
    console.log(`   Attestation Files: ${report.summary.attestation_files}`);
    console.log('');
    console.log(`   Issues:`);
    console.log(`   - Missing Required: ${issues.missing_required.length}`);
    console.log(`   - Checksum Mismatches: ${issues.checksum_mismatches.length}`);
    console.log(`   - Broken References: ${issues.broken_references.length}`);
    console.log(`   - Orphaned Files: ${issues.orphaned_files.length}`);
    console.log('');

    if (report.alerts.length > 0) {
      console.log(`⚠️  Alerts (${report.alerts.length}):`);
      for (const alert of report.alerts) {
        console.log(`   [${alert.level.toUpperCase()}] ${alert.message}`);
      }
      console.log('');
    }

    console.log(`✅ Report: ${config.output.report_file}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('');

    // Exit with appropriate code
    if (report.status === 'fail') {
      process.exit(1);
    }

  } catch (error) {
    console.error('');
    console.error('❌ Audit failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export { main, scanMemoryFiles, verifyIndexIntegrity, generateReport };
