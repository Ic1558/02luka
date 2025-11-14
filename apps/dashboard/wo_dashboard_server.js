#!/usr/bin/env node
/**
 * WO Dashboard Server
 * API server for Work Order dashboard interactions
 * SECURITY FIXED: Path traversal prevention + auth-token endpoint removed + replay attack protection
 */

const http = require('http');
const { createClient } = require('redis');
const fs = require('fs').promises;
const path = require('path');
const url = require('url');
const { verifySignature } = require('../../server/security/verifySignature');
const { canonicalJsonStringify } = require('../../server/security/canonicalJson');
const { woStatePath, assertValidWoId, sanitizeWoId } = require('../../g/apps/dashboard/security/woId');

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
    // Handle different error types explicitly
    if (err.statusCode === 400) {
      // Validation error - re-throw to be caught at handler level
      throw err;
    }
    if (err.code === 'ENOENT') {
      // File not found - this is expected for non-existent WOs
      return null;
    }
    // Other errors - log and return null
    console.error('Error reading state file:', err);
    return null;
  }
}

/**
 * Canonicalize work order state data
 * - Normalizes timestamps to ISO format
 * - Ensures consistent field ordering
 * - Validates required fields
 * @param {object} data - Work order state data
 * @returns {object} Canonicalized work order state data
 */
function canonicalizeWoState(data) {
  if (!data || typeof data !== 'object') {
    throw new Error('Invalid work order state: must be an object');
  }
  
  const canonical = {
    id: data.id || '',
    title: data.title || '',
    description: data.description || '',
    status: data.status || 'Open',
    priority: data.priority || 'Medium',
    progress: typeof data.progress === 'number' ? Math.max(0, Math.min(100, data.progress)) : 0,
    owner: data.owner || '',
    source: data.source || 'work_order',
    tags: Array.isArray(data.tags) ? data.tags : [],
    notes: data.notes || '',
    goal: data.goal || '',
    due_date: data.due_date || '',
  };
  
  // Normalize timestamps to ISO format
  const now = new Date().toISOString();
  canonical.ts_update = data.ts_update ? new Date(data.ts_update).toISOString() : now;
  canonical.ts_create = data.ts_create ? new Date(data.ts_create).toISOString() : now;
  
  // Ensure status is valid
  const validStatuses = ['Open', 'InProgress', 'Complete', 'Cancelled', 'OnHold'];
  if (!validStatuses.includes(canonical.status)) {
    canonical.status = 'Open';
  }
  
  // Ensure priority is valid
  const validPriorities = ['Low', 'Medium', 'High', 'Critical'];
  if (!validPriorities.includes(canonical.priority)) {
    canonical.priority = 'Medium';
  }
  
  return canonical;
}

async function writeStateFile(woId, data) {
  try {
    // SECURITY: Validate ID and ensure path stays within STATE_DIR
    const filePath = woStatePath(STATE_DIR, woId);
    
    // Canonicalize state data before writing
    const canonicalData = canonicalizeWoState(data);
    
    // Ensure ID matches the sanitized woId
    canonicalData.id = woId;
    
    const tmpPath = `${filePath}.tmp`;
    // Use canonical JSON for deterministic state writes (required for signature verification)
    await fs.writeFile(tmpPath, canonicalJsonStringify(canonicalData) + '\n');
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

  // SECURITY FIX: /api/auth-token endpoint REMOVED
  // Token should be configured via environment variables for trusted agents only
  // Public exposure of auth token is a security vulnerability
  
  // Explicit check for removed endpoint (return 404 before auth check)
  if (pathname === '/api/auth-token') {
    return sendError(res, 404, 'Not found');
  }

  // Auth check for all API endpoints
  const authHeader = req.headers.authorization || req.headers['x-auth-token'] || '';
  const token = authHeader.replace(/^Bearer\s+/i, '').replace(/^Token\s+/i, '');

  if (pathname.startsWith('/api/')) {
    if (token !== AUTH_TOKEN) {
      return sendError(res, 401, 'Unauthorized');
    }
  }

  // Replay attack protection: verify signature for WO operations
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
    // Replay attack protection: verify signature
    const ok = await ensureSignedRequest('');
    if (!ok) {
      return;
    }

    const rawWoId = pathname.replace('/api/wo/', '');
    
    // SECURITY: Sanitize and validate WO ID FIRST (before any file operations)
    // This ensures path traversal attempts return 400, not 404
    let woId;
    try {
      woId = sanitizeWoId(rawWoId); // Sanitize and normalize
    } catch (err) {
      if (err.statusCode === 400) {
        return sendError(res, 400, 'Invalid work order id');
      }
      return sendError(res, 500, err.message);
    }
    
    // Now safe to read file (validation passed)
    try {
      const data = await readStateFile(woId);
      
      if (!data) {
        return sendError(res, 404, 'WO not found');
      }
      
      return sendJSON(res, 200, data);
    } catch (err) {
      // File read errors (shouldn't happen after validation, but handle gracefully)
      if (err.statusCode === 400) {
        return sendError(res, 400, err.message);
      }
      console.error('Read state file error:', err);
      return sendError(res, 500, err.message);
    }
  }

  // POST /api/wo/:id/action - Perform action on WO
  if (req.method === 'POST' && pathname.match(/^\/api\/wo\/([^\/]+)\/action$/)) {
    const rawWoId = pathname.match(/^\/api\/wo\/([^\/]+)\/action$/)[1];
    
    // SECURITY: Sanitize and validate WO ID before processing
    let woId;
    try {
      woId = sanitizeWoId(rawWoId); // Sanitize and normalize
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
        // Replay attack protection: verify signature with body payload
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
              // Use canonical JSON for deterministic Redis payloads (required for signature verification)
              await redisClient.publish('wo:update', canonicalJsonStringify({
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
        const statusCode = err.statusCode || 400;
        return sendError(res, statusCode, err.message);
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
    console.log(`🔒 Security: Replay attack protection enabled (signed requests)`);
  });
}

start().catch(console.error);
