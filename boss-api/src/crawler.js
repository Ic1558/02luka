import { URL } from 'node:url';
import { setTimeout as setNodeTimeout, clearTimeout as clearNodeTimeout } from 'node:timers';

const DEFAULT_FETCH_TIMEOUT_MS = 15000;

function isHtmlContentType(contentType = '') {
  if (!contentType) {
    return false;
  }
  return /text\/(html|xml)|application\/xhtml\+xml/i.test(contentType);
}

function stripScriptsAndStyles(html) {
  return html
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, ' ');
}

function decodeBasicEntities(text) {
  if (!text) {
    return text;
  }
  return text
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'");
}

function htmlToText(html) {
  if (!html) {
    return '';
  }
  const withoutTags = html.replace(/<[^>]+>/g, ' ');
  return decodeBasicEntities(withoutTags)
    .replace(/\s+/g, ' ')
    .trim();
}

function extractTitle(html) {
  if (!html) {
    return '';
  }
  const match = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  if (!match) {
    return '';
  }
  return decodeBasicEntities(match[1]).replace(/\s+/g, ' ').trim();
}

function extractLinks(html, baseUrl) {
  if (!html) {
    return [];
  }
  const hrefRegex = /href\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/gi;
  const results = new Set();
  let match;
  while ((match = hrefRegex.exec(html)) !== null) {
    const candidate = match[1] || match[2] || match[3] || '';
    const normalized = normalizeUrl(candidate, baseUrl);
    if (!normalized) {
      continue;
    }
    results.add(normalized);
  }
  return Array.from(results);
}

function normalizeUrl(value, baseUrl) {
  if (typeof value !== 'string' || !value.trim()) {
    return null;
  }
  try {
    const url = baseUrl ? new URL(value, baseUrl) : new URL(value);
    if (!/^https?:$/i.test(url.protocol)) {
      return null;
    }
    url.hash = '';
    return url.toString();
  } catch {
    return null;
  }
}

function getHostname(url) {
  try {
    return new URL(url).hostname.toLowerCase();
  } catch {
    return null;
  }
}

export function allowlistHasHost(host, allowlist) {
  if (!host || !allowlist || allowlist.size === 0) {
    return false;
  }
  const lowerHost = host.toLowerCase();
  for (const domain of allowlist) {
    if (!domain) {
      continue;
    }
    const trimmed = domain.toLowerCase();
    if (lowerHost === trimmed || lowerHost.endsWith(`.${trimmed}`)) {
      return true;
    }
  }
  return false;
}

export function scrubPIIText(text) {
  if (!text) {
    return text;
  }
  const emailRegex = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
  const phoneRegex = /\b(?:\+?1[\s.-]*)?(?:\(\d{3}\)|\d{3})[\s.-]*\d{3}[\s.-]*\d{4}\b/g;
  return text
    .replace(emailRegex, '[REDACTED_EMAIL]')
    .replace(phoneRegex, '[REDACTED_PHONE]');
}

async function fetchWithTimeout(url, options = {}, timeoutMs = DEFAULT_FETCH_TIMEOUT_MS) {
  const controller = new AbortController();
  const timeoutId = setNodeTimeout(() => controller.abort(), timeoutMs);

  try {
    return await globalThis.fetch(url, { ...options, signal: controller.signal });
  } catch (error) {
    if (error && error.name === 'AbortError') {
      throw Object.assign(new Error('fetch_timeout'), { code: 'fetch_timeout' });
    }
    throw error;
  } finally {
    clearNodeTimeout(timeoutId);
  }
}

export async function crawlUrls(seedUrls, options) {
  const {
    maxPages,
    perDomain,
    allowlist,
    userAgent,
    scrubPII = false
  } = options || {};

  const queue = [];
  const queuedUrls = new Set();
  const visited = new Set();
  const results = [];
  const perDomainCounts = new Map();
  const queuedPerDomain = new Map();

  for (const seed of seedUrls || []) {
    const normalized = normalizeUrl(seed);
    if (!normalized) {
      continue;
    }
    queue.push(normalized);
    queuedUrls.add(normalized);
    const host = getHostname(normalized);
    if (host) {
      queuedPerDomain.set(host, (queuedPerDomain.get(host) || 0) + 1);
    }
  }

  while (queue.length > 0 && results.length < maxPages) {
    const current = queue.shift();
    if (current) {
      queuedUrls.delete(current);
    }
    const currentHost = getHostname(current);
    if (currentHost) {
      const existingQueue = queuedPerDomain.get(currentHost) || 0;
      if (existingQueue > 0) {
        queuedPerDomain.set(currentHost, existingQueue - 1);
      }
    }

    if (!current || visited.has(current)) {
      continue;
    }

    visited.add(current);

    const baseRecord = {
      url: current,
      fetchedAt: new Date().toISOString()
    };

    if (!currentHost || !allowlistHasHost(currentHost, allowlist)) {
      results.push({ ...baseRecord, error: 'host_not_allowlisted' });
      continue;
    }

    const currentCount = perDomainCounts.get(currentHost) || 0;
    if (currentCount >= perDomain) {
      results.push({ ...baseRecord, skipped: 'per_domain_limit' });
      continue;
    }

    let response;
    try {
      response = await fetchWithTimeout(current, {
        headers: {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
        }
      });
    } catch (error) {
      perDomainCounts.set(currentHost, currentCount + 1);
      results.push({
        ...baseRecord,
        error: error && error.code === 'fetch_timeout' ? 'timeout' : 'fetch_failed',
        details: error ? String(error.message || error.code || error) : 'unknown_error'
      });
      continue;
    }

    const record = { ...baseRecord };
    record.status = response.status;
    record.ok = response.ok;
    record.scrubbed = Boolean(scrubPII);
    record.contentType = response.headers.get('content-type') || '';

    const finalUrl = response.url || current;
    record.url = finalUrl;

    const finalHost = getHostname(finalUrl) || currentHost;
    const finalAllowlisted = allowlistHasHost(finalHost, allowlist);

    if (finalHost !== currentHost) {
      perDomainCounts.set(currentHost, currentCount + 1);
    }

    const finalCount = perDomainCounts.get(finalHost) || 0;
    if (finalCount >= perDomain) {
      perDomainCounts.set(finalHost, finalCount);
      record.skipped = 'per_domain_limit';
      results.push(record);
      continue;
    }

    let body = '';
    try {
      body = await response.text();
    } catch (error) {
      perDomainCounts.set(finalHost, finalCount + 1);
      record.error = 'read_failed';
      record.details = error ? String(error.message || error) : 'unknown_error';
      results.push(record);
      continue;
    }

    record.rawLength = body.length;

    if (!finalAllowlisted) {
      perDomainCounts.set(finalHost, finalCount + 1);
      record.error = 'redirected_host_not_allowed';
      results.push(record);
      continue;
    }

    perDomainCounts.set(finalHost, finalCount + 1);

    if (response.ok && isHtmlContentType(record.contentType)) {
      const stripped = stripScriptsAndStyles(body);
      const title = extractTitle(stripped);
      const textContent = htmlToText(stripped);
      record.title = scrubPII ? scrubPIIText(title) : title;
      record.content = scrubPII ? scrubPIIText(textContent) : textContent;

      const links = extractLinks(stripped, finalUrl);
      const discovered = [];
      for (const link of links) {
        if (results.length + queue.length >= maxPages) {
          break;
        }
        if (visited.has(link) || queuedUrls.has(link)) {
          continue;
        }
        const linkHost = getHostname(link);
        if (!linkHost || !allowlistHasHost(linkHost, allowlist)) {
          continue;
        }
        const hostCount = perDomainCounts.get(linkHost) || 0;
        const hostQueued = queuedPerDomain.get(linkHost) || 0;
        if (hostCount + hostQueued >= perDomain) {
          continue;
        }
        queue.push(link);
        queuedUrls.add(link);
        queuedPerDomain.set(linkHost, hostQueued + 1);
        discovered.push(link);
      }
      if (discovered.length > 0) {
        record.discoveredLinks = discovered;
      }
    } else {
      const preview = body.slice(0, 500);
      record.content = scrubPII ? scrubPIIText(preview) : preview;
    }

    results.push(record);
  }

  return results;
}

export { normalizeUrl };
