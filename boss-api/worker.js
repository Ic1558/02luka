/**
 * Cloudflare Worker - boss-api
 *
 * Provides:
 * - /healthz - Health check
 * - /api/discord/notify - Discord notifications
 * - /api/reports/summary - OPS summary (from GitHub)
 * - /api/reports/latest - Latest report (from GitHub)
 * - /api/reports/list - List reports (from GitHub)
 * - /api/capabilities - API capabilities
 *
 * Required environment variables:
 * - DISCORD_WEBHOOK_DEFAULT
 * - DISCORD_WEBHOOK_MAP (optional JSON)
 * - GITHUB_TOKEN (for reading reports)
 * - GITHUB_REPO (default: Ic1558/02luka)
 */

// GitHub configuration
const GITHUB_REPO = 'Ic1558/02luka';
const GITHUB_API_BASE = 'https://api.github.com';
const REPORTS_PATH = 'g/reports';

// Discord webhook relay
async function postDiscordWebhook(webhookUrl, payload) {
  const response = await fetch(webhookUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': '02luka-boss-api/1.0'
    },
    body: JSON.stringify(payload)
  });

  if (!response.ok) {
    const error = new Error(`Discord webhook returned ${response.status}`);
    error.statusCode = response.status;
    const text = await response.text();
    try {
      const json = JSON.parse(text);
      error.message = `Discord webhook returned ${response.status}: ${JSON.stringify(json)}`;
    } catch {
      error.message = `Discord webhook returned ${response.status}`;
    }
    throw error;
  }

  return response;
}

// GitHub API helper
async function fetchGitHub(path, env) {
  const token = env.GITHUB_TOKEN;
  const url = `${GITHUB_API_BASE}/repos/${GITHUB_REPO}/contents/${path}`;

  const headers = {
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': '02luka-boss-api/1.0'
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const response = await fetch(url, { headers });

  if (!response.ok) {
    throw new Error(`GitHub API error: ${response.status}`);
  }

  return response.json();
}

// Decode base64 content from GitHub
function decodeGitHubContent(content) {
  // GitHub returns content in base64
  const decoded = atob(content.replace(/\n/g, ''));
  return decoded;
}

// JSON response helper
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'public, max-age=60'
    }
  });
}

// Error response helper
function errorResponse(message, status = 500) {
  return jsonResponse({ error: message }, status);
}

// Normalize Discord level
function normalizeLevel(rawLevel) {
  const normalized = typeof rawLevel === 'string' ? rawLevel.trim().toLowerCase() : '';
  if (normalized === 'warn' || normalized === 'warning') return 'warn';
  if (normalized === 'error' || normalized === 'err' || normalized === 'fatal') return 'error';
  return 'info';
}

// Resolve Discord webhook
function resolveDiscordWebhook(env, channelName) {
  const normalized = typeof channelName === 'string' && channelName.trim() ? channelName.trim() : 'default';

  // Try DISCORD_WEBHOOK_MAP first
  if (env.DISCORD_WEBHOOK_MAP) {
    try {
      const map = JSON.parse(env.DISCORD_WEBHOOK_MAP);
      if (map[normalized]) return map[normalized];
      if (normalized !== 'default' && map.default) return map.default;
    } catch (e) {
      console.error('Failed to parse DISCORD_WEBHOOK_MAP:', e);
    }
  }

  // Fallback to DISCORD_WEBHOOK_DEFAULT
  return env.DISCORD_WEBHOOK_DEFAULT || '';
}

// Format Discord payload
function formatDiscordPayload(level, content) {
  const trimmedContent = typeof content === 'string' ? content.trim() : '';
  const levelEmojis = {
    info: 'ℹ️',
    warn: '⚠️',
    error: '🚨'
  };

  const prefix = levelEmojis[level] || '';
  const finalContent = prefix ? `${prefix} ${trimmedContent}` : trimmedContent;

  return {
    content: finalContent,
    allowed_mentions: { parse: [] }
  };
}

// Rate limiting
const rateLimitMap = new Map();
const RATE_LIMIT_WINDOW = 60000;
const RATE_LIMIT_MAX = 100;

function checkRateLimit(ip) {
  const now = Date.now();
  const windowStart = now - RATE_LIMIT_WINDOW;

  if (!rateLimitMap.has(ip)) {
    rateLimitMap.set(ip, []);
  }

  const requests = rateLimitMap.get(ip).filter(time => time > windowStart);

  if (requests.length >= RATE_LIMIT_MAX) {
    return false;
  }

  requests.push(now);
  rateLimitMap.set(ip, requests);
  return true;
}

// Main request handler
async function handleRequest(request, env) {
  const url = new URL(request.url);
  const path = url.pathname;
  const ip = request.headers.get('CF-Connecting-IP') || 'unknown';

  // Rate limiting
  if (!checkRateLimit(ip)) {
    return errorResponse('Rate limit exceeded', 429);
  }

  // CORS preflight
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      }
    });
  }

  // Health check
  if (path === '/healthz') {
    return jsonResponse({
      status: 'ok',
      timestamp: new Date().toISOString(),
      worker: 'boss-api-cloudflare'
    });
  }

  // API capabilities
  if (path === '/api/capabilities') {
    return jsonResponse({
      ui: {
        inbox: false,
        preview: false,
        prompt_composer: false,
        connectors: false
      },
      features: {
        discord: true,
        reports: true,
        github: true
      },
      endpoints: {
        healthz: true,
        discord_notify: true,
        reports_summary: true,
        reports_latest: true,
        reports_list: true
      }
    });
  }

  // Discord notification
  if (path === '/api/discord/notify' && request.method === 'POST') {
    try {
      const body = await request.json();
      const rawContent = body.content;

      if (!rawContent || typeof rawContent !== 'string' || !rawContent.trim()) {
        return errorResponse('content is required', 400);
      }

      const level = normalizeLevel(body.level);
      const channel = typeof body.channel === 'string' ? body.channel.trim() : 'default';
      const webhookUrl = resolveDiscordWebhook(env, channel);

      if (!webhookUrl) {
        return errorResponse('Discord webhook is not configured', 503);
      }

      const payload = formatDiscordPayload(level, rawContent);

      try {
        await postDiscordWebhook(webhookUrl, payload);
      } catch (error) {
        console.error('Failed to deliver Discord notification:', error.message);
        return errorResponse('Failed to send Discord notification', 502);
      }

      return jsonResponse({ ok: true });
    } catch (error) {
      return errorResponse('Unexpected error while processing request', 500);
    }
  }

  // Reports summary (from GitHub)
  if (path === '/api/reports/summary') {
    try {
      const data = await fetchGitHub(`${REPORTS_PATH}/OPS_SUMMARY.json`, env);
      const content = decodeGitHubContent(data.content);
      const summary = JSON.parse(content);
      return jsonResponse(summary);
    } catch (error) {
      console.error('Failed to fetch summary:', error);
      // Return graceful fallback
      return jsonResponse({
        status: 'unknown',
        note: 'summary_not_available',
        hint: 'OPS_SUMMARY.json not found in repository'
      });
    }
  }

  // Reports list (from GitHub)
  if (path === '/api/reports/list') {
    try {
      const data = await fetchGitHub(REPORTS_PATH, env);

      if (!Array.isArray(data)) {
        return errorResponse('Invalid response from GitHub', 500);
      }

      const files = data
        .filter(item => item.type === 'file' && /^OPS_ATOMIC_\d+_\d+\.md$/.test(item.name))
        .map(item => item.name)
        .sort()
        .reverse()
        .slice(0, 20);

      return jsonResponse({ files });
    } catch (error) {
      console.error('Failed to list reports:', error);
      return jsonResponse({ files: [] });
    }
  }

  // Latest report (from GitHub)
  if (path === '/api/reports/latest') {
    try {
      const data = await fetchGitHub(REPORTS_PATH, env);

      if (!Array.isArray(data)) {
        return errorResponse('Invalid response from GitHub', 500);
      }

      const files = data
        .filter(item => item.type === 'file' && /^OPS_ATOMIC_\d+_\d+\.md$/.test(item.name))
        .map(item => item.name)
        .sort()
        .reverse();

      if (files.length === 0) {
        return errorResponse('No reports found', 404);
      }

      const latestFile = files[0];
      const fileData = await fetchGitHub(`${REPORTS_PATH}/${latestFile}`, env);
      const content = decodeGitHubContent(fileData.content);

      return new Response(content, {
        headers: {
          'Content-Type': 'text/markdown; charset=utf-8',
          'Access-Control-Allow-Origin': '*'
        }
      });
    } catch (error) {
      console.error('Failed to fetch latest report:', error);
      return errorResponse('Failed to read latest report', 500);
    }
  }

  // 404 for unknown routes
  return errorResponse('Not found', 404);
}

// Cloudflare Workers export
export default {
  async fetch(request, env, ctx) {
    try {
      return await handleRequest(request, env);
    } catch (error) {
      console.error('Unhandled error:', error);
      return errorResponse('Internal server error', 500);
    }
  }
};
