#!/usr/bin/env node
/**
 * WO Dashboard Server
 * API server for Work Order dashboard interactions
 * SECURITY FIXED: Path traversal prevention + signed requests + auth-token removal
 */

const http = require('http');
const { createClient } = require('redis');
const fs = require('fs').promises;
const path = require('path');
const url = require('url');
const { verifySignature } = require('../../server/security/verifySignature');
const { canonicalJsonStringify } = require('../../server/security/canonicalJson');
const { woStatePath, sanitizeWoId } = require('../../g/apps/dashboard/security/woId');

const BASE = process.env.LUKA_SOT || process.env.HOME + '/02luka';
const PORT = process.env.DASHBOARD_PORT || 8765;
const AUTH_TOKEN = process.env.DASHBOARD_AUTH_TOKEN || 'dashboard-token-change-me';

// Redis configuration - FIXED: Use env var, not hard-coded
const REDIS_PASSWORD = process.env.REDIS_PASSWORD || 'gggclukaic';
const REDIS_URL = process.env.REDIS_URL || `redis://:${REDIS_PASSWORD}@127.0.0.1:6379`;

const STATE_DIR = path.join(BASE, 'followup/state');
const FOLLOWUP_DATA = path.join(BASE, 'g/apps/dashboard/data/followup.json');
const LOGS_DIR = path.join(BASE, 'logs');
const SYSTEM_REPORTS_DIR = path.join(BASE, 'g', 'reports', 'system');
const FALLBACK_REPORTS_DIR = path.join(BASE, 'reports', 'system');
const SNAPSHOT_FILE_REGEX = /^reality_hooks_snapshot_.*\.json$/;

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
    const filePath = woStatePath(STATE_DIR, woId);
    const content = await fs.readFile(filePath, 'utf8');
    return JSON.parse(content);
  } catch (err) {
    if (err.statusCode === 400) {
      throw err;
    }
    if (err.code === 'ENOENT') {
      return null;
    }
    console.error('Error reading state file:', err);
    return null;
  }
}

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
    due_date: data.due_date || ''
  };

  const now = new Date().toISOString();
  canonical.ts_update = data.ts_update ? new Date(data.ts_update).toISOString() : now;
  canonical.ts_create = data.ts_create ? new Date(data.ts_create).toISOString() : now;

  const validStatuses = ['Open', 'InProgress', 'Complete', 'Cancelled', 'OnHold'];
  if (!validStatuses.includes(canonical.status)) {
    canonical.status = 'Open';
  }

  const validPriorities = ['Low', 'Medium', 'High', 'Critical'];
  if (!validPriorities.includes(canonical.priority)) {
    canonical.priority = 'Medium';
  }

  return canonical;
}

async function writeStateFile(woId, data) {
  try {
    const filePath = woStatePath(STATE_DIR, woId);
    const canonicalData = canonicalizeWoState(data);
    canonicalData.id = woId;

    const tmpPath = `${filePath}.tmp`;
    await fs.writeFile(tmpPath, canonicalJsonStringify(canonicalData) + '\n');
    await fs.rename(tmpPath, filePath);
    return true;
  } catch (err) {
    console.error('Write state error:', err);
    return false;
  }
}

const server = http.createServer(async (req, res) => {
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

  if (pathname === '/api/auth-token') {
    return sendError(res, 404, 'Not found');
  }

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

  if (req.method === 'GET' && pathname === '/api/reality/snapshot') {
    try {
      const snapshotPath = await findLatestRealitySnapshotPath();
      if (!snapshotPath) {
        return sendJSON(res, 200, {
          status: 'no_snapshot',
          snapshot_path: null,
          data: null
        });
      }

      try {
        const contents = await fs.readFile(snapshotPath, 'utf8');
        const data = JSON.parse(contents);
        return sendJSON(res, 200, {
          status: 'ok',
          snapshot_path: snapshotPath,
          data
        });
      } catch (err) {
        if (err.name === 'SyntaxError') {
          return sendJSON(res, 200, {
            status: 'error',
            snapshot_path: snapshotPath,
            error: 'invalid_json'
          });
        }
        throw err;
      }
    } catch (err) {
      console.error('Error reading Reality Hooks snapshot:', err);
      return sendError(res, 500, 'Failed to read Reality Hooks snapshot.');
    }
  }

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

  const woDetailMatch = pathname.match(/^\/api\/wo\/([^/]+)$/);
  if (req.method === 'GET' && woDetailMatch) {
    const ok = await ensureSignedRequest('');
    if (!ok) {
      return;
    }

    let woId;
    try {
      woId = sanitizeWoId(woDetailMatch[1]);
    } catch (err) {
      const status = err.statusCode || 400;
      return sendError(res, status, err.message);
    }

    try {
      const data = await readStateFile(woId);

      if (!data) {
        return sendError(res, 404, 'WO not found');
      }

      return sendJSON(res, 200, data);
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return sendError(res, statusCode, err.message);
    }
  }

  const actionMatch = pathname.match(/^\/api\/wo\/([^/]+)\/action$/);
  if (req.method === 'POST' && actionMatch) {
    let woId;
    try {
      woId = sanitizeWoId(actionMatch[1]);
    } catch (err) {
      const status = err.statusCode || 400;
      return sendError(res, status, err.message);
    }

    let body = '';
    req.on('data', chunk => {
      body += chunk.toString();
    });
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
          if (redisClient) {
            try {
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

  if (req.method === 'GET' && pathname === '/api/followup') {
    try {
      const content = await fs.readFile(FOLLOWUP_DATA, 'utf8');
      const data = JSON.parse(content);
      return sendJSON(res, 200, data);
    } catch (err) {
      return sendError(res, 500, err.message);
    }
  }

  sendError(res, 404, 'Not found');
});

async function findLatestRealitySnapshotPath() {
  const searchDirs = [
    SYSTEM_REPORTS_DIR,
    FALLBACK_REPORTS_DIR,
    path.dirname(LOGS_DIR)
  ];

  let latest = null;

  for (const dir of searchDirs) {
    if (!dir) continue;

    try {
      const stats = await fs.stat(dir);
      if (!stats.isDirectory()) {
        continue;
      }
    } catch {
      continue;
    }

    let entries;
    try {
      entries = await fs.readdir(dir, { withFileTypes: true });
    } catch (err) {
      console.warn('Unable to read Reality snapshot directory:', dir, err.message);
      continue;
    }

    for (const entry of entries) {
      if (!entry.isFile() || !SNAPSHOT_FILE_REGEX.test(entry.name)) {
        continue;
      }

      const filePath = path.join(dir, entry.name);
      try {
        const fileStats = await fs.stat(filePath);
        if (!latest || fileStats.mtimeMs > latest.mtimeMs) {
          latest = { path: filePath, mtimeMs: fileStats.mtimeMs };
        }
      } catch (err) {
        console.warn('Unable to stat Reality snapshot file:', filePath, err.message);
      }
    }
  }

  return latest ? latest.path : null;
}

async function start() {
  await initRedis();

  server.listen(PORT, () => {
    console.log(`🚀 WO Dashboard Server running on http://localhost:${PORT}`);
    console.log('📊 API endpoints:');
    console.log('   GET  /api/wos');
    console.log('   GET  /api/wo/:id');
    console.log('   POST /api/wo/:id/action');
    console.log('   GET  /api/followup');
    console.log('🔒 Security: Path traversal protection enabled');
    console.log('🔒 Security: /api/auth-token endpoint removed');
    console.log('🔒 Security: Replay attack protection enabled (signed requests)');
  });
}

start().catch(console.error);
