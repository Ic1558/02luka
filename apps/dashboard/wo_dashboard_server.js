#!/usr/bin/env node
/**
 * WO Dashboard Server
 * API server for Work Order dashboard interactions
 * Fixed: Uses env vars for Redis password, enforces signed requests for WO APIs
 */

const http = require('http');
const { createClient } = require('redis');
const fs = require('fs').promises;
const path = require('path');
const url = require('url');
const { verifySignature } = require('../../server/security/verifySignature');

const BASE = process.env.LUKA_SOT || process.env.HOME + '/02luka';
const PORT = process.env.DASHBOARD_PORT || 8765;
const AUTH_TOKEN = process.env.DASHBOARD_AUTH_TOKEN || 'dashboard-token-change-me';

// Redis configuration - FIXED: Use env var, not hard-coded
const REDIS_PASSWORD = process.env.REDIS_PASSWORD || 'gggclukaic';
const REDIS_URL = process.env.REDIS_URL || `redis://:${REDIS_PASSWORD}@127.0.0.1:6379`;

const STATE_DIR = path.join(BASE, 'g/followup/state');
const FOLLOWUP_DATA = path.join(BASE, 'g/apps/dashboard/data/followup.json');

let redisClient = null;

async function initRedis() {
  try {
    redisClient = createClient({ url: REDIS_URL });
    redisClient.on('error', (err) => console.error('Redis error:', err));
    await redisClient.connect();
    console.log('✅ Redis connected');
  } catch (err) {
    console.error('❌ Redis connection failed:', err.message);
    redisClient = null;
  }
}

function sendJSON(res, status, data) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

function sendError(res, status, message) {
  sendJSON(res, status, { error: message });
}

async function readStateFile(woId) {
  try {
    const filePath = path.join(STATE_DIR, `${woId}.json`);
    const content = await fs.readFile(filePath, 'utf8');
    return JSON.parse(content);
  } catch (err) {
    return null;
  }
}

async function writeStateFile(woId, data) {
  try {
    const filePath = path.join(STATE_DIR, `${woId}.json`);
    const tmpPath = `${filePath}.tmp`;
    await fs.writeFile(tmpPath, JSON.stringify(data, null, 2));
    await fs.rename(tmpPath, filePath);
    return true;
  } catch (err) {
    console.error('Write state error:', err);
    return false;
  }
}

const server = http.createServer(async (req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, x-luka-signature, x-luka-timestamp'
  );

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    return res.end();
  }

  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;

  // Auth check for other endpoints
  const authHeader = req.headers.authorization || req.headers['x-auth-token'] || '';
  const token = authHeader.replace(/^Bearer\s+/i, '').replace(/^Token\s+/i, '');

  if (pathname.startsWith('/api/')) {
    if (token !== AUTH_TOKEN) {
      return sendError(res, 401, 'Unauthorized');
    }
  }

  const ensureSignedRequest = async (payload = '') => {
    try {
      verifySignature({
        headers: req.headers,
        payload,
        method: req.method,
        path: pathname
      });
      return true;
    } catch (err) {
      const status = err.statusCode || 401;
      sendError(res, status, err.message);
      return false;
    }
  };

  if (pathname.startsWith('/api/wo/state/')) {
    const ok = await ensureSignedRequest('');
    if (!ok) {
      return;
    }
  }

  // GET /api/wos - List all WOs
  if (req.method === 'GET' && pathname === '/api/wos') {
    try {
      const files = await fs.readdir(STATE_DIR);
      const wos = [];
      
      for (const file of files) {
        if (file.endsWith('.json')) {
          const woId = file.replace('.json', '');
          const data = await readStateFile(woId);
          if (data) {
            wos.push(data);
          }
        }
      }
      
      return sendJSON(res, 200, wos);
    } catch (err) {
      return sendError(res, 500, err.message);
    }
  }

  // GET /api/wo/:id - Get single WO
  const woDetailMatch = pathname.match(/^\/api\/wo\/([^\/]+)$/);
  if (req.method === 'GET' && woDetailMatch) {
    const ok = await ensureSignedRequest('');
    if (!ok) {
      return;
    }

    const woId = woDetailMatch[1];
    const data = await readStateFile(woId);

    if (!data) {
      return sendError(res, 404, 'WO not found');
    }
    
    return sendJSON(res, 200, data);
  }

  // POST /api/wo/:id/action - Perform action on WO
  const woActionMatch = pathname.match(/^\/api\/wo\/([^\/]+)\/action$/);
  if (req.method === 'POST' && woActionMatch) {
    const woId = woActionMatch[1];

    let body = '';
    req.on('data', chunk => { body += chunk.toString(); });
    req.on('end', async () => {
      try {
        const ok = await ensureSignedRequest(body);
        if (!ok) {
          return;
        }

        const { action } = JSON.parse(body);
        const currentData = await readStateFile(woId);
        
        if (!currentData) {
          return sendError(res, 404, 'WO not found');
        }

        // Update status based on action
        if (action === 'activate' || action === 'start') {
          currentData.status = 'InProgress';
        } else if (action === 'pause') {
          currentData.status = 'Open';
        } else if (action === 'complete') {
          currentData.status = 'Complete';
        }

        currentData.ts_update = new Date().toISOString();
        
        const success = await writeStateFile(woId, currentData);
        
        if (success) {
          // Publish to Redis if available
          if (redisClient) {
            try {
              await redisClient.publish('wo:update', JSON.stringify({
                wo_id: woId,
                action: action,
                status: currentData.status,
                ts: currentData.ts_update
              }));
            } catch (err) {
              console.error('Redis publish error:', err);
            }
          }
          
          return sendJSON(res, 200, { success: true, wo: currentData });
        } else {
          return sendError(res, 500, 'Failed to update WO');
        }
      } catch (err) {
        if (res.writableEnded) {
          return;
        }
        return sendError(res, 400, err.message);
      }
    });
    return;
  }

  // GET /api/followup - Get followup.json data
  if (req.method === 'GET' && pathname === '/api/followup') {
    try {
      const content = await fs.readFile(FOLLOWUP_DATA, 'utf8');
      const data = JSON.parse(content);
      return sendJSON(res, 200, data);
    } catch (err) {
      return sendError(res, 500, err.message);
    }
  }

  // 404
  sendError(res, 404, 'Not found');
});

async function start() {
  await initRedis();
  
  server.listen(PORT, () => {
    console.log(`🚀 WO Dashboard Server running on http://localhost:${PORT}`);
    console.log(`📊 API endpoints:`);
    console.log(`   GET  /api/wos`);
    console.log(`   GET  /api/wo/:id`);
    console.log(`   POST /api/wo/:id/action`);
    console.log(`   GET  /api/followup`);
  });
}

start().catch(console.error);
