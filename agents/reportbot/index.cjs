#!/usr/bin/env node
/**
 * Reportbot Agent
 * Reads latest OPS_ATOMIC report and generates JSON summary
 * Usage: node agents/reportbot/index.cjs
 */
const fs = require('fs');
const path = require('path');

const REPO = process.env.REPO_ROOT || process.cwd();
const REPORT_DIR = path.join(REPO, 'g', 'reports');
const OUT_JSON = path.join(REPO, 'g', 'reports', 'OPS_SUMMARY.json');

/**
 * Find latest OPS_ATOMIC report
 */
function latestReport() {
  if (!fs.existsSync(REPORT_DIR)) {
    console.error('Report directory not found:', REPORT_DIR);
    return null;
  }

  const files = fs.readdirSync(REPORT_DIR)
    .filter(f => /^OPS_ATOMIC_\d+_\d+\.md$/.test(f))
    .sort()
    .reverse();

  if (!files.length) return null;
  return path.join(REPORT_DIR, files[0]);
}

/**
 * Parse report markdown for key metrics
 */
function parseSummary(md, filename) {
  // Extract timestamp from filename (OPS_ATOMIC_YYMMDD_HHMMSS.md)
  const match = filename.match(/OPS_ATOMIC_(\d+)_(\d+)\.md/);
  const timestamp = match ? `20${match[1]}_${match[2]}` : 'unknown';

  // Find overall status
  let status = 'unknown';
  const statusMatch = md.match(/##\s*Phase\s*3.*Verify.*\n.*\n.*\n-\s*API.*:\s*(✅|❌)/i);
  if (statusMatch) {
    status = statusMatch[1] === '✅' ? 'OK' : 'FAIL';
  }

  // Extract service checks
  const services = {};
  const serviceLines = md.match(/^-\s*(API|UI|MCP).*?:\s*(✅|❌)/gim) || [];
  serviceLines.forEach(line => {
    const parts = line.match(/^-\s*(\w+).*?:\s*(✅|❌)/i);
    if (parts) {
      services[parts[1]] = parts[2] === '✅' ? 'UP' : 'DOWN';
    }
  });

  // Find failures and warnings
  const fails = [];
  const warns = [];

  // Look for explicit FAIL/ERROR markers
  const failMatches = md.matchAll(/(?:FAIL|ERROR|❌)[:\s-]+(.+)/gi);
  for (const m of failMatches) {
    const msg = m[1].trim();
    if (msg && msg.length > 3) fails.push(msg);
  }

  // Look for WARN markers
  const warnMatches = md.matchAll(/(?:WARN|⚠️)[:\s-]+(.+)/gi);
  for (const m of warnMatches) {
    const msg = m[1].trim();
    if (msg && msg.length > 3) warns.push(msg);
  }

  // Extract migration counts
  const migration = {};
  const migLines = md.match(/^-\s*(boss|g|docs)\/legacy_parent:\s*(\d+)\s*files/gim) || [];
  migLines.forEach(line => {
    const parts = line.match(/^-\s*(\w+)\/legacy_parent:\s*(\d+)\s*files/i);
    if (parts) {
      migration[parts[1]] = parseInt(parts[2], 10);
    }
  });

  // Extract git info
  const git = {};
  const gitMatch = md.match(/```\n(##\s*.+\n.+)\n```/);
  if (gitMatch) {
    git.status = gitMatch[1].trim();
  }

  return {
    timestamp,
    status,
    services,
    fails: [...new Set(fails)].slice(0, 10), // dedupe and limit
    warns: [...new Set(warns)].slice(0, 10),
    migration,
    git
  };
}

/**
 * Main execution
 */
function main() {
  console.log('[reportbot] Starting...');

  const reportPath = latestReport();
  if (!reportPath) {
    console.error('[reportbot] No OPS_ATOMIC report found in:', REPORT_DIR);
    process.exit(0);
  }

  console.log('[reportbot] Reading:', path.basename(reportPath));
  const md = fs.readFileSync(reportPath, 'utf8');
  const summary = parseSummary(md, path.basename(reportPath));

  const output = {
    generated_at: new Date().toISOString(),
    latest_file: path.basename(reportPath),
    ...summary
  };

  fs.writeFileSync(OUT_JSON, JSON.stringify(output, null, 2));
  console.log('[reportbot] Wrote:', OUT_JSON);
  console.log('[reportbot] Status:', output.status);
  console.log('[reportbot] Services:', Object.entries(output.services).map(([k,v]) => `${k}:${v}`).join(', '));

  if (output.fails.length > 0) {
    console.log('[reportbot] Failures detected:', output.fails.length);
  }
  if (output.warns.length > 0) {
    console.log('[reportbot] Warnings detected:', output.warns.length);
  }

  process.exit(0);
}

if (require.main === module) {
  main();
}

module.exports = main;
