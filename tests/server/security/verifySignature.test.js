const assert = require('assert');
const crypto = require('crypto');
const { verifySignature } = require('../../../server/security/verifySignature');

process.env.LUKA_API_SECRET = 'unit-test-secret';

function sign({ method, path, payload = '', timestamp = Date.now().toString() }) {
  const normalizedMethod = method.toUpperCase();
  const payloadString = typeof payload === 'string' ? payload : JSON.stringify(payload);
  const baseString = `${timestamp}.${normalizedMethod}.${path}.${payloadString}`;
  const signature = crypto.createHmac('sha256', process.env.LUKA_API_SECRET).update(baseString).digest('hex');

  return {
    headers: {
      'x-luka-signature': signature,
      'x-luka-timestamp': timestamp
    },
    payload
  };
}

function expectSignatureError(fn) {
  try {
    fn();
    throw new Error('Expected verifySignature to throw');
  } catch (err) {
    assert.strictEqual(err.message, 'Invalid Luka signature');
  }
}

(function runTests() {
  const context = { method: 'GET', path: '/api/wo/123/action' };
  const signed = sign({ ...context });
  assert.strictEqual(verifySignature({ ...signed, method: context.method, path: context.path }), true);

  expectSignatureError(() =>
    verifySignature({
      ...signed,
      method: 'POST',
      path: context.path
    })
  );

  expectSignatureError(() =>
    verifySignature({
      ...signed,
      method: context.method,
      path: '/api/wo/456/action'
    })
  );

  console.log('verifySignature tests passed');
})();
