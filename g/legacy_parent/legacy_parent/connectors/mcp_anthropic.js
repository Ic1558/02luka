const API_URL = 'https://api.anthropic.com/v1/messages';
const DEFAULT_MODEL = process.env.ANTHROPIC_MODEL || 'claude-3-sonnet-20240229';

function requireKey() {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) {
    const err = new Error('Anthropic API key not configured');
    err.code = 'NO_KEY';
    throw err;
  }
  return key;
}

function extractText(data) {
  if (!data) return '';
  if (Array.isArray(data.content)) {
    return data.content
      .map((part) => typeof part === 'string' ? part : (part && typeof part.text === 'string' ? part.text : ''))
      .filter(Boolean)
      .join('\n')
      .trim();
  }
  if (typeof data.content === 'string') return data.content;
  return '';
}

async function postMessage(payload) {
  const key = requireKey();
  const res = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': key,
      'anthropic-version': '2023-06-01'
    },
    body: JSON.stringify(payload)
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Anthropic request failed: ${res.status} ${res.statusText} ${detail}`.trim());
  }

  return res.json();
}

function buildOptimizePrompt({ system, user, context }) {
  const instructions = [
    'You are an expert prompt engineer optimizing instructions for multi-agent orchestration.',
    'Rewrite the provided prompt so that it is concise, explicit, and ready for execution by professional assistants.',
    'Return only the improved prompt without commentary.'
  ];
  if (system) {
    instructions.push('Incorporate the given system directive.');
  }
  if (context) {
    instructions.push('Respect the provided context and constraints.');
  }

  const segments = [];
  if (system) {
    segments.push(`System Directive:\n${system.trim()}`);
  }
  if (context) {
    segments.push(`Context:\n${context.trim()}`);
  }
  if (user) {
    segments.push(`User Prompt:\n${user.trim()}`);
  }

  const combined = segments.join('\n\n') || user || '';

  return {
    model: DEFAULT_MODEL,
    max_tokens: 800,
    temperature: 0.2,
    system: instructions.join(' '),
    messages: [
      {
        role: 'user',
        content: combined
      }
    ]
  };
}

function buildChatPayload({ input, system, model }) {
  const payload = {
    model: model || DEFAULT_MODEL,
    max_tokens: 800,
    temperature: 0.2,
    messages: [
      {
        role: 'user',
        content: String(input || '')
      }
    ]
  };

  if (system) {
    payload.system = String(system);
  }

  return payload;
}

async function optimizePrompt({ system = '', user = '', context = '' } = {}) {
  const response = await postMessage(buildOptimizePrompt({ system, user, context }));
  const text = extractText(response);
  return {
    text,
    raw: response
  };
}

async function chat({ input = '', system = '', model } = {}) {
  const response = await postMessage(buildChatPayload({ input, system, model }));
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
