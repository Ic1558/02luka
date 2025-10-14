const API_URL = 'https://api.openai.com/v1/chat/completions';
const DEFAULT_MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';

function requireKey() {
  const key = process.env.OPENAI_API_KEY;
  if (!key) {
    const err = new Error('OpenAI API key not configured');
    err.code = 'NO_KEY';
    throw err;
  }
  return key;
}

function extractText(data) {
  if (!data) return '';
  const choice = Array.isArray(data.choices) ? data.choices[0] : null;
  if (!choice) return '';
  const message = choice.message || {};
  if (typeof message.content === 'string') {
    return message.content.trim();
  }
  return '';
}

async function postCompletion(payload) {
  const key = requireKey();
  const res = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${key}`
    },
    body: JSON.stringify(payload)
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`OpenAI request failed: ${res.status} ${res.statusText} ${detail}`.trim());
  }

  return res.json();
}

function buildOptimizePrompt({ system, user, context, model }) {
  const instructions = [
    'You are an expert prompt engineer optimizing instructions for a team of AI delegates.',
    'Refine the supplied prompt to be direct, structured, and execution-ready.',
    'Answer with the improved prompt only.'
  ];
  if (system) {
    instructions.push('Respect the provided system directive.');
  }
  if (context) {
    instructions.push('Include relevant context and constraints.');
  }

  const messages = [
    { role: 'system', content: instructions.join(' ') }
  ];

  const sections = [];
  if (system) sections.push(`System:\n${system.trim()}`);
  if (context) sections.push(`Context:\n${context.trim()}`);
  if (user) sections.push(`Prompt:\n${user.trim()}`);

  messages.push({ role: 'user', content: sections.join('\n\n') || user || '' });

  return {
    model: model || DEFAULT_MODEL,
    temperature: 0.2,
    max_tokens: 800,
    messages
  };
}

function buildChatPayload({ input, system, model }) {
  const messages = [];
  if (system) {
    messages.push({ role: 'system', content: String(system) });
  }
  messages.push({ role: 'user', content: String(input || '') });

  return {
    model: model || DEFAULT_MODEL,
    temperature: 0.3,
    max_tokens: 800,
    messages
  };
}

async function optimizePrompt({ system = '', user = '', context = '', model } = {}) {
  const response = await postCompletion(buildOptimizePrompt({ system, user, context, model }));
  const text = extractText(response);
  return {
    text,
    raw: response
  };
}

async function chat({ input = '', system = '', model } = {}) {
  const response = await postCompletion(buildChatPayload({ input, system, model }));
  const text = extractText(response);
  return {
    text,
    raw: response
  };
}

module.exports = {
  optimizePrompt,
  chat
};
