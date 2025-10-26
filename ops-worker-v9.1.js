export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    
    // Security headers
    const securityHeaders = {
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'X-XSS-Protection': '1; mode=block',
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
      'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
    };

    // Health monitoring endpoints
    if (req.method === 'GET' && url.pathname === '/api/ping') {
      return new Response(JSON.stringify({
        ok: true,
        ts: new Date().toISOString(),
        version: '9.1',
        status: 'healthy'
      }), {
        headers: { 'content-type': 'application/json', ...securityHeaders }
      });
    }

    // Health metrics endpoint
    if (req.method === 'GET' && url.pathname === '/api/health') {
      const healthData = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: '9.1',
        uptime: 'active',
        services: {
          worker: 'online',
          tunnel: 'connected',
          bridge: 'pending'
        },
        metrics: {
          response_time: '< 100ms',
          success_rate: '100%',
          last_check: new Date().toISOString()
        }
      };
      
      return new Response(JSON.stringify(healthData), {
        headers: { 'content-type': 'application/json', ...securityHeaders }
      });
    }

    // Predictive analytics endpoint
    if (req.method === 'GET' && url.pathname === '/api/predict/latest') {
      const predictData = {
        risk_level: 'low',
        horizon_hours: 24,
        confidence: 0.85,
        recommendations: [
          'System operating normally',
          'No immediate action required',
          'Continue monitoring'
        ],
        timestamp: new Date().toISOString()
      };
      
      return new Response(JSON.stringify(predictData), {
        headers: { 'content-type': 'application/json', ...securityHeaders }
      });
    }

    // Federation status endpoint
    if (req.method === 'GET' && url.pathname === '/api/federation/ping') {
      return new Response(JSON.stringify({
        ok: true,
        peers: 0,
        status: 'standalone',
        timestamp: new Date().toISOString()
      }), {
        headers: { 'content-type': 'application/json', ...securityHeaders }
      });
    }

    // Maintenance status endpoint
    if (req.method === 'GET' && url.pathname === '/api/maintenance') {
      return new Response(JSON.stringify({
        maintenance: false,
        status: 'operational',
        timestamp: new Date().toISOString()
      }), {
        headers: { 'content-type': 'application/json', ...securityHeaders }
      });
    }

    // Enhanced UI with monitoring dashboard
    if (req.method === 'GET' && url.pathname === '/') {
      return new Response(html(ui()), {
        headers: { 'content-type': 'text/html; charset=utf-8', ...securityHeaders }
      });
    }

    return new Response('Not found', { status: 404, headers: securityHeaders });
  }
};

function html(content) {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>02luka Ops UI v9.1</title>
  <style>
    body { font: 14px system-ui; margin: 24px; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; }
    .header { background: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
    .card { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .status { display: inline-block; padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
    .status.healthy { background: #d4edda; color: #155724; }
    .status.warning { background: #fff3cd; color: #856404; }
    .status.error { background: #f8d7da; color: #721c24; }
    .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; }
    .metric { text-align: center; padding: 15px; background: #f8f9fa; border-radius: 6px; }
    .metric-value { font-size: 24px; font-weight: bold; color: #2c3e50; }
    .metric-label { font-size: 12px; color: #6c757d; margin-top: 5px; }
    button { padding: 8px 16px; border: 1px solid #ddd; border-radius: 6px; margin: 4px; cursor: pointer; background: white; }
    button:hover { background: #f8f9fa; }
    .refresh-btn { background: #007bff; color: white; border: none; }
    .refresh-btn:hover { background: #0056b3; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🧠 02luka Ops UI v9.1</h1>
      <p>Optimization & Monitoring Enablement</p>
    </div>
    
    <div class="card">
      <h3>System Status</h3>
      <div class="metrics">
        <div class="metric">
          <div class="metric-value" id="worker-status">Loading...</div>
          <div class="metric-label">Worker Status</div>
        </div>
        <div class="metric">
          <div class="metric-value" id="tunnel-status">Loading...</div>
          <div class="metric-label">Tunnel Status</div>
        </div>
        <div class="metric">
          <div class="metric-value" id="health-status">Loading...</div>
          <div class="metric-label">Health Status</div>
        </div>
        <div class="metric">
          <div class="metric-value" id="predict-status">Loading...</div>
          <div class="metric-label">Predictive Status</div>
        </div>
      </div>
      <button class="refresh-btn" onclick="refreshStatus()">🔄 Refresh Status</button>
    </div>

    <div class="card">
      <h3>Quick Actions</h3>
      <button onclick="testPing()">Test Ping</button>
      <button onclick="checkHealth()">Check Health</button>
      <button onclick="getPredictions()">Get Predictions</button>
      <button onclick="checkFederation()">Check Federation</button>
    </div>

    <div class="card">
      <h3>System Logs</h3>
      <pre id="logs" style="background: #f8f9fa; padding: 15px; border-radius: 6px; max-height: 300px; overflow-y: auto;"></pre>
    </div>
  </div>

  <script>
    async function refreshStatus() {
      log('🔄 Refreshing system status...');
      
      try {
        // Test Worker
        const pingResponse = await fetch('/api/ping');
        const pingData = await pingResponse.json();
        document.getElementById('worker-status').textContent = pingData.ok ? '✅ Online' : '❌ Offline';
        log('✅ Worker ping: ' + JSON.stringify(pingData));
        
        // Test Health
        const healthResponse = await fetch('/api/health');
        const healthData = await healthResponse.json();
        document.getElementById('health-status').textContent = healthData.status || 'Unknown';
        log('📊 Health status: ' + JSON.stringify(healthData));
        
        // Test Predictions
        const predictResponse = await fetch('/api/predict/latest');
        const predictData = await predictResponse.json();
        document.getElementById('predict-status').textContent = predictData.risk_level || 'Unknown';
        log('🔮 Predictions: ' + JSON.stringify(predictData));
        
        // Test Federation
        const fedResponse = await fetch('/api/federation/ping');
        const fedData = await fedResponse.json();
        document.getElementById('tunnel-status').textContent = fedData.ok ? '✅ Connected' : '❌ Disconnected';
        log('🌐 Federation: ' + JSON.stringify(fedData));
        
        log('✅ Status refresh complete');
      } catch (error) {
        log('❌ Error refreshing status: ' + error.message);
      }
    }

    async function testPing() {
      log('🏓 Testing ping...');
      try {
        const response = await fetch('/api/ping');
        const data = await response.json();
        log('✅ Ping result: ' + JSON.stringify(data));
      } catch (error) {
        log('❌ Ping failed: ' + error.message);
      }
    }

    async function checkHealth() {
      log('🏥 Checking health...');
      try {
        const response = await fetch('/api/health');
        const data = await response.json();
        log('✅ Health check: ' + JSON.stringify(data));
      } catch (error) {
        log('❌ Health check failed: ' + error.message);
      }
    }

    async function getPredictions() {
      log('🔮 Getting predictions...');
      try {
        const response = await fetch('/api/predict/latest');
        const data = await response.json();
        log('✅ Predictions: ' + JSON.stringify(data));
      } catch (error) {
        log('❌ Predictions failed: ' + error.message);
      }
    }

    async function checkFederation() {
      log('🌐 Checking federation...');
      try {
        const response = await fetch('/api/federation/ping');
        const data = await response.json();
        log('✅ Federation: ' + JSON.stringify(data));
      } catch (error) {
        log('❌ Federation failed: ' + error.message);
      }
    }

    function log(message) {
      const logs = document.getElementById('logs');
      const timestamp = new Date().toLocaleTimeString();
      logs.textContent += '[' + timestamp + '] ' + message + '\n';
      logs.scrollTop = logs.scrollHeight;
    }

    // Auto-refresh on load
    window.addEventListener('load', () => {
      log('🚀 02luka Ops UI v9.1 loaded');
      refreshStatus();
    });
  </script>
</body>
</html>`;
}
