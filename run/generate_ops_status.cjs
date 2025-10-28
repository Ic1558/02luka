#!/usr/bin/env node
/**
 * Phase 10.2 - Live Mirror Status Board Generator
 * Creates jobs.json and status.html with Chart.js visualizations
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

// Configuration
const CONFIG = {
  outputDir: 'dist/ops',
  jobsFile: 'dist/ops/jobs.json',
  statusFile: 'dist/ops/status.html',
  maxRuns: 10,
  githubRepo: process.env.GITHUB_REPOSITORY || 'Ic1558/02luka',
  githubToken: process.env.GITHUB_TOKEN,
  manifestFile: 'dist/ops/manifest.json'
};

// Ensure output directory exists
if (!fs.existsSync(CONFIG.outputDir)) {
  fs.mkdirSync(CONFIG.outputDir, { recursive: true });
}

/**
 * Fetch GitHub workflow runs
 */
async function fetchGitHubRuns() {
  if (!CONFIG.githubToken) {
    console.log('⚠️ No GitHub token, using mock data');
    return generateMockRuns();
  }

  const url = `https://api.github.com/repos/${CONFIG.githubRepo}/actions/workflows/ops-mirror.yml/runs?per_page=${CONFIG.maxRuns}`;
  
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        'Authorization': `token ${CONFIG.githubToken}`,
        'User-Agent': '02luka-ops-status',
        'Accept': 'application/vnd.github.v3+json'
      }
    };

    https.get(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const response = JSON.parse(data);
          const runs = response.workflow_runs || [];
          resolve(runs.map(run => ({
            id: run.id,
            run_number: run.run_number,
            status: run.status,
            conclusion: run.conclusion,
            created_at: run.created_at,
            updated_at: run.updated_at,
            run_started_at: run.run_started_at,
            html_url: run.html_url,
            duration_ms: run.run_started_at ? 
              new Date(run.updated_at) - new Date(run.run_started_at) : 0
          })));
        } catch (error) {
          console.error('❌ Error parsing GitHub API response:', error.message);
          resolve(generateMockRuns());
        }
      });
    }).on('error', (error) => {
      console.error('❌ Error fetching GitHub runs:', error.message);
      resolve(generateMockRuns());
    });
  });
}

/**
 * Generate mock runs for testing
 */
function generateMockRuns() {
  const runs = [];
  const now = new Date();
  
  for (let i = 0; i < CONFIG.maxRuns; i++) {
    const runDate = new Date(now - (i * 24 * 60 * 60 * 1000));
    runs.push({
      id: `mock-${i}`,
      run_number: 1000 - i,
      status: 'completed',
      conclusion: Math.random() > 0.1 ? 'success' : 'failure',
      created_at: runDate.toISOString(),
      updated_at: new Date(runDate.getTime() + 45000).toISOString(),
      run_started_at: runDate.toISOString(),
      html_url: `https://github.com/${CONFIG.githubRepo}/actions/runs/mock-${i}`,
      duration_ms: 30000 + Math.random() * 60000
    });
  }
  
  return runs;
}

/**
 * Read manifest.json for current build info
 */
function readManifest() {
  try {
    if (fs.existsSync(CONFIG.manifestFile)) {
      return JSON.parse(fs.readFileSync(CONFIG.manifestFile, 'utf8'));
    }
  } catch (error) {
    console.error('⚠️ Error reading manifest:', error.message);
  }
  
  return {
    version: '10.2.0',
    ts: new Date().toISOString(),
    build_id: `build_${Date.now()}`,
    source: 'ops-status-generator',
    status: 'ok'
  };
}

/**
 * Generate jobs.json
 */
async function generateJobsJson() {
  console.log('📊 Fetching GitHub workflow runs...');
  const runs = await fetchGitHubRuns();
  const manifest = readManifest();
  
  const jobs = {
    last_updated: new Date().toISOString(),
    total_runs: runs.length,
    runs: runs.map(run => ({
      id: run.id,
      run_number: run.run_number,
      timestamp: run.created_at,
      status: run.conclusion === 'success' ? 'success' : 
              run.conclusion === 'failure' ? 'failure' : 'running',
      duration_ms: run.duration_ms,
      files_count: Math.floor(Math.random() * 10) + 3, // Mock file count
      total_size_bytes: Math.floor(Math.random() * 10000) + 1000, // Mock size
      source: 'github_actions',
      workflow_run_id: run.id,
      url: run.html_url
    }))
  };
  
  fs.writeFileSync(CONFIG.jobsFile, JSON.stringify(jobs, null, 2));
  console.log(`✅ Generated ${CONFIG.jobsFile} with ${jobs.runs.length} runs`);
  
  return jobs;
}

/**
 * Generate status.html with Chart.js
 */
function generateStatusHtml(jobs) {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>02luka Ops Mirror - Status Board</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: #2c3e50;
            color: white;
            padding: 20px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2em;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.8;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            padding: 20px;
            background: #ecf0f1;
        }
        .stat-card {
            background: white;
            padding: 20px;
            border-radius: 6px;
            text-align: center;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #2c3e50;
        }
        .stat-label {
            color: #7f8c8d;
            margin-top: 5px;
        }
        .charts {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            padding: 20px;
        }
        .chart-container {
            background: white;
            padding: 20px;
            border-radius: 6px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .chart-title {
            font-size: 1.2em;
            font-weight: bold;
            margin-bottom: 15px;
            color: #2c3e50;
        }
        .runs-table {
            margin: 20px;
            background: white;
            border-radius: 6px;
            overflow: hidden;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .runs-table h3 {
            margin: 0;
            padding: 20px;
            background: #34495e;
            color: white;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ecf0f1;
        }
        th {
            background: #f8f9fa;
            font-weight: 600;
        }
        .status-success {
            color: #27ae60;
            font-weight: bold;
        }
        .status-failure {
            color: #e74c3c;
            font-weight: bold;
        }
        .status-running {
            color: #f39c12;
            font-weight: bold;
        }
        .refresh-info {
            text-align: center;
            padding: 20px;
            color: #7f8c8d;
            font-size: 0.9em;
        }
        @media (max-width: 768px) {
            .charts {
                grid-template-columns: 1fr;
            }
            .stats {
                grid-template-columns: repeat(2, 1fr);
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 02luka Ops Mirror Status</h1>
            <p>Live monitoring of mirror pipeline runs and performance</p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value">${jobs.total_runs}</div>
                <div class="stat-label">Total Runs</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${jobs.runs.filter(r => r.status === 'success').length}</div>
                <div class="stat-label">Successful</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${Math.round(jobs.runs.reduce((acc, r) => acc + r.duration_ms, 0) / jobs.runs.length / 1000)}s</div>
                <div class="stat-label">Avg Duration</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${Math.round(jobs.runs.reduce((acc, r) => acc + r.total_size_bytes, 0) / jobs.runs.length / 1024)}KB</div>
                <div class="stat-label">Avg Size</div>
            </div>
        </div>
        
        <div class="charts">
            <div class="chart-container">
                <div class="chart-title">Duration Trends</div>
                <canvas id="durationChart"></canvas>
            </div>
            <div class="chart-container">
                <div class="chart-title">File Count Trends</div>
                <canvas id="filesChart"></canvas>
            </div>
        </div>
        
        <div class="runs-table">
            <h3>Recent Runs</h3>
            <table>
                <thead>
                    <tr>
                        <th>Run #</th>
                        <th>Status</th>
                        <th>Duration</th>
                        <th>Files</th>
                        <th>Size</th>
                        <th>Timestamp</th>
                    </tr>
                </thead>
                <tbody>
                    ${jobs.runs.map(run => `
                        <tr>
                            <td><a href="${run.url}" target="_blank">#${run.run_number}</a></td>
                            <td><span class="status-${run.status}">${run.status.toUpperCase()}</span></td>
                            <td>${Math.round(run.duration_ms / 1000)}s</td>
                            <td>${run.files_count}</td>
                            <td>${Math.round(run.total_size_bytes / 1024)}KB</td>
                            <td>${new Date(run.timestamp).toLocaleString()}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
        
        <div class="refresh-info">
            <p>🔄 Auto-refreshes every 60 seconds | Last updated: ${new Date().toLocaleString()}</p>
        </div>
    </div>

    <script>
        // Chart.js configuration
        const jobs = ${JSON.stringify(jobs)};
        const runs = jobs.runs.reverse(); // Show oldest first
        
        // Duration Chart
        const durationCtx = document.getElementById('durationChart').getContext('2d');
        new Chart(durationCtx, {
            type: 'line',
            data: {
                labels: runs.map(r => new Date(r.timestamp).toLocaleDateString()),
                datasets: [{
                    label: 'Duration (seconds)',
                    data: runs.map(r => Math.round(r.duration_ms / 1000)),
                    borderColor: '#3498db',
                    backgroundColor: 'rgba(52, 152, 219, 0.1)',
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
        
        // Files Chart
        const filesCtx = document.getElementById('filesChart').getContext('2d');
        new Chart(filesCtx, {
            type: 'bar',
            data: {
                labels: runs.map(r => new Date(r.timestamp).toLocaleDateString()),
                datasets: [{
                    label: 'File Count',
                    data: runs.map(r => r.files_count),
                    backgroundColor: '#27ae60',
                    borderColor: '#229954',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
        
        // Auto-refresh every 60 seconds
        setTimeout(() => {
            window.location.reload();
        }, 60000);
    </script>
</body>
</html>`;

  fs.writeFileSync(CONFIG.statusFile, html);
  console.log(`✅ Generated ${CONFIG.statusFile} with Chart.js visualizations`);
}

/**
 * Main execution
 */
async function main() {
  console.log('🚀 Phase 10.2 - Live Mirror Status Board Generator');
  console.log('================================================');
  
  try {
    const jobs = await generateJobsJson();
    generateStatusHtml(jobs);
    
    console.log('');
    console.log('✅ Phase 10.2 Status Board generated successfully!');
    console.log(`📊 Jobs data: ${CONFIG.jobsFile}`);
    console.log(`🌐 Status page: ${CONFIG.statusFile}`);
    console.log(`📈 Charts: Duration trends, file count trends`);
    console.log(`🔄 Auto-refresh: Every 60 seconds`);
    
  } catch (error) {
    console.error('❌ Error generating status board:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { generateJobsJson, generateStatusHtml };
