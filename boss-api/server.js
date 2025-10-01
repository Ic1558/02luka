const http = require('http');
const https = require('https');
const path = require('path');
const fs = require('fs/promises');

const HOST = process.env.HOST || '127.0.0.1';
const PORT = Number(process.env.PORT || 4000);
const repoRoot = path.resolve(__dirname, '..'); // 02luka-repo root
const bossRoot = path.join(repoRoot, 'boss');

function writeJson(res, code, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type'
  });
  res.end(body);
}

function clampScore(value) {
  if (!Number.isFinite(value)) return 0;
  if (value < 0) return 0;
  if (value > 1) return 1;
  return Number(value.toFixed(3));
}

function normalizeWhitespace(text) {
  return text.replace(/[ \t]+/g, ' ').replace(/\s+\n/g, '\n').trim();
}

function ensureSentence(text) {
  if (!text) return '';
  const trimmed = text.trim();
  if (!trimmed) return '';
  return /[.!?]$/.test(trimmed) ? trimmed : `${trimmed}.`;
}

function stripBulletPrefix(line) {
  return line.replace(/^\s*(?:[-*]|\d+[.)])\s*/, '').trim();
}

function dedupeStrings(items) {
  const seen = new Set();
  const result = [];
  for (const item of items) {
    const normalized = item.trim();
    if (!normalized) continue;
    const key = normalized.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(normalized);
  }
  return result;
}

function analyzePromptStructure(promptText) {
  const text = (promptText || '').replace(/\r/g, '');
  const normalized = text.toLowerCase();
  const words = normalized.split(/\s+/).filter(Boolean);
  const wordCount = words.length;
  const headings = (text.match(/(^|\n)\s*(?:#{2,}|[A-Z][A-Z\s]{3,}:)/g) || []).length;
  const bulletCount = (text.match(/(^|\n)\s*(?:[-*]|\d+[.)])\s+/g) || []).length;
  const hasYouAre = /\byou are\b|\bact as\b/i.test(text);
  const hasDeliverable = /\bdeliverable\b|\boutput\b|\breturn\b|\bprovide\b|\breport\b|\bsubmit\b/i.test(normalized);
  const hasQuality = /\bquality\b|\bsuccess\b|\bdefinition of done\b|\bacceptance\b|\bverify\b/i.test(normalized);
  const hasCallToAction = /\bplan\b|\bexecute\b|\banalyze\b|\brespond\b|\bprepare\b|\bdraft\b|\bdeliver\b|\bproduce\b/i.test(normalized);
  const hasContext = /\bcontext\b|\bbackground\b|\bmission\b|\bgoal\b|\bbrief\b/i.test(normalized);
  const hasConstraints = /\bconstraint\b|\bdeadline\b|\bmust not\b|\bavoid\b|\bwithout\b|\bdo not\b/i.test(normalized);
  const hasMetrics = /\bmetric\b|\bscore\b|\bdeadline\b|\bminutes?\b|\bhours?\b|\bday\b|\beta\b/i.test(normalized);

  const readabilityTarget = 180;
  const readability = clampScore(1 - Math.min(1, Math.abs(wordCount - readabilityTarget) / readabilityTarget));

  let score = 0.35;
  score += Math.min(0.25, readability * 0.25);
  if (wordCount > 50) score += 0.05;
  if (headings > 0) score += 0.08;
  if (bulletCount > 0) score += 0.1;
  if (hasDeliverable) score += 0.08;
  if (hasQuality) score += 0.07;
  if (hasCallToAction) score += 0.07;
  if (hasContext) score += 0.05;
  if (hasConstraints) score += 0.05;
  if (hasYouAre) score += 0.03;
  if (hasMetrics) score += 0.02;

  return {
    wordCount,
    headings,
    bulletCount,
    hasYouAre,
    hasDeliverable,
    hasQuality,
    hasCallToAction,
    hasContext,
    hasConstraints,
    hasMetrics,
    readability,
    score: clampScore(score)
  };
}

function computeFeatureDelta(targetFeatures, baselineFeatures) {
  if (!baselineFeatures) return {};
  const delta = {
    score: Number((targetFeatures.score - baselineFeatures.score).toFixed(3))
  };

  const booleanKeys = ['hasYouAre', 'hasDeliverable', 'hasQuality', 'hasCallToAction', 'hasContext', 'hasConstraints', 'hasMetrics'];
  for (const key of booleanKeys) {
    if (typeof targetFeatures[key] === 'boolean' && typeof baselineFeatures[key] === 'boolean') {
      delta[key] = targetFeatures[key] === baselineFeatures[key]
        ? 0
        : (targetFeatures[key] ? 1 : -1);
    }
  }

  const numericKeys = ['wordCount', 'headings', 'bulletCount'];
  for (const key of numericKeys) {
    if (typeof targetFeatures[key] === 'number' && typeof baselineFeatures[key] === 'number') {
      delta[key] = Number((targetFeatures[key] - baselineFeatures[key]).toFixed(2));
    }
  }

  return delta;
}

function extractRoleLine(promptText) {
  const match = promptText.match(/you are[^\n.]*[\n.]?/i);
  if (match) {
    return ensureSentence(normalizeWhitespace(match[0]));
  }
  const firstLine = promptText.split(/\n/).map((line) => line.trim()).find(Boolean);
  if (firstLine) {
    if (/act as|pretend/i.test(firstLine)) {
      return ensureSentence(firstLine);
    }
    return ensureSentence(`You are ${firstLine}`);
  }
  return 'You are Luka, a decisive autonomous operator coordinating expert AI systems.';
}

function parsePromptComponents(promptText) {
  const cleaned = (promptText || '').replace(/\r/g, '');
  const lines = cleaned.split(/\n/);
  const bulletLines = lines.filter((line) => /^\s*(?:[-*]|\d+[.)])\s+/.test(line)).map(stripBulletPrefix);
  const nonBulletLines = lines.filter((line) => !/^\s*(?:[-*]|\d+[.)])\s+/.test(line));
  const paragraphs = nonBulletLines.join('\n').split(/\n\s*\n/).map((block) => block.trim()).filter(Boolean);
  const sentences = paragraphs.flatMap((para) => para.split(/(?<=[.!?])\s+/)).map((item) => item.trim()).filter(Boolean);
  const deliverableLines = lines
    .filter((line) => /\bdeliverable\b|\boutput\b|\breturn\b|\bprovide\b|\breport\b|\bsubmit\b|\bproduce\b|\bshare\b/i.test(line))
    .map(stripBulletPrefix);
  const constraintSentences = sentences.filter((line) => /\bmust\b|\bmust not\b|\bavoid\b|\bconstraint\b|\bdeadline\b|\bwithout\b|\bdo not\b/i.test(line));
  const questionSentences = sentences.filter((line) => /\?/g.test(line));
  const resourceLines = lines.filter((line) => /\btool\b|\bresource\b|\bapi\b|\bdatabase\b|\bdocument\b|\blink\b/i.test(line)).map(stripBulletPrefix);
  const summaryParagraph = paragraphs[0] || '';
  return {
    lines,
    bulletLines,
    paragraphs,
    sentences,
    deliverableLines,
    constraintSentences,
    questionSentences,
    resourceLines,
    summaryParagraph
  };
}

function ensureNumberedList(items) {
  const unique = dedupeStrings(items).slice(0, 6);
  const finalItems = unique.length > 0 ? unique : [
    'Clarify the mission objectives and missing context.',
    'Draft a step-by-step action plan before execution.',
    'Execute tasks decisively while documenting key findings.',
    'Report progress, blockers, and recommended next actions.'
  ];
  return finalItems.map((item, index) => `${index + 1}. ${ensureSentence(stripBulletPrefix(item))}`);
}

function ensureBulletList(items, options = {}) {
  const prefix = options.checkbox ? '- [ ] ' : '- ';
  const unique = dedupeStrings(items).slice(0, options.limit || 6);
  const fallback = options.fallback || [
    'Summarize the current understanding and assumptions.',
    'List concrete next actions or questions to resolve.',
    'Flag risks or blockers that need attention.'
  ];
  const source = unique.length > 0 ? unique : fallback;
  return source.map((item) => `${prefix}${stripBulletPrefix(item)}`);
}

function buildStructuredVariant(promptText, components) {
  const roleLine = extractRoleLine(promptText);
  const mission = components.summaryParagraph || ensureSentence('Deliver a decisive plan that solves the mission.');
  const procedure = ensureNumberedList(components.bulletLines);
  const constraintsList = ensureBulletList(components.constraintSentences, {
    fallback: ['Call out any constraints or dependencies you identify.']
  });
  const deliverables = ensureBulletList(components.deliverableLines, {
    fallback: [
      'Provide a concise mission report covering actions taken, key findings, and outcomes.',
      'List the top-priority next moves or requests for clarification.'
    ]
  });

  const prompt = [
    '## Role',
    roleLine,
    '## Mission Brief',
    mission,
    '## Constraints',
    constraintsList.join('\n'),
    '## Operating Procedure',
    procedure.join('\n'),
    '## Deliverables',
    deliverables.join('\n'),
    '## Quality Bar',
    '- Cross-check each deliverable for accuracy before finalizing.\n- Surface any risks, blockers, or open questions with owner-ready language.'
  ].join('\n\n');

  return {
    id: 'structured-brief',
    title: 'Structured mission brief',
    summary: 'Adds Role, Mission, Constraints, Procedure, Deliverables, and Quality sections for a crisp battle plan.',
    improvements: [
      'Introduces a mission brief template to frame the ask.',
      'Normalizes steps into a numbered operating procedure.',
      'Clarifies expected deliverables and success checks.'
    ],
    prompt
  };
}

function buildChecklistVariant(promptText, components) {
  const summary = components.summaryParagraph || ensureSentence('Execute quickly while maintaining communication.');
  const actions = ensureBulletList(components.bulletLines.length ? components.bulletLines : components.sentences, {
    checkbox: true,
    fallback: [
      'Draft an initial action plan and confirm with stakeholders.',
      'Execute the plan, keeping a log of decisions and learnings.',
      'Reconcile outputs against the mission goals before delivering.'
    ]
  });
  const checkpoints = ensureBulletList(components.questionSentences, {
    fallback: [
      'T+15m: Confirm understanding of the mission and surface missing information.',
      'T+30m: Share progress snapshot with any early findings.',
      'T+60m: Deliver refined output and proposed next moves.'
    ]
  });
  const deliverables = ensureBulletList(components.deliverableLines, {
    fallback: [
      'Final response must include a concise summary, key evidence, and prioritized next steps.',
      'Highlight blockers or open questions separately from the main answer.'
    ]
  });

  const prompt = [
    '### Mission Summary',
    summary,
    '### Action Checklist',
    actions.join('\n'),
    '### Checkpoints & Comms Rhythm',
    checkpoints.join('\n'),
    '### Completion Criteria',
    deliverables.join('\n'),
    '### Closing Loop',
    '- Close with confidence level, outstanding risks, and the next recommended push.'
  ].join('\n\n');

  return {
    id: 'checklist',
    title: 'Checklist with comms rhythm',
    summary: 'Turns the mission into checkboxes with explicit time-boxed updates and completion criteria.',
    improvements: [
      'Establishes a communication cadence for progress signals.',
      'Adds checkbox-style actions to drive accountability.',
      'Defines how to wrap with confidence, risks, and next steps.'
    ],
    prompt
  };
}

function buildNorthStarVariant(promptText, components) {
  const roleLine = extractRoleLine(promptText);
  const mission = components.summaryParagraph || ensureSentence('Deliver a high-signal answer that unblocks execution.');
  const resources = ensureBulletList(components.resourceLines, {
    fallback: ['Leverage available local tools, knowledge bases, and MCP resources as needed.']
  });
  const guardrails = ensureBulletList(components.constraintSentences, {
    fallback: [
      'Escalate if critical information is missing before making irreversible calls.',
      'Document assumptions explicitly whenever acting on them.'
    ]
  });
  const deliverables = ensureBulletList(components.deliverableLines, {
    fallback: [
      'North Star Output: actionable plan + supporting rationale.',
      'Next moves list with owners (even if tentative).'
    ]
  });

  const prompt = [
    'SYSTEM ROLE:',
    roleLine,
    'OBJECTIVE:',
    mission,
    'NORTH STAR OUTPUT:',
    deliverables.join('\n'),
    'RESOURCES & LEVERS:',
    resources.join('\n'),
    'GUARDRAILS:',
    guardrails.join('\n'),
    'SIGN-OFF FORMAT:',
    '- Begin with a one-line mission status (GREEN / YELLOW / RED).\n- Provide the recommended plan with supporting evidence.\n- List risks, blockers, and explicit asks of stakeholders.'
  ].join('\n\n');

  return {
    id: 'north-star',
    title: 'North Star outcome framing',
    summary: 'Frames the request around mission objective, resources, guardrails, and expected sign-off structure.',
    improvements: [
      'Focuses the assistant on the north-star outcome and evidence.',
      'Surfaces available levers/resources explicitly.',
      'Defines sign-off format with status call, plan, and risks.'
    ],
    prompt
  };
}

function scoreAndEnrichVariant(variant, baselineFeatures) {
  const features = analyzePromptStructure(variant.prompt);
  return Object.assign({}, variant, {
    score: features.score,
    features,
    delta: computeFeatureDelta(features, baselineFeatures)
  });
}

function generateHeuristicVariants(promptText) {
  const components = parsePromptComponents(promptText);
  const baselineFeatures = analyzePromptStructure(promptText);
  const baseline = {
    id: 'baseline',
    title: 'Original prompt',
    summary: 'As provided by the operator.',
    prompt: promptText,
    score: baselineFeatures.score,
    features: baselineFeatures
  };

  const rawVariants = [
    buildStructuredVariant(promptText, components),
    buildChecklistVariant(promptText, components),
    buildNorthStarVariant(promptText, components)
  ];

  const enriched = rawVariants
    .map((variant) => scoreAndEnrichVariant(variant, baselineFeatures))
    .sort((a, b) => b.score - a.score);

  return { baseline, variants: enriched };
}

async function maybeAddModelVariant(promptText, baselineFeatures) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return null;

  const baseUrl = (process.env.OPENAI_BASE_URL || 'https://api.openai.com').replace(/\/+$/, '');
  const model = process.env.LUKA_OPTIMIZER_MODEL || 'gpt-4o-mini';

  const body = JSON.stringify({
    model,
    temperature: 0.3,
    max_tokens: 900,
    messages: [
      {
        role: 'system',
        content: 'You refine operator prompts for autonomous AI systems. Return only the improved prompt. Make it structured and actionable.'
      },
      {
        role: 'user',
        content: `Rewrite the following prompt so it is crisp, structured, and ready for an elite AI operator. Keep all critical details.\n\n${promptText}`
      }
    ]
  });

  try {
    const response = await httpRequestJson(`${baseUrl}/v1/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`
      },
      body,
      timeout: 20000
    });

    if (response.status < 200 || response.status >= 300) {
      return null;
    }

    const parsed = response.body ? JSON.parse(response.body) : {};
    const text = extractTextFromPayload(parsed);
    if (!text) return null;

    const cleaned = text.trim();
    if (!cleaned) return null;

    const variant = {
      id: 'model-rewrite',
      title: `Model rewrite (${model})`,
      summary: 'Rewritten via remote model for additional polish.',
      improvements: [
        'Applies LLM-driven restructuring with the latest context.',
        'Maintains mission intent while tightening instructions.'
      ],
      prompt: cleaned,
      source: 'model',
      meta: { provider: 'openai', model }
    };

    return scoreAndEnrichVariant(variant, baselineFeatures);
  } catch (err) {
    console.warn('[boss-api] optimize_prompt model call failed', err.message || err);
    return null;
  }
}

async function optimizePrompt(promptText) {
  const heuristic = generateHeuristicVariants(promptText);
  const modelVariant = await maybeAddModelVariant(promptText, heuristic.baseline.features);
  const variants = [...heuristic.variants];
  if (modelVariant) {
    variants.push(modelVariant);
    variants.sort((a, b) => b.score - a.score);
  }

  return {
    ok: true,
    heuristics: 'v1',
    baseline: heuristic.baseline,
    variants,
    meta: {
      generatedAt: new Date().toISOString(),
      usingModel: Boolean(modelVariant),
      model: modelVariant?.meta?.model || null
    }
  };
}

const allowed = new Set(['inbox','sent','deliverables','dropbox','drafts','documents']);

const CHAT_TARGETS = {
  auto: {
    id: 'auto',
    name: 'Smart Delegate',
    type: 'aggregate',
    delegates: ['mcp', 'mcp_fs', 'ollama']
  },
  mcp: {
    id: 'mcp',
    name: 'MCP Docker Gateway',
    type: 'mcp',
    baseUrl: process.env.MCP_GATEWAY_URL || 'http://127.0.0.1:5012'
  },
  mcp_fs: {
    id: 'mcp_fs',
    name: 'MCP FS Gateway',
    type: 'mcp',
    baseUrl: process.env.MCP_FS_URL || 'http://127.0.0.1:8765'
  },
  ollama: {
    id: 'ollama',
    name: 'Ollama',
    type: 'ollama',
    baseUrl: process.env.OLLAMA_URL || 'http://localhost:11434'
  }
};

function httpRequestJson(targetUrl, options = {}) {
  const url = new URL(targetUrl);
  const isHttps = url.protocol === 'https:';
  const transport = isHttps ? https : http;
  const body = options.body || null;

  return new Promise((resolve, reject) => {
    const req = transport.request({
      protocol: url.protocol,
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: `${url.pathname}${url.search}`,
      method: options.method || 'GET',
      headers: Object.assign({}, options.headers || {}, body
        ? { 'Content-Length': Buffer.byteLength(body) }
        : {})
    }, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        resolve({ status: res.statusCode, headers: res.headers, body: data });
      });
    });

    req.on('error', reject);
    req.setTimeout(options.timeout || 10000, () => {
      req.destroy(new Error('Request timed out'));
    });

    if (body) {
      req.write(body);
    }

    req.end();
  });
}

function extractTextFromPayload(payload) {
  if (payload == null) return '';
  if (typeof payload === 'string') return payload;
  if (Array.isArray(payload)) {
    return payload.map(extractTextFromPayload).filter(Boolean).join('\n');
  }

  if (payload.reply) return extractTextFromPayload(payload.reply);
  if (payload.response) return extractTextFromPayload(payload.response);
  if (payload.message) return extractTextFromPayload(payload.message);
  if (payload.output) return extractTextFromPayload(payload.output);
  if (payload.answer) return extractTextFromPayload(payload.answer);

  if (payload.choices && payload.choices.length) {
    const choice = payload.choices[0];
    if (choice && choice.message && typeof choice.message.content === 'string') {
      return choice.message.content;
    }
    if (typeof choice.text === 'string') {
      return choice.text;
    }
  }

  if (typeof payload.content === 'string') return payload.content;

  try {
    return JSON.stringify(payload);
  } catch (err) {
    return String(payload);
  }
}

function summarizeMcpHandshake(payload) {
  const lines = ['MCP handshake successful.'];
  if (!payload || typeof payload !== 'object') {
    lines.push('No additional metadata received from gateway.');
    return lines.join('\n');
  }

  const result = payload.result || {};
  const serverInfo = result.serverInfo || {};
  const capabilities = result.capabilities || {};

  if (serverInfo.name || serverInfo.version) {
    const label = [serverInfo.name, serverInfo.version].filter(Boolean).join(' ');
    if (label) lines.push(`Server: ${label}`);
  }

  if (Array.isArray(capabilities.tools) && capabilities.tools.length) {
    lines.push(`Tools: ${capabilities.tools.join(', ')}`);
  }

  if (Array.isArray(capabilities.resources) && capabilities.resources.length) {
    lines.push(`Resources: ${capabilities.resources.join(', ')}`);
  }

  lines.push('Note: Gateway exposes MCP protocol; use a compatible client for interactive chat.');
  return lines.join('\n');
}

async function callMcpGateway(message, target) {
  const baseUrl = target.baseUrl.replace(/\/+$/, '');
  const payloadVariants = [
    {
      endpoint: '/chat',
      body: JSON.stringify({ message, prompt: message, input: message }),
      headers: { 'Content-Type': 'application/json' }
    },
    {
      endpoint: '/api/chat',
      body: JSON.stringify({ message, prompt: message, input: message }),
      headers: { 'Content-Type': 'application/json' }
    },
    {
      endpoint: '/v1/chat/completions',
      body: JSON.stringify({
        model: target.model || 'default',
        messages: [{ role: 'user', content: message }]
      }),
      headers: { 'Content-Type': 'application/json' }
    }
  ];

  for (const variant of payloadVariants) {
    try {
      const response = await httpRequestJson(`${baseUrl}${variant.endpoint}`, {
        method: 'POST',
        headers: variant.headers,
        body: variant.body,
        timeout: 15000
      });

      if (response.status >= 200 && response.status < 300) {
        let parsed;
        try {
          parsed = response.body ? JSON.parse(response.body) : null;
        } catch (err) {
          parsed = response.body;
        }
        const text = extractTextFromPayload(parsed);
        if (text) {
          return { text, meta: { endpoint: variant.endpoint, status: response.status } };
        }
      }
    } catch (err) {
      continue;
    }
  }

  try {
    const handshakePayload = JSON.stringify({
      jsonrpc: '2.0',
      id: `codex-handshake-${Date.now()}`,
      method: 'initialize',
      params: {}
    });

    const response = await httpRequestJson(`${baseUrl}/mcp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: handshakePayload,
      timeout: 10000
    });

    if (response.status >= 200 && response.status < 300) {
      let parsed;
      try {
        parsed = response.body ? JSON.parse(response.body) : null;
      } catch (err) {
        parsed = null;
      }

      const text = summarizeMcpHandshake(parsed);
      if (text) {
        return { text, meta: { endpoint: '/mcp', status: response.status } };
      }
    }
  } catch (err) {
    // fall through to error throw
  }

  throw new Error(`${target.name} did not return a response`);
}

async function detectOllamaModel(baseUrl) {
  try {
    const response = await httpRequestJson(`${baseUrl}/api/tags`, { method: 'GET', timeout: 5000 });
    if (response.status >= 200 && response.status < 300) {
      const parsed = JSON.parse(response.body || '{}');
      const models = Array.isArray(parsed.models) ? parsed.models : [];
      if (models.length > 0) {
        const name = models[0].name || models[0].model;
        if (name) return name;
      }
    }
  } catch (err) {
    return null;
  }
  return null;
}

async function callOllama(message, target) {
  const baseUrl = target.baseUrl.replace(/\/+$/, '');
  const model = target.model || await detectOllamaModel(baseUrl) || 'llama3';

  const payload = JSON.stringify({
    model,
    messages: [
      { role: 'system', content: 'You are part of the 02luka local ensemble. Provide concise, high-signal answers.' },
      { role: 'user', content: message }
    ]
  });

  const response = await httpRequestJson(`${baseUrl}/v1/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: payload,
    timeout: 20000
  });

  if (response.status >= 200 && response.status < 300) {
    let parsed;
    try {
      parsed = response.body ? JSON.parse(response.body) : null;
    } catch (err) {
      parsed = response.body;
    }
    const text = extractTextFromPayload(parsed);
    if (text) {
      return { text, meta: { model, endpoint: '/v1/chat/completions', status: response.status } };
    }
  }

  throw new Error(`${target.name} did not return a response`);
}

async function executeTarget(targetId, message) {
  const target = CHAT_TARGETS[targetId];
  if (!target) {
    throw new Error(`Unknown target: ${targetId}`);
  }

  const startedAt = Date.now();

  if (target.type === 'mcp') {
    const result = await callMcpGateway(message, target);
    return {
      id: target.id,
      name: target.name,
      status: 'ok',
      text: result.text,
      latencyMs: Date.now() - startedAt,
      meta: result.meta
    };
  }

  if (target.type === 'ollama') {
    const result = await callOllama(message, target);
    return {
      id: target.id,
      name: target.name,
      status: 'ok',
      text: result.text,
      latencyMs: Date.now() - startedAt,
      meta: result.meta
    };
  }

  throw new Error(`Target ${target.name} is not actionable`);
}

async function orchestrateChat(message, targetId = 'auto') {
  const selected = CHAT_TARGETS[targetId] || CHAT_TARGETS.auto;
  const delegates = selected.type === 'aggregate' ? selected.delegates : [selected.id];

  const results = [];
  for (const id of delegates) {
    const startedAt = Date.now();
    try {
      const outcome = await executeTarget(id, message);
      results.push(outcome);
    } catch (err) {
      results.push({
        id,
        name: CHAT_TARGETS[id]?.name || id,
        status: 'error',
        error: err.message,
        latencyMs: Date.now() - startedAt
      });
    }
  }

  const successful = results.filter((item) => item.status === 'ok' && item.text);
  const best = successful.find((item) => item.meta?.endpoint !== '/mcp') || successful[0] || null;

  return {
    ok: Boolean(best),
    target: targetId,
    summary: best ? `Selected ${best.name}` : 'No delegates returned a response',
    best: best || null,
    results
  };
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  // CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    });
    return res.end();
  }

  try {
    if (req.method === 'POST' && url.pathname === '/api/chat') {
      let raw = '';
      req.on('data', (chunk) => {
        raw += chunk;
        if (raw.length > 1_000_000) {
          req.destroy();
        }
      });

      req.on('end', async () => {
        try {
          const payload = raw ? JSON.parse(raw) : {};
          const message = (payload.message || payload.prompt || payload.input || '').trim();
          if (!message) {
            return writeJson(res, 400, { error: 'message is required' });
          }

          const targetId = typeof payload.target === 'string' && payload.target.trim()
            ? payload.target.trim()
            : 'auto';

          try {
            const result = await orchestrateChat(message, targetId);
            return writeJson(res, 200, result);
          } catch (err) {
            console.error('[boss-api] chat orchestration failed', err);
            return writeJson(res, 502, { error: 'Chat orchestration failed', detail: err.message });
          }
        } catch (err) {
          return writeJson(res, 400, { error: 'Invalid JSON payload' });
        }
      });
      return;
    }

    if (req.method === 'POST' && url.pathname === '/api/optimize_prompt') {
      let raw = '';
      req.on('data', (chunk) => {
        raw += chunk;
        if (raw.length > 1_000_000) {
          req.destroy();
        }
      });

      req.on('end', async () => {
        try {
          const payload = raw ? JSON.parse(raw) : {};
          const prompt = (payload.prompt || payload.message || '').trim();
          if (!prompt) {
            return writeJson(res, 400, { error: 'prompt is required' });
          }

          try {
            const result = await optimizePrompt(prompt);
            return writeJson(res, 200, result);
          } catch (err) {
            console.error('[boss-api] prompt optimization failed', err);
            return writeJson(res, 502, { error: 'Prompt optimization failed', detail: err.message });
          }
        } catch (err) {
          return writeJson(res, 400, { error: 'Invalid JSON payload' });
        }
      });
      return;
    }

    // /api/list/:folder
    if (req.method === 'GET' && url.pathname.startsWith('/api/list/')) {
      const mailbox = decodeURIComponent(url.pathname.slice('/api/list/'.length));

      if (!mailbox) {
        return writeJson(res, 400, { error: 'Mailbox is required' });
      }

      if (!allowed.has(mailbox)) {
        return writeJson(res, 400, { error: 'Invalid mailbox' });
      }

      const mailboxRoot = path.join(bossRoot, mailbox);
      const relMailbox = path.relative(bossRoot, mailboxRoot);
      if (relMailbox.startsWith('..') || path.isAbsolute(relMailbox)) {
        return writeJson(res, 400, { error: 'Invalid mailbox path' });
      }

      let dirEntries;
      try {
        dirEntries = await fs.readdir(mailboxRoot, { withFileTypes: true });
      } catch (err) {
        if (err.code === 'ENOENT') {
          return writeJson(res, 404, { error: 'Mailbox not found' });
        }
        throw err;
      }

      const files = dirEntries.filter((entry) => entry.isFile() && !entry.name.startsWith('.'));
      const items = await Promise.all(files.map(async (entry) => {
        const filePath = path.join(mailboxRoot, entry.name);
        const stats = await fs.stat(filePath);
        return {
          id: entry.name,
          name: entry.name,
          path: path.relative(repoRoot, filePath),
          size: stats.size,
          updatedAt: stats.mtime.toISOString()
        };
      }));

      return writeJson(res, 200, { mailbox, items });
    }

    // /api/file/:folder/:name
    if (req.method === 'GET' && url.pathname.startsWith('/api/file/')) {
      const segments = url.pathname.split('/').filter(Boolean); // ['api','file',mailbox,...name]
      const mailbox = segments[2] ? decodeURIComponent(segments[2]) : '';
      const nameParts = segments.slice(3).map((part) => decodeURIComponent(part));
      const name = nameParts.join('/');

      if (!mailbox || !name) {
        return writeJson(res, 400, { error: 'Mailbox and filename are required' });
      }

      if (!allowed.has(mailbox)) {
        return writeJson(res, 400, { error: 'Invalid mailbox' });
      }

      const mailboxRoot = path.join(bossRoot, mailbox);
      const relMailbox = path.relative(bossRoot, mailboxRoot);
      if (relMailbox.startsWith('..') || path.isAbsolute(relMailbox)) {
        return writeJson(res, 400, { error: 'Invalid mailbox path' });
      }

      const targetFile = path.join(mailboxRoot, name);
      const relTarget = path.relative(mailboxRoot, targetFile);
      if (relTarget.startsWith('..') || path.isAbsolute(relTarget)) {
        return writeJson(res, 400, { error: 'Invalid filename' });
      }

      try {
        const data = await fs.readFile(targetFile, 'utf8');
        res.writeHead(200, {
          'Content-Type': 'text/plain; charset=utf-8',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(data);
      } catch (err) {
        if (err.code === 'ENOENT') {
          return writeJson(res, 404, { error: 'not found' });
        }
        return writeJson(res, 500, { error: 'Internal Server Error' });
      }
      return;
    }

    return writeJson(res, 404, { error: 'Not Found' });
  } catch (e) {
    console.error('[boss-api]', e.message || e);
    return writeJson(res, 500, { error: 'Internal Server Error' });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`boss-api listening on http://${HOST}:${PORT}`);
});
