const crypto = require('crypto');

const FIVE_MINUTES_MS = 5 * 60 * 1000;

function toMilliseconds(timestampHeader) {
  const ts = Number(timestampHeader);
  if (!Number.isFinite(ts)) {
    return null;
  }

  return ts < 1e12 ? ts * 1000 : ts;
}

function normalizePayload(payload) {
  if (payload === undefined || payload === null) {
    return '';
  }
  return typeof payload === 'string' ? payload : JSON.stringify(payload);
}

function verifySignature({ headers = {}, payload } = {}) {
  const secret = process.env.LUKA_API_SECRET;
  if (!secret) {
    const err = new Error('Server misconfiguration: missing LUKA_API_SECRET');
    err.statusCode = 500;
    throw err;
  }

  const signature = headers['x-luka-signature'];
  const timestampHeader = headers['x-luka-timestamp'];

  if (!signature || !timestampHeader) {
    const err = new Error('Missing Luka signature headers');
    err.statusCode = 401;
    throw err;
  }

  const timestampMs = toMilliseconds(timestampHeader);
  if (!timestampMs) {
    const err = new Error('Invalid Luka timestamp header');
    err.statusCode = 400;
    throw err;
  }

  if (Math.abs(Date.now() - timestampMs) > FIVE_MINUTES_MS) {
    const err = new Error('Request timestamp outside the allowed window');
    err.statusCode = 401;
    throw err;
  }

  const payloadString = normalizePayload(payload);
  const baseString = `${timestampHeader}.${payloadString}`;
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(baseString)
    .digest('hex');

  const providedBuffer = Buffer.from(signature, 'utf8');
  const expectedBuffer = Buffer.from(expectedSignature, 'utf8');

  if (
    providedBuffer.length !== expectedBuffer.length ||
    !crypto.timingSafeEqual(providedBuffer, expectedBuffer)
  ) {
    const err = new Error('Invalid Luka signature');
    err.statusCode = 401;
    throw err;
  }

  return true;
}

module.exports = { verifySignature };
