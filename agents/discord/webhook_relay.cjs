const https = require('https');
const { URL } = require('url');

const DEFAULT_TIMEOUT_MS = 10_000;

function normalizeUrl(rawUrl) {
  if (!rawUrl || typeof rawUrl !== 'string') {
    throw new Error('Discord webhook URL is required');
  }

  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch (error) {
    throw new Error('Invalid Discord webhook URL');
  }

  if (parsed.protocol !== 'https:') {
    throw new Error('Discord webhook URL must use https');
  }

  return parsed;
}

function buildRequestOptions(parsedUrl, serializedPayload) {
  const headers = {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(serializedPayload)
  };

  const options = {
    method: 'POST',
    hostname: parsedUrl.hostname,
    path: `${parsedUrl.pathname}${parsedUrl.search}`,
    headers
  };

  if (parsedUrl.port) {
    options.port = parsedUrl.port;
  }

  return options;
}

function postDiscordWebhook(webhookUrl, payload = {}) {
  const parsedUrl = normalizeUrl(webhookUrl);
  const serialized = JSON.stringify(payload || {});
  const options = buildRequestOptions(parsedUrl, serialized);

  return new Promise((resolve, reject) => {
    const request = https.request(options, response => {
      const statusCode = response.statusCode || 0;
      const chunks = [];

      response.on('data', chunk => chunks.push(chunk));
      response.on('end', () => {
        const bodyBuffer = Buffer.concat(chunks);
        const bodyText = bodyBuffer.toString('utf8');

        if (statusCode >= 200 && statusCode < 300) {
          resolve({ statusCode, body: bodyText });
        } else {
          const error = new Error('Discord webhook returned a non-success status');
          error.statusCode = statusCode;
          error.body = bodyText;
          reject(error);
        }
      });
    });

    request.setTimeout(DEFAULT_TIMEOUT_MS, () => {
      request.destroy(new Error('Discord webhook request timed out'));
    });

    request.on('error', reject);

    request.write(serialized);
    request.end();
  });
}

module.exports = {
  postDiscordWebhook
};
