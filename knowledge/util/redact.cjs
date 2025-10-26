#!/usr/bin/env node

const EMAIL_REGEX = /([A-Za-z0-9._%+-]{2,})@([A-Za-z0-9.-]+\.[A-Za-z]{2,})/g;
const TOKEN_REGEX = /\b([A-Za-z0-9]{6})([A-Za-z0-9._-]{10,})\b/g;
const UUID_REGEX = /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/g;
const CREDIT_CARD_REGEX = /(\b\d{4})[- ]?(\d{4})[- ]?(\d{4})[- ]?(\d{1,4}\b)/g;

function maskEmail(match, user, domain) {
  if (!user) return match;
  const masked = user.length <= 2 ? '*'.repeat(user.length) : `${user[0]}***${user[user.length - 1]}`;
  return `${masked}@${domain}`;
}

function maskToken(match, start, rest) {
  if (!start || !rest) return match;
  return `${start}***${rest.slice(-2)}`;
}

function maskCard(match, g1, g2, g3, g4) {
  return `${g1}-****-****-${g4}`;
}

function maskUuid(match) {
  return `${match.slice(0, 4)}****-****-****-****${match.slice(-4)}`;
}

function redactString(value) {
  if (typeof value !== 'string' || value.length === 0) {
    return value;
  }
  let result = value;
  result = result.replace(EMAIL_REGEX, maskEmail);
  result = result.replace(TOKEN_REGEX, maskToken);
  result = result.replace(CREDIT_CARD_REGEX, maskCard);
  result = result.replace(UUID_REGEX, maskUuid);
  return result;
}

function redact(value) {
  if (value == null) {
    return value;
  }
  if (typeof value === 'string') {
    return redactString(value);
  }
  if (Array.isArray(value)) {
    return value.map((item) => redact(item));
  }
  if (typeof value === 'object') {
    const output = {};
    for (const [key, val] of Object.entries(value)) {
      output[key] = redact(val);
    }
    return output;
  }
  return value;
}

function summarize(value, limit = 400) {
  const text = typeof value === 'string' ? value : JSON.stringify(value);
  if (!text) {
    return '';
  }
  if (text.length <= limit) {
    return text;
  }
  return `${text.slice(0, limit)}… (${text.length - limit} more)`;
}

module.exports = {
  redact,
  redactString,
  summarize,
};

if (require.main === module) {
  const samples = [
    'Contact me at sample.user@example.com',
    'Token sk_live_1234567890ABCDEFGHIJ',
    'Card 4242-4242-4242-4242',
    'UUID 123e4567-e89b-12d3-a456-426614174000',
  ];
  for (const sample of samples) {
    console.log(redact(sample));
  }
}
