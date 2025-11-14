#!/usr/bin/env node
/**
 * Verify Mirror Integrity
 * Checks URLs for availability, latency, and content integrity
 * Generates integrity.json, integrity.tsv, and alert files
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const crypto = require('crypto');

const OUTPUT_DIR = path.join(process.cwd(), 'dist', 'ops');
const STATE_DIR = path.join(process.cwd(), 'g', 'state');
const LOGS_DIR = path.join(process.cwd(), 'g', 'logs');
const ALERTS_DIR = path.join(STATE_DIR, 'alerts');
const BASE_URL = process.env.MIRROR_BASE_URL || 'https://ops.theedges.work';

// URLs to check (10 URLs as per workflow spec)
const URLS_TO_CHECK = [
  `${BASE_URL}/ops/status.html`,
  `${BASE_URL}/ops/jobs.json`,
  `${BASE_URL}/ops/_health.html`,
  `${BASE_URL}/ops/manifest.json`,
  `${BASE_URL}/ops/integrity.json`,
  `${BASE_URL}/ops/integrity.tsv`,
  `${BASE_URL}/_health.html`,
  `${BASE_URL}/manifest.json`,
  `${BASE_URL}/docs/`,
  `${BASE_URL}/`,
];

// Ensure directories exist
[OUTPUT_DIR, STATE_DIR, LOGS_DIR, ALERTS_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

function httpsRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();
    const req = https.request(url, { timeout: 10000, ...options }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        const latency = Date.now() - startTime;
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: data,
          latency,
        });
      });
    });
    req.on('error', (error) => {
      const latency = Date.now() - startTime;
      reject({ error: error.message, latency });
    });
    req.on('timeout', () => {
      req.destroy();
      reject({ error: 'Request timeout', latency: 10000 });
    });
    req.end();
  });
}

function calculateSHA256(content) {
  return crypto.createHash('sha256').update(content).digest('hex');
}

async function checkURL(url) {
  try {
    const result = await httpsRequest(url);
    
    // Check if status code indicates success (200-299)
    const isSuccess = result.statusCode >= 200 && result.statusCode < 300;
    
    if (!isSuccess) {
      return {
        url,
        status: 'error',
        statusCode: result.statusCode,
        latency: result.latency,
        sha256: null,
        contentLength: result.body.length,
        timestamp: new Date().toISOString(),
        error: `HTTP ${result.statusCode}`,
      };
    }
    
    const sha256 = calculateSHA256(result.body);
    
    return {
      url,
      status: 'ok',
      statusCode: result.statusCode,
      latency: result.latency,
      sha256,
      contentLength: result.body.length,
      timestamp: new Date().toISOString(),
      error: null,
    };
  } catch (error) {
    return {
      url,
      status: 'error',
      statusCode: null,
      latency: error.latency || 0,
      sha256: null,
      contentLength: 0,
      timestamp: new Date().toISOString(),
      error: error.error || 'Unknown error',
    };
  }
}

function generateIntegrityJSON(results) {
  const summary = {
    total: results.length,
    ok: results.filter(r => r.status === 'ok').length,
    errors: results.filter(r => r.status === 'error').length,
    avgLatency: results.reduce((sum, r) => sum + r.latency, 0) / results.length,
    timestamp: new Date().toISOString(),
  };

  return {
    summary,
    checks: results,
  };
}

function generateIntegrityTSV(results) {
  const header = 'URL\tStatus\tStatusCode\tLatency(ms)\tSHA256\tContentLength\tTimestamp\tError\n';
  const rows = results.map(r => 
    `${r.url}\t${r.status}\t${r.statusCode || 'N/A'}\t${r.latency}\t${r.sha256 || 'N/A'}\t${r.contentLength}\t${r.timestamp}\t${r.error || 'N/A'}`
  ).join('\n');
  
  return header + rows;
}

function generateAlert(result) {
  if (result.status === 'ok') {
    return null;
  }

  const alert = {
    alert_id: `alert_${Date.now()}_${result.url.replace(/[^a-zA-Z0-9]/g, '_')}`,
    severity: 'critical',
    type: 'mirror_integrity_failure',
    url: result.url,
    error: result.error,
    timestamp: new Date().toISOString(),
    status_code: result.statusCode,
  };

  return alert;
}

function writeAlertLog(alert) {
  const logFile = path.join(LOGS_DIR, 'ops_alerts.log');
  const logEntry = `${alert.timestamp}\t${alert.severity}\t${alert.type}\t${alert.url}\t${alert.error}\n`;
  fs.appendFileSync(logFile, logEntry);
}

async function main() {
  console.log('🔍 Running mirror integrity check...');
  console.log(`🌐 Base URL: ${BASE_URL}`);
  console.log(`📋 Checking ${URLS_TO_CHECK.length} URLs...\n`);

  const results = [];
  
  for (const url of URLS_TO_CHECK) {
    process.stdout.write(`  Checking ${url}... `);
    const result = await checkURL(url);
    results.push(result);
    
    if (result.status === 'ok') {
      console.log(`✅ ${result.statusCode} (${result.latency}ms)`);
    } else {
      console.log(`❌ ${result.error}`);
    }
  }

  console.log('\n📊 Generating integrity reports...');

  // Generate integrity.json
  const integrityJSON = generateIntegrityJSON(results);
  fs.writeFileSync(
    path.join(OUTPUT_DIR, 'integrity.json'),
    JSON.stringify(integrityJSON, null, 2)
  );
  console.log('✅ Generated integrity.json');

  // Generate integrity.tsv
  const integrityTSV = generateIntegrityTSV(results);
  fs.writeFileSync(
    path.join(OUTPUT_DIR, 'integrity.tsv'),
    integrityTSV
  );
  console.log('✅ Generated integrity.tsv');

  // Generate alerts for failures
  const alerts = results
    .map(generateAlert)
    .filter(a => a !== null);

  if (alerts.length > 0) {
    console.log(`🚨 Generated ${alerts.length} alert(s)`);
    
    for (const alert of alerts) {
      const alertFile = path.join(ALERTS_DIR, `${alert.alert_id}.json`);
      fs.writeFileSync(alertFile, JSON.stringify(alert, null, 2));
      writeAlertLog(alert);
    }
  } else {
    console.log('✅ No alerts generated (all checks passed)');
  }

  // Summary
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📊 Integrity Check Summary');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`   Total URLs: ${integrityJSON.summary.total}`);
  console.log(`   ✅ Successful: ${integrityJSON.summary.ok}`);
  console.log(`   ❌ Failed: ${integrityJSON.summary.errors}`);
  console.log(`   ⏱️  Avg Latency: ${Math.round(integrityJSON.summary.avgLatency)}ms`);
  console.log(`   📁 Output: ${OUTPUT_DIR}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Exit with error if any failures
  if (integrityJSON.summary.errors > 0) {
    console.error(`❌ Integrity check failed: ${integrityJSON.summary.errors} URL(s) failed`);
    process.exit(1);
  }

  console.log('✅ All integrity checks passed');
}

main().catch(error => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
