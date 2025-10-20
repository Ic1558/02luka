#!/usr/bin/env node
/**
 * Phase 7.2: HTTP Skill Wrapper
 * Safe HTTP requests (curl-like for local use)
 *
 * Usage:
 *   http.cjs GET <url>
 *   http.cjs POST <url> [json-data]
 *   http.cjs PUT <url> [json-data]
 *   http.cjs DELETE <url>
 *
 * For internal/localhost use only
 * Blocks requests to external domains by default
 */

const https = require('https');
const http = require('http');
const { URL } = require('url');

// Parse arguments
const [method, urlString, data] = process.argv.slice(2);

if (!method || !urlString) {
  console.error('Usage: http.cjs <METHOD> <url> [json-data]');
  process.exit(1);
}

// Parse URL
let url;
try {
  url = new URL(urlString);
} catch (error) {
  console.error('Invalid URL:', urlString);
  process.exit(1);
}

// Safety check: Only allow localhost and specific trusted domains
const ALLOWED_HOSTS = [
  'localhost',
  '127.0.0.1',
  '::1',
  'boss-api.ittipong-c.workers.dev' // Our Cloudflare Worker
];

const isAllowed = ALLOWED_HOSTS.some(host =>
  url.hostname === host || url.hostname.endsWith(`.${host}`)
);

if (!isAllowed) {
  console.error('❌ Blocked: Only localhost and trusted domains allowed');
  console.error('Attempted:', url.hostname);
  console.error('Allowed:', ALLOWED_HOSTS.join(', '));
  process.exit(113);
}

// Select protocol module
const client = url.protocol === 'https:' ? https : http;

// Build request options
const options = {
  method: method.toUpperCase(),
  hostname: url.hostname,
  port: url.port,
  path: url.pathname + url.search,
  headers: {
    'User-Agent': '02luka-local-orchestrator/1.0',
    'Accept': 'application/json'
  }
};

// Add content type for POST/PUT
if (data && (options.method === 'POST' || options.method === 'PUT')) {
  options.headers['Content-Type'] = 'application/json';
  options.headers['Content-Length'] = Buffer.byteLength(data);
}

// Make request
const req = client.request(options, (res) => {
  let body = '';

  res.on('data', (chunk) => {
    body += chunk;
  });

  res.on('end', () => {
    // Output response
    console.log(`Status: ${res.statusCode}`);
    console.log(`Headers: ${JSON.stringify(res.headers)}`);
    console.log('Body:', body);

    // Exit code based on status
    if (res.statusCode >= 200 && res.statusCode < 300) {
      process.exit(0);
    } else {
      process.exit(1);
    }
  });
});

req.on('error', (error) => {
  console.error('Request failed:', error.message);
  process.exit(1);
});

// Set timeout
req.setTimeout(30000, () => {
  console.error('Request timeout');
  req.destroy();
  process.exit(1);
});

// Send data if provided
if (data) {
  req.write(data);
}

req.end();
