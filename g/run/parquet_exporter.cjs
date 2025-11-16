#!/usr/bin/env node

/**
 * Parquet Exporter for OPS-Atomic Telemetry
 *
 * Converts markdown reports to Parquet format for analytics
 * Phase 7.8 - Data Analytics Integration
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
const CONFIG = {
  reportsDir: path.join(process.env.HOME, '02luka', 'g', 'reports'),
  outputDir: path.join(process.env.HOME, '02luka', 'g', 'analytics'),
  summaryDir: path.join(process.env.HOME, '02luka', 'g', 'reports', 'parquet'),
  dryRun: process.argv.includes('--dry'),
};

// Ensure output directories exist
function ensureDirectories() {
  [CONFIG.outputDir, CONFIG.summaryDir].forEach(dir => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  });
}

// Parse heartbeat markdown to JSON
function parseHeartbeatReport(filePath, content) {
  const filename = path.basename(filePath);
  const lines = content.split('\n');

  const data = {
    filename,
    report_type: 'heartbeat',
    timestamp: null,
    status: null,
    duration_ms: null,
    redis_status: 'unknown',
    database_status: 'unknown',
    api_status: 'unknown',
    launchagent_optimizer: 'unknown',
    launchagent_digest: 'unknown',
  };

  for (const line of lines) {
    // Extract timestamp
    if (line.startsWith('**Timestamp:**')) {
      data.timestamp = line.replace('**Timestamp:**', '').trim();
    }
    // Extract status
    if (line.startsWith('**Status:**')) {
      data.status = line.replace('**Status:**', '').trim();
    }
    // Extract duration
    if (line.startsWith('**Duration:**')) {
      const match = line.match(/(\d+)ms/);
      if (match) data.duration_ms = parseInt(match[1], 10);
    }
    // Extract Redis status
    if (line.includes('Redis responding')) {
      data.redis_status = line.includes('✅') ? 'ok' : 'error';
    }
    // Extract Database status
    if (line.includes('Database file exists')) {
      data.database_status = line.includes('✅') ? 'ok' : 'error';
    }
    // Extract API status
    if (line.includes('Endpoint not responding') || line.includes('API Health:')) {
      data.api_status = line.includes('✅') ? 'ok' : 'warn';
    }
    // Extract LaunchAgent statuses
    if (line.includes('com.02luka.optimizer:')) {
      data.launchagent_optimizer = line.includes('✅') ? 'loaded' : 'not_loaded';
    }
    if (line.includes('com.02luka.digest:')) {
      data.launchagent_digest = line.includes('✅') ? 'loaded' : 'not_loaded';
    }
  }

  return data;
}

// Scan reports directory recursively
function scanReports() {
  const reports = [];

  function scanDir(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);

      if (entry.isDirectory()) {
        // Skip parquet and analytics directories
        if (!fullPath.includes('/parquet') && !fullPath.includes('/analytics')) {
          scanDir(fullPath);
        }
      } else if (entry.name.endsWith('.md')) {
        try {
          const content = fs.readFileSync(fullPath, 'utf8');

          // Parse heartbeat reports
          if (entry.name.startsWith('heartbeat_')) {
            const data = parseHeartbeatReport(fullPath, content);
            reports.push(data);
          }
          // Add other report types here as needed
        } catch (err) {
          console.error(`Error reading ${fullPath}:`, err.message);
        }
      }
    }
  }

  scanDir(CONFIG.reportsDir);
  return reports;
}

// Convert JSON to Parquet using DuckDB
function exportToParquet(data, outputPath) {
  const startTime = Date.now();

  // Create temporary JSON file
  const tempJson = path.join(CONFIG.outputDir, 'temp_export.json');
  fs.writeFileSync(tempJson, data.map(d => JSON.stringify(d)).join('\n'));

  try {
    // Use DuckDB to convert JSON to Parquet
    const sql = `
      COPY (
        SELECT * FROM read_json_auto('${tempJson}')
      ) TO '${outputPath}' (FORMAT PARQUET, COMPRESSION SNAPPY);
    `;

    execSync(`duckdb -c "${sql}"`, { stdio: 'pipe' });

    // Clean up temp file
    fs.unlinkSync(tempJson);

    return Date.now() - startTime;
  } catch (err) {
    // Clean up temp file on error
    if (fs.existsSync(tempJson)) {
      fs.unlinkSync(tempJson);
    }
    throw err;
  }
}

// Generate summary report
function generateSummary(rowCount, fileSize, duration, outputPath) {
  const date = new Date().toISOString().split('T')[0].replace(/-/g, '');
  const summaryPath = path.join(CONFIG.summaryDir, `parquet_export_summary_${date}.md`);

  const summary = `# Parquet Export Summary

**Date:** ${new Date().toISOString()}
**Status:** ✅ Success

## Export Details

- **Row Count:** ${rowCount}
- **File Size:** ${(fileSize / 1024).toFixed(2)} KB
- **Duration:** ${duration}ms
- **Output File:** \`${path.basename(outputPath)}\`
- **Compression:** Snappy

## Validation

- ✅ DuckDB export successful
- ✅ Parquet file created
- ✅ Compression applied

---

*Generated by parquet_exporter.cjs*
`;

  fs.writeFileSync(summaryPath, summary);
  console.log(`[INFO] Summary report: ${summaryPath}`);
}

// Main execution
async function main() {
  console.log('[INFO] === Parquet Exporter Starting ===');

  if (CONFIG.dryRun) {
    console.log('[INFO] DRY RUN MODE - No files will be created');
  }

  // Ensure directories
  ensureDirectories();

  // Scan and parse reports
  console.log('[INFO] Scanning reports...');
  const reports = scanReports();
  console.log(`[INFO] Found ${reports.length} reports to export`);

  if (reports.length === 0) {
    console.log('[WARN] No reports found to export');
    return;
  }

  if (CONFIG.dryRun) {
    console.log('[INFO] Sample data (first 3 records):');
    console.log(JSON.stringify(reports.slice(0, 3), null, 2));
    console.log('[INFO] DRY RUN COMPLETE');
    return;
  }

  // Generate output filename
  const date = new Date().toISOString().split('T')[0].replace(/-/g, '');
  const outputPath = path.join(CONFIG.outputDir, `ops_atomic_${date}.parquet`);

  // Export to Parquet
  console.log('[INFO] Exporting to Parquet...');
  const duration = exportToParquet(reports, outputPath);

  // Get file stats
  const stats = fs.statSync(outputPath);

  console.log(`[INFO] ✅ Export complete: ${outputPath}`);
  console.log(`[INFO] File size: ${(stats.size / 1024).toFixed(2)} KB`);
  console.log(`[INFO] Duration: ${duration}ms`);

  // Generate summary report
  generateSummary(reports.length, stats.size, duration, outputPath);

  console.log('[INFO] === Parquet Exporter Complete ===');
}

// Error handling
main().catch(err => {
  console.error('[ERROR] Parquet export failed:', err.message);
  process.exit(1);
});
