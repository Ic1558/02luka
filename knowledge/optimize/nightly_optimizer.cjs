#!/usr/bin/env node
/**
 * Nightly Optimizer - Automated database optimization workflow
 *
 * Workflow:
 * 1. Run index advisor to analyze query performance
 * 2. Generate recommendations report
 * 3. Optionally auto-apply indexes (if --auto-apply)
 * 4. Send notifications on completion
 *
 * Features:
 * - Advisory mode (default): Generate report only
 * - Auto-apply mode (--auto-apply): Apply recommended indexes
 * - Cooldown protection (won't run if last run < 23 hours ago)
 * - Graceful failure handling
 */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const ROOT = path.resolve(__dirname, '../..');
const COOLDOWN_FILE = path.join(ROOT, 'g/reports/nightly_optimizer_last_run.txt');
const COOLDOWN_HOURS = 23; // Minimum hours between runs

/**
 * Main execution
 */
async function main() {
  const args = process.argv.slice(2);
  const autoApply = args.includes('--auto-apply');
  const force = args.includes('--force');
  const verbose = args.includes('--verbose');

  console.log('🌙 Nightly Optimizer - Database Optimization Workflow\n');

  // Check cooldown (unless forced)
  if (!force && !checkCooldown()) {
    console.log('⏸️  Cooldown active - last run < 23 hours ago');
    console.log('   Use --force to override\n');
    process.exit(0);
  }

  const startTime = Date.now();

  // Step 1: Run index advisor
  console.log('📊 Step 1: Running index advisor...\n');
  const advisorResult = await runIndexAdvisor(verbose);

  if (advisorResult.exitCode !== 0 && advisorResult.exitCode !== 1) {
    console.error('❌ Index advisor failed');
    console.error(advisorResult.stderr);
    process.exit(1);
  }

  // Step 2: Parse advisor report
  const report = readAdvisorReport();

  if (!report) {
    console.log('⚠️  No advisor report generated\n');
    process.exit(0);
  }

  console.log(`\n📋 Advisor Results:`);
  console.log(`   Slow queries: ${report.slow_queries?.length || 0}`);
  console.log(`   Recommendations: ${report.recommendations?.length || 0}\n`);

  // Step 3: Auto-apply indexes (if enabled)
  if (autoApply && report.recommendations?.length > 0) {
    console.log('⚙️  Step 2: Auto-applying indexes...\n');
    const applyResult = await runApplyIndexes(verbose);

    if (applyResult.exitCode !== 0) {
      console.error('❌ Index application failed');
      console.error(applyResult.stderr);
      process.exit(1);
    }

    console.log('✅ Indexes applied successfully\n');
  } else if (report.recommendations?.length > 0) {
    console.log('📋 Advisory mode: Indexes NOT auto-applied');
    console.log('   Run with --auto-apply to apply automatically\n');
  }

  // Step 4: Update cooldown
  updateCooldown();

  const duration = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log(`\n✅ Nightly optimization complete (${duration}s)\n`);

  // Exit code: 0 = success, 1 = recommendations pending
  process.exit(report.recommendations?.length > 0 && !autoApply ? 1 : 0);
}

/**
 * Check if cooldown period has elapsed
 */
function checkCooldown() {
  if (!fs.existsSync(COOLDOWN_FILE)) {
    return true; // No previous run
  }

  const lastRunTime = parseInt(fs.readFileSync(COOLDOWN_FILE, 'utf8'));
  const hoursElapsed = (Date.now() - lastRunTime) / (1000 * 60 * 60);

  return hoursElapsed >= COOLDOWN_HOURS;
}

/**
 * Update cooldown timestamp
 */
function updateCooldown() {
  const dir = path.dirname(COOLDOWN_FILE);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(COOLDOWN_FILE, Date.now().toString());
}

/**
 * Run index advisor
 */
function runIndexAdvisor(verbose) {
  return runCommand('node', [
    path.join(ROOT, 'knowledge/optimize/index_advisor.cjs'),
    ...(verbose ? ['--verbose'] : [])
  ]);
}

/**
 * Run apply indexes script
 */
function runApplyIndexes(verbose) {
  return runCommand('bash', [
    path.join(ROOT, 'knowledge/optimize/apply_indexes.sh'),
    ...(verbose ? ['--verbose'] : [])
  ]);
}

/**
 * Read advisor report
 */
function readAdvisorReport() {
  const reportPath = path.join(ROOT, 'g/reports/index_advisor_report.json');

  if (!fs.existsSync(reportPath)) {
    return null;
  }

  try {
    return JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  } catch (err) {
    console.error(`Failed to parse report: ${err.message}`);
    return null;
  }
}

/**
 * Run a shell command and capture output
 */
function runCommand(cmd, args) {
  return new Promise((resolve) => {
    const proc = spawn(cmd, args, {
      stdio: ['ignore', 'inherit', 'pipe']
    });

    let stderr = '';

    proc.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    proc.on('close', (exitCode) => {
      resolve({
        exitCode,
        stderr
      });
    });

    proc.on('error', (err) => {
      resolve({
        exitCode: 1,
        stderr: err.message
      });
    });
  });
}

// Run
if (require.main === module) {
  main().catch(err => {
    console.error('❌ Nightly optimizer failed:', err.message);
    process.exit(1);
  });
}

module.exports = { main };
