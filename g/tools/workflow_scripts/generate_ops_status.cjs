#!/usr/bin/env node
/**
 * Generate Ops Status Board
 * Creates status.html, jobs.json, and related files for GitHub Pages deployment
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const OUTPUT_DIR = path.join(process.cwd(), 'dist', 'ops');
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_REPOSITORY = process.env.GITHUB_REPOSITORY || 'Ic1558/02luka';
const FORCE_REFRESH = process.env.FORCE_REFRESH === 'true';

// Ensure output directory exists
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

function httpsRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

async function fetchWorkflowRuns() {
  if (!GITHUB_TOKEN) {
    console.warn('⚠️  GITHUB_TOKEN not set, using limited API access');
    return [];
  }

  const [owner, repo] = GITHUB_REPOSITORY.split('/');
  const url = `https://api.github.com/repos/${owner}/${repo}/actions/runs?per_page=50&sort=updated&order=desc`;

  try {
    const response = await httpsRequest(url, {
      headers: {
        'Authorization': `Bearer ${GITHUB_TOKEN}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': '02luka-ops-status',
      },
    });

    return response.workflow_runs.slice(0, 20).map(run => ({
      id: run.id,
      name: run.name,
      status: run.status,
      conclusion: run.conclusion,
      created_at: run.created_at,
      updated_at: run.updated_at,
      head_branch: run.head_branch,
      workflow_id: run.workflow_id,
      html_url: run.html_url,
      run_number: run.run_number,
    }));
  } catch (error) {
    console.error('❌ Error fetching workflow runs:', error.message);
    return [];
  }
}

function generateJobsJSON(runs) {
  const jobs = {
    timestamp: new Date().toISOString(),
    total: runs.length,
    runs: runs.map(run => ({
      id: run.id,
      name: run.name,
      status: run.status,
      conclusion: run.conclusion,
      created_at: run.created_at,
      updated_at: run.updated_at,
      branch: run.head_branch,
      run_number: run.run_number,
      url: run.html_url,
    })),
    summary: {
      success: runs.filter(r => r.conclusion === 'success').length,
      failure: runs.filter(r => r.conclusion === 'failure').length,
      cancelled: runs.filter(r => r.conclusion === 'cancelled').length,
      in_progress: runs.filter(r => r.status === 'in_progress' || r.status === 'queued').length,
    },
  };

  return JSON.stringify(jobs, null, 2);
}

function generateStatusHTML(jobs) {
  const data = JSON.parse(jobs);
  const successCount = data.summary.success;
  const failureCount = data.summary.failure;
  const total = data.total;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>02luka Ops Status Board</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      background: #0d1117;
      color: #c9d1d9;
      padding: 20px;
      line-height: 1.6;
    }
    .container { max-width: 1200px; margin: 0 auto; }
    h1 { color: #58a6ff; margin-bottom: 20px; }
    .summary {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 15px;
      margin-bottom: 30px;
    }
    .stat-card {
      background: #161b22;
      border: 1px solid #30363d;
      border-radius: 6px;
      padding: 20px;
      text-align: center;
    }
    .stat-card.success { border-color: #238636; }
    .stat-card.failure { border-color: #da3633; }
    .stat-card.in-progress { border-color: #f85149; }
    .stat-value {
      font-size: 2em;
      font-weight: bold;
      margin: 10px 0;
    }
    .stat-label { color: #8b949e; font-size: 0.9em; }
    .runs-list {
      background: #161b22;
      border: 1px solid #30363d;
      border-radius: 6px;
      padding: 20px;
      margin-top: 30px;
    }
    .run-item {
      padding: 15px;
      border-bottom: 1px solid #30363d;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .run-item:last-child { border-bottom: none; }
    .run-name { font-weight: 500; }
    .run-status {
      padding: 4px 12px;
      border-radius: 12px;
      font-size: 0.85em;
      font-weight: 500;
    }
    .status-success { background: #238636; color: #fff; }
    .status-failure { background: #da3633; color: #fff; }
    .status-cancelled { background: #6e7681; color: #fff; }
    .status-in_progress { background: #f85149; color: #fff; }
    .status-queued { background: #f85149; color: #fff; }
    .run-link { color: #58a6ff; text-decoration: none; }
    .run-link:hover { text-decoration: underline; }
    .timestamp { color: #8b949e; font-size: 0.85em; margin-top: 20px; text-align: center; }
    .refresh-info { color: #8b949e; font-size: 0.85em; margin-top: 10px; text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <h1>🚀 02luka Operations Status Board</h1>
    
    <div class="summary">
      <div class="stat-card success">
        <div class="stat-label">Successful</div>
        <div class="stat-value">${successCount}</div>
      </div>
      <div class="stat-card failure">
        <div class="stat-label">Failed</div>
        <div class="stat-value">${failureCount}</div>
      </div>
      <div class="stat-card in-progress">
        <div class="stat-label">In Progress</div>
        <div class="stat-value">${data.summary.in_progress}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Total Runs</div>
        <div class="stat-value">${total}</div>
      </div>
    </div>

    <div class="runs-list">
      <h2>Recent Workflow Runs</h2>
      ${data.runs.map(run => {
        const statusClass = run.status === 'completed' 
          ? (run.conclusion === 'success' ? 'status-success' : run.conclusion === 'failure' ? 'status-failure' : 'status-cancelled')
          : 'status-in_progress';
        const statusText = run.status === 'completed' ? run.conclusion : run.status;
        const date = new Date(run.updated_at).toLocaleString();
        return `
        <div class="run-item">
          <div>
            <div class="run-name">${run.name}</div>
            <div style="color: #8b949e; font-size: 0.85em; margin-top: 5px;">
              #${run.run_number} • ${run.branch} • ${date}
            </div>
          </div>
          <div>
            <span class="run-status ${statusClass}">${statusText}</span>
            <a href="${run.url}" target="_blank" class="run-link" style="margin-left: 10px;">View →</a>
          </div>
        </div>`;
      }).join('')}
    </div>

    <div class="timestamp">
      Last updated: ${new Date().toLocaleString()}
    </div>
    <div class="refresh-info">
      Auto-refresh: Every 60 seconds
    </div>
  </div>

  <script>
    // Auto-refresh every 60 seconds
    setTimeout(() => {
      window.location.reload();
    }, 60000);
  </script>
</body>
</html>`;
}

function generateHealthHTML() {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>02luka Health Check</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0d1117;
      color: #c9d1d9;
      padding: 40px;
      text-align: center;
    }
    h1 { color: #58a6ff; margin-bottom: 20px; }
    .status { font-size: 2em; color: #238636; margin: 20px 0; }
  </style>
</head>
<body>
  <h1>02luka System Health</h1>
  <div class="status">✅ OPERATIONAL</div>
  <p>Last checked: ${new Date().toLocaleString()}</p>
</body>
</html>`;
}

function generateManifestJSON() {
  return JSON.stringify({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.GITHUB_SHA || 'unknown',
    branch: process.env.GITHUB_REF || 'unknown',
  }, null, 2);
}

async function main() {
  console.log('🚀 Generating Ops Status Board...');

  try {
    // Fetch workflow runs
    const runs = await fetchWorkflowRuns();
    console.log(`📊 Fetched ${runs.length} workflow runs`);

    // Generate jobs.json
    const jobsJSON = generateJobsJSON(runs);
    fs.writeFileSync(path.join(OUTPUT_DIR, 'jobs.json'), jobsJSON);
    console.log('✅ Generated jobs.json');

    // Generate status.html
    const statusHTML = generateStatusHTML(jobsJSON);
    fs.writeFileSync(path.join(OUTPUT_DIR, 'status.html'), statusHTML);
    console.log('✅ Generated status.html');

    // Generate _health.html
    const healthHTML = generateHealthHTML();
    fs.writeFileSync(path.join(OUTPUT_DIR, '_health.html'), healthHTML);
    console.log('✅ Generated _health.html');

    // Generate manifest.json
    const manifestJSON = generateManifestJSON();
    fs.writeFileSync(path.join(OUTPUT_DIR, 'manifest.json'), manifestJSON);
    console.log('✅ Generated manifest.json');

    console.log('🎉 Ops Status Board generated successfully!');
    console.log(`📁 Output directory: ${OUTPUT_DIR}`);
  } catch (error) {
    console.error('❌ Error generating status board:', error);
    process.exit(1);
  }
}

main();

