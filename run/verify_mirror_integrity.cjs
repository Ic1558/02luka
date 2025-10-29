#!/usr/bin/env node
/**
 * Phase 10.4 - Mirror Integrity Monitor
 * Daily link/hash verification of the public mirror; alert if broken
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const crypto = require('crypto');

// Configuration
const CONFIG = {
  baseUrl: process.env.MIRROR_BASE_URL || 'https://ops.theedges.work',
  outputDir: 'dist/ops',
  stateDir: 'g/state',
  logsDir: 'g/logs',
  alertsDir: 'g/state/alerts',
  timeout: 10000, // 10 seconds
  retries: 3,
  retryDelay: 1000, // 1 second
  targets: [
    { url: '/ops/status.html', critical: true, type: 'html' },
    { url: '/ops/jobs.json', critical: true, type: 'json' },
    { url: '/ops/_health.html', critical: true, type: 'html' },
    { url: '/ops/manifest.json', critical: true, type: 'json' },
    { url: '/ops/latest.json', critical: false, type: 'json' },
    { url: '/ops/latest.tsv', critical: false, type: 'text' },
    { url: '/ops/dashboard.html', critical: false, type: 'html' },
    { url: '/docs/index.html', critical: true, type: 'html' },
    { url: '/docs/assets/docs.css', critical: false, type: 'css' },
    { url: '/docs/assets/docs.js', critical: false, type: 'js' }
  ]
};

// Ensure directories exist
[CONFIG.outputDir, CONFIG.stateDir, CONFIG.logsDir, CONFIG.alertsDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

/**
 * Make HTTP request with timeout and retries
 */
function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const requestOptions = {
      timeout: CONFIG.timeout,
      ...options
    };

    const req = https.request(url, requestOptions, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          data: data,
          size: data.length
        });
      });
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.end();
  });
}

/**
 * Check a single URL with retries
 */
async function checkUrl(target, attempt = 1) {
  const fullUrl = CONFIG.baseUrl + target.url;
  
  try {
    const startTime = Date.now();
    const response = await makeRequest(fullUrl);
    const endTime = Date.now();
    
    const result = {
      url: target.url,
      fullUrl: fullUrl,
      statusCode: response.statusCode,
      contentType: response.headers['content-type'] || 'unknown',
      size: response.size,
      latency: endTime - startTime,
      success: response.statusCode >= 200 && response.statusCode < 400,
      critical: target.critical,
      type: target.type,
      timestamp: new Date().toISOString()
    };
    
    // Validate content type
    if (target.type === 'json' && !response.headers['content-type']?.includes('json')) {
      result.warning = 'Unexpected content type for JSON';
    }
    
    if (target.type === 'html' && !response.headers['content-type']?.includes('html')) {
      result.warning = 'Unexpected content type for HTML';
    }
    
    // Calculate SHA256 hash
    if (response.data) {
      result.sha256 = crypto.createHash('sha256').update(response.data).digest('hex');
    }
    
    return result;
    
  } catch (error) {
    if (attempt < CONFIG.retries) {
      console.log(`⚠️ Retry ${attempt}/${CONFIG.retries} for ${target.url}: ${error.message}`);
      await new Promise(resolve => setTimeout(resolve, CONFIG.retryDelay * attempt));
      return checkUrl(target, attempt + 1);
    }
    
    return {
      url: target.url,
      fullUrl: fullUrl,
      statusCode: 0,
      contentType: 'unknown',
      size: 0,
      latency: 0,
      success: false,
      critical: target.critical,
      type: target.type,
      error: error.message,
      timestamp: new Date().toISOString()
    };
  }
}

/**
 * Check all URLs
 */
async function checkAllUrls() {
  console.log(`🔍 Checking ${CONFIG.targets.length} URLs...`);
  
  const results = [];
  const startTime = Date.now();
  
  for (const target of CONFIG.targets) {
    console.log(`  Checking ${target.url}...`);
    const result = await checkUrl(target);
    results.push(result);
    
    if (result.success) {
      console.log(`    ✅ ${result.statusCode} (${result.latency}ms, ${result.size} bytes)`);
    } else {
      console.log(`    ❌ ${result.error || 'Failed'} (${result.statusCode})`);
    }
  }
  
  const endTime = Date.now();
  const totalTime = endTime - startTime;
  
  return {
    results,
    summary: {
      total: results.length,
      successful: results.filter(r => r.success).length,
      failed: results.filter(r => !r.success).length,
      critical_failed: results.filter(r => !r.success && r.critical).length,
      total_time: totalTime,
      timestamp: new Date().toISOString()
    }
  };
}

/**
 * Generate integrity.json
 */
function generateIntegrityJson(checkResult) {
  const integrity = {
    check_timestamp: checkResult.summary.timestamp,
    base_url: CONFIG.baseUrl,
    overall_status: checkResult.summary.critical_failed > 0 ? 'critical' : 
                   checkResult.summary.failed > 0 ? 'warning' : 'healthy',
    summary: checkResult.summary,
    checks: checkResult.results.map(result => ({
      url: result.url,
      status_code: result.statusCode,
      content_type: result.contentType,
      size_bytes: result.size,
      latency_ms: result.latency,
      success: result.success,
      critical: result.critical,
      sha256: result.sha256,
      error: result.error,
      warning: result.warning
    }))
  };
  
  const outputPath = path.join(CONFIG.outputDir, 'integrity.json');
  fs.writeFileSync(outputPath, JSON.stringify(integrity, null, 2));
  console.log(`✅ Generated ${outputPath}`);
  
  return integrity;
}

/**
 * Generate integrity.tsv
 */
function generateIntegrityTsv(checkResult) {
  const headers = ['url', 'status_code', 'content_type', 'size_bytes', 'latency_ms', 'success', 'critical', 'sha256', 'error'];
  const rows = checkResult.results.map(result => [
    result.url,
    result.statusCode,
    result.contentType,
    result.size,
    result.latency,
    result.success,
    result.critical,
    result.sha256 || '',
    result.error || ''
  ]);
  
  const tsv = [headers.join('\t'), ...rows.map(row => row.join('\t'))].join('\n');
  const outputPath = path.join(CONFIG.outputDir, 'integrity.tsv');
  fs.writeFileSync(outputPath, tsv);
  console.log(`✅ Generated ${outputPath}`);
}

/**
 * Append to integrity history
 */
function appendToHistory(integrity) {
  const historyPath = path.join(CONFIG.stateDir, 'integrity_history.jsonl');
  const historyEntry = {
    timestamp: integrity.check_timestamp,
    overall_status: integrity.overall_status,
    total_checks: integrity.summary.total,
    successful: integrity.summary.successful,
    failed: integrity.summary.failed,
    critical_failed: integrity.summary.critical_failed,
    total_time: integrity.summary.total_time
  };
  
  fs.appendFileSync(historyPath, JSON.stringify(historyEntry) + '\n');
  console.log(`✅ Appended to ${historyPath}`);
}

/**
 * Generate alerts
 */
function generateAlerts(integrity) {
  const alerts = [];
  
  // Critical failures
  const criticalFailures = integrity.checks.filter(check => !check.success && check.critical);
  if (criticalFailures.length > 0) {
    alerts.push({
      level: 'critical',
      message: `${criticalFailures.length} critical URLs failed`,
      details: criticalFailures.map(f => `${f.url} (${f.status_code})`).join(', '),
      timestamp: integrity.check_timestamp
    });
  }
  
  // Warnings
  const warnings = integrity.checks.filter(check => check.warning);
  if (warnings.length > 0) {
    alerts.push({
      level: 'warning',
      message: `${warnings.length} URLs have warnings`,
      details: warnings.map(w => `${w.url}: ${w.warning}`).join(', '),
      timestamp: integrity.check_timestamp
    });
  }
  
  // High latency
  const slowUrls = integrity.checks.filter(check => check.latency_ms > 5000);
  if (slowUrls.length > 0) {
    alerts.push({
      level: 'warning',
      message: `${slowUrls.length} URLs are slow (>5s)`,
      details: slowUrls.map(s => `${s.url} (${s.latency_ms}ms)`).join(', '),
      timestamp: integrity.check_timestamp
    });
  }
  
  // Generate alert files
  alerts.forEach((alert, index) => {
    const alertFile = path.join(CONFIG.alertsDir, `integrity_${Date.now()}_${index}.json`);
    fs.writeFileSync(alertFile, JSON.stringify(alert, null, 2));
    console.log(`🚨 Generated alert: ${alertFile}`);
  });
  
  // Append to ops_alerts.log
  if (alerts.length > 0) {
    const logPath = path.join(CONFIG.logsDir, 'ops_alerts.log');
    const logEntry = `[${integrity.check_timestamp}] MIRROR_INTEGRITY: ${alerts.map(a => `${a.level.toUpperCase()}: ${a.message}`).join('; ')}\n`;
    fs.appendFileSync(logPath, logEntry);
    console.log(`📝 Appended to ${logPath}`);
  }
  
  return alerts;
}

/**
 * Main execution
 */
async function main() {
  console.log('🚀 Phase 10.4 - Mirror Integrity Monitor');
  console.log('========================================');
  console.log(`🌐 Base URL: ${CONFIG.baseUrl}`);
  console.log(`🎯 Targets: ${CONFIG.targets.length} URLs`);
  console.log('');
  
  try {
    // Check all URLs
    const checkResult = await checkAllUrls();
    
    console.log('');
    console.log('📊 Summary:');
    console.log(`  Total: ${checkResult.summary.total}`);
    console.log(`  Successful: ${checkResult.summary.successful}`);
    console.log(`  Failed: ${checkResult.summary.failed}`);
    console.log(`  Critical Failed: ${checkResult.summary.critical_failed}`);
    console.log(`  Total Time: ${checkResult.summary.total_time}ms`);
    
    // Generate integrity files
    console.log('');
    console.log('📄 Generating integrity files...');
    const integrity = generateIntegrityJson(checkResult);
    generateIntegrityTsv(checkResult);
    
    // Append to history
    appendToHistory(integrity);
    
    // Generate alerts
    console.log('');
    console.log('🚨 Checking for alerts...');
    const alerts = generateAlerts(integrity);
    
    if (alerts.length > 0) {
      console.log(`  Generated ${alerts.length} alerts`);
      alerts.forEach(alert => {
        console.log(`    ${alert.level.toUpperCase()}: ${alert.message}`);
      });
    } else {
      console.log('  No alerts generated');
    }
    
    console.log('');
    console.log('✅ Phase 10.4 Mirror Integrity Monitor completed!');
    console.log(`📊 Status: ${integrity.overall_status.toUpperCase()}`);
    console.log(`📄 Files: dist/ops/integrity.json, dist/ops/integrity.tsv`);
    console.log(`📝 History: g/state/integrity_history.jsonl`);
    console.log(`🚨 Alerts: ${alerts.length} generated`);
    
    // Exit with error code if critical failures
    if (integrity.overall_status === 'critical') {
      console.log('');
      console.log('❌ Critical failures detected - exiting with error code');
      process.exit(1);
    }
    
  } catch (error) {
    console.error('❌ Error in mirror integrity monitor:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { checkAllUrls, generateIntegrityJson, generateAlerts };
