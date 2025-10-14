const API_URL = process.env.OPENAI_RESPONSES_URL || 'https://api.openai.com/v1/responses';
const DEFAULT_MODEL = process.env.OPENAI_MODEL || 'o4-mini';
const DEFAULT_REASONING_EFFORT = process.env.OPENAI_REASONING_EFFORT || 'medium';

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
  if (typeof data.output_text === 'string') {
    return data.output_text.trim();
  }
  const parts = [];
  const blocks = Array.isArray(data.output) ? data.output : [];
  for (const block of blocks) {
    if (!block) continue;
    if (typeof block.output_text === 'string') {
      parts.push(block.output_text);
    }
    if (typeof block.text === 'string') {
      parts.push(block.text);
    }
    const contentItems = Array.isArray(block.content) ? block.content : [];
    for (const item of contentItems) {
      if (!item) continue;
      if (typeof item.text === 'string') {
        parts.push(item.text);
      }
      if (typeof item.output_text === 'string') {
        parts.push(item.output_text);
      }
    }
  }
  return parts.join('\n').trim();
}

function extractReasoning(data) {
  if (!data) return '';
  const collected = [];
  const blocks = Array.isArray(data.output) ? data.output : [];
  for (const block of blocks) {
    const contentItems = Array.isArray(block?.content) ? block.content : [];
    for (const item of contentItems) {
      if (!item) continue;
      if (item.type === 'reasoning' && typeof item.reasoning === 'string') {
        collected.push(item.reasoning);
      } else if (item.type === 'reasoning' && typeof item.text === 'string') {
        collected.push(item.text);
      } else if (item.type === 'reasoning_text' && typeof item.text === 'string') {
        collected.push(item.text);
      } else if (item.type === 'thought' && typeof item.text === 'string') {
        collected.push(item.text);
      }
    }
  }
  return collected.join('\n\n').trim();
}

function wrapMessage(role, text) {
  return {
    role,
    content: [{ type: 'text', text: String(text || '') }]
  };
}

function supportsReasoning(model) {
  return /^(o[0-9]|gpt-4\.1-mini|gpt-4\.1)/i.test(String(model || ''));
}

function withReasoning(payload) {
  const reasoningEffort = DEFAULT_REASONING_EFFORT;
  const model = payload?.model || DEFAULT_MODEL;
  if (!reasoningEffort || !supportsReasoning(model)) {
    return payload;
  }
  return { ...payload, reasoning: { effort: reasoningEffort } };
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

  const systemMsg = wrapMessage('system', instructions.join(' '));
  const sections = [];
  if (system) sections.push(`System:\n${system.trim()}`);
  if (context) sections.push(`Context:\n${context.trim()}`);
  if (user) sections.push(`Prompt:\n${user.trim()}`);

  const userMsg = wrapMessage('user', sections.join('\n\n') || user || '');

  return withReasoning({
    model: model || DEFAULT_MODEL,
    input: [systemMsg, userMsg],
    max_output_tokens: 800,
    temperature: 0.2,
    metadata: { intent: 'prompt_optimization' }
  });
}

function buildChatPayload({ input, system, model }) {
  const messages = [];
  if (system) {
    messages.push(wrapMessage('system', system));
  }
  messages.push(wrapMessage('user', input || ''));

  return withReasoning({
    model: model || DEFAULT_MODEL,
    input: messages,
    max_output_tokens: 800,
    temperature: 0.3,
    metadata: { intent: 'direct_chat' }
  });
}

async function optimizePrompt({ system = '', user = '', context = '', model } = {}) {
  const response = await postCompletion(buildOptimizePrompt({ system, user, context, model }));
  const text = extractText(response);
  return {
    text,
    raw: response,
    model: response?.model || model || DEFAULT_MODEL,
    reasoning: extractReasoning(response)
  };
}

async function chat({ input = '', system = '', model } = {}) {
  const response = await postCompletion(buildChatPayload({ input, system, model }));
  const text = extractText(response);
  return {
    text,
    raw: response,
    model: response?.model || model || DEFAULT_MODEL,
    reasoning: extractReasoning(response)
  };
}

module.exports = {
  optimizePrompt,
  chat
};
