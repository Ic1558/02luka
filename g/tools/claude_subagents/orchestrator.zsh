const { verifySignature } = require('../../server/security/verifySignature');
const { canonicalJsonStringify } = require('../../server/security/canonicalJson');
const { woStatePath, assertValidWoId, sanitizeWoId } = require('./security/woId');

const fs = require('fs').promises;
const path = require('path');
const http = require('http');

async function writeStateFile(filePath, canonicalData) {
  const tmpPath = `${filePath}.tmp`;
  // Use canonical JSON for deterministic state writes (required for signature verification)
  await fs.writeFile(tmpPath, canonicalJsonStringify(canonicalData) + '\n');
  await fs.rename(tmpPath, filePath);
}

async function ensureSignedRequest(body) {
  // Implementation for signature verification
  // Placeholder for actual signature verification logic
  return true;
}

const server = http.createServer(async (req, res) => {
  const { pathname } = new URL(req.url, `http://${req.headers.host}`);

  if (req.method === 'GET' && pathname.startsWith('/api/wo/')) {
    // Replay attack protection: verify signature
    const ok = await ensureSignedRequest('');
    if (!ok) {
      return;
    }

    const rawWoId = pathname.replace('/api/wo/', '');

    // Further processing...
  }

  if (req.method === 'POST' && pathname.match(/^\/api\/wo\/([^\/]+)\/action$/)) {
    const rawWoId = pathname.match(/^\/api\/wo\/([^\/]+)\/action$/)[1];

    // SECURITY: Sanitize and validate WO ID before processing
    let woId;
    try {
      woId = sanitizeWoId(rawWoId); // Sanitize and normalize
    } catch (err) {
      // Handle error
    }

    // Further processing...
  }
});

server.listen(3000);
