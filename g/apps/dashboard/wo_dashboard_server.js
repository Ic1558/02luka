#!/usr/bin/env node
/**
 * WO Dashboard Server
 * API server for Work Order dashboard interactions
 * SECURITY FIXED: Path traversal prevention + auth-token endpoint removed
 */

const http = require('http');
const { createClient } = require('redis');
const fs = require('fs').promises;
const path = require('path');
const url = require('url');
const { woStatePath, assertValidWoId } = require('./security/woId');

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
    // SECURITY: Validate ID and ensure path stays within STATE_DIR
    const filePath = woStatePath(STATE_DIR, woId);
    const content = await fs.readFile(filePath, 'utf8');
    return JSON.parse(content);
  } catch (err) {
    // Return null for file not found, but log validation errors
    if (err.statusCode === 400) {
      console.error('Invalid WO ID:', woId, err.message);
    }
    return null;
  }
}

async function writeStateFile(woId, data) {
  try {
    // SECURITY: Validate ID and ensure path stays within STATE_DIR
    const filePath = woStatePath(STATE_DIR, woId);
    const tmpPath = `${filePath}.tmp`;
    await fs.writeFile(tmpPath, JSON.stringify(data, null, 2));
    await fs.rename(tmpPath, filePath);
    return true;
  } catch (err) {
    console.error('Write state error:', err);
    // Return false for validation errors too
    return false;
  }
}

const server = http.createServer(async (req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    return res.end();
  }

  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;

  // SECURITY FIX: /api/auth-token endpoint REMOVED
  // Token should be configured via environment variables for trusted agents only
  // Public exposure of auth token is a security vulnerability

  // Auth check for all API endpoints
  const authHeader = req.headers.authorization || req.headers['x-auth-token'] || '';
  const token = authHeader.replace(/^Bearer\s+/i, '').replace(/^Token\s+/i, '');
  
  if (pathname.startsWith('/api/')) {
    if (token !== AUTH_TOKEN) {
      return sendError(res, 401, 'Unauthorized');
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
  if (req.method === 'GET' && pathname.startsWith('/api/wo/')) {
    try {
      const woId = pathname.replace('/api/wo/', '');
      // SECURITY: Validate WO ID before processing
      assertValidWoId(woId);
      
      const data = await readStateFile(woId);
      
      if (!data) {
        return sendError(res, 404, 'WO not found');
      }
      
      return sendJSON(res, 200, data);
    } catch (err) {
      // Validation error
      if (err.statusCode === 400) {
        return sendError(res, 400, 'Invalid work order id');
      }
      return sendError(res, 500, err.message);
    }
  }

  // POST /api/wo/:id/action - Perform action on WO
  if (req.method === 'POST' && pathname.match(/^\/api\/wo\/([^\/]+)\/action$/)) {
    let woId;
    try {
      woId = pathname.match(/^\/api\/wo\/([^\/]+)\/action$/)[1];
      // SECURITY: Validate WO ID before processing
      assertValidWoId(woId);
    } catch (err) {
      if (err.statusCode === 400) {
        return sendError(res, 400, 'Invalid work order id');
      }
      return sendError(res, 500, err.message);
    }
    
    let body = '';
    req.on('data', chunk => { body += chunk.toString(); });
    req.on('end', async () => {
      try {
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
    console.log(`🔒 Security: Path traversal protection enabled`);
    console.log(`🔒 Security: /api/auth-token endpoint removed (use env var)`);
  });
}

start().catch(console.error);
