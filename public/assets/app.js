const modelSelect = document.getElementById('model-select');
const functionSelect = document.getElementById('function-select');
const functionList = document.getElementById('function-list');
const modelDetails = document.getElementById('model-details');
const transcript = document.getElementById('transcript');
const interactionForm = document.getElementById('interaction-form');
const promptInput = document.getElementById('prompt-input');
const paramsInput = document.getElementById('params-input');
const sendButton = document.getElementById('send-button');
const statusPill = document.getElementById('stub-status');
const entryTemplate = document.getElementById('transcript-entry-template');
const functionHint = document.getElementById('function-hint');

const state = {
  models: [],
  functions: [],
};

async function fetchJSON(url, options) {
  const response = await fetch(url, options);
  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || `${response.status} ${response.statusText}`);
  }
  return response.json();
}

function setStatus(state, detail) {
  statusPill.dataset.state = state;
  statusPill.textContent = detail;
}

function hydrateModels(models) {
  state.models = models;
  modelSelect.innerHTML = '';
  models.forEach((model) => {
    const option = document.createElement('option');
    option.value = model.id;
    option.textContent = `${model.name}`;
    option.dataset.description = model.description || '';
    option.dataset.provider = model.provider || '';
    option.dataset.capabilities = (model.capabilities || []).join(',');
    modelSelect.appendChild(option);
  });
  if (models.length > 0) {
    modelSelect.value = models[0].id;
    renderModelDetails(models[0]);
  }
}

function renderModelDetails(model) {
  const parts = [];
  if (model.provider) {
    parts.push(`<strong>Provider:</strong> ${escapeHtml(model.provider)}`);
  }
  if (model.capabilities?.length) {
    parts.push(`<strong>Capabilities:</strong> ${escapeHtml(model.capabilities.join(', '))}`);
  }
  if (model.description) {
    parts.push(escapeHtml(model.description));
  }
  modelDetails.innerHTML = parts.join('<br>');
}

function hydrateFunctions(functions) {
  state.functions = functions;
  functionSelect.innerHTML = '';
  functionList.innerHTML = '';

  functions.forEach((fn) => {
    const option = document.createElement('option');
    option.value = fn.id;
    option.textContent = fn.label;
    functionSelect.appendChild(option);

    const listItem = document.createElement('li');
    listItem.innerHTML = `
      <button type="button" class="ghost" data-function-id="${fn.id}">
        <div class="function-label">${fn.label}</div>
        <div class="function-description">${fn.description}</div>
      </button>
    `;
    functionList.appendChild(listItem);
  });

  if (functions.length > 0) {
    functionSelect.value = functions[0].id;
    updateFunctionHint(functions[0].id);
    highlightFunction(functions[0].id);
  }
}

function updateFunctionHint(functionId) {
  const target = state.functions.find((fn) => fn.id === functionId);
  if (!target) {
    functionHint.textContent = '';
    return;
  }
  functionHint.textContent = target.description || '';
}

function highlightFunction(functionId) {
  const buttons = functionList.querySelectorAll('button[data-function-id]');
  buttons.forEach((button) => {
    if (button.dataset.functionId === functionId) {
      button.classList.add('active');
    } else {
      button.classList.remove('active');
    }
  });
}

function appendMessage(kind, meta, body) {
  const entry = entryTemplate.content.cloneNode(true);
  const article = entry.querySelector('.message');
  article.dataset.kind = kind;
  const header = entry.querySelector('.message-meta');
  const content = entry.querySelector('.message-body');
  header.textContent = meta;
  content.innerHTML = body;
  transcript.appendChild(entry);
  transcript.scrollTop = transcript.scrollHeight;
}

function safeJsonParse(value) {
  if (!value.trim()) {
    return {};
  }
  try {
    return JSON.parse(value);
  } catch (error) {
    throw new Error(`Params must be valid JSON. ${error.message}`);
  }
}

function formatResult(result) {
  return `<pre>${escapeHtml(JSON.stringify(result, null, 2))}</pre>`;
}

function escapeHtml(unsafe) {
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

async function initialise() {
  try {
    const [models, functions, status] = await Promise.all([
      fetchJSON('/api/models'),
      fetchJSON('/api/functions'),
      fetchJSON('/api/status'),
    ]);
    hydrateModels(models);
    hydrateFunctions(functions);

    let statusMessage = 'Stub offline';
    if (status.ok) {
      if (status.details && typeof status.details === 'object' && status.details.status) {
        statusMessage = `Stub: ${status.details.status}`;
      } else {
        statusMessage = 'Stub online';
      }
    } else if (status.details) {
      statusMessage = `Stub offline (${typeof status.details === 'string' ? status.details : 'see console'})`;
      console.warn('[ui] stub status detail:', status.details);
    }
    setStatus(status.ok ? 'online' : 'offline', statusMessage);
  } catch (error) {
    console.error(error);
    setStatus('offline', 'Stub unavailable');
  }
}

modelSelect.addEventListener('change', (event) => {
  const modelId = event.target.value;
  const selected = state.models.find((model) => model.id === modelId);
  if (selected) {
    renderModelDetails(selected);
  }
});

functionList.addEventListener('click', (event) => {
  const button = event.target.closest('button[data-function-id]');
  if (!button) return;
  functionSelect.value = button.dataset.functionId;
  updateFunctionHint(button.dataset.functionId);
  highlightFunction(button.dataset.functionId);
});

functionSelect.addEventListener('change', (event) => {
  updateFunctionHint(event.target.value);
  highlightFunction(event.target.value);
});

interactionForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const modelId = modelSelect.value;
  const functionId = functionSelect.value;
  const prompt = promptInput.value.trim();

  if (!prompt) {
    alert('Please provide a prompt to send to the selected function.');
    return;
  }

  let extraParams;
  try {
    extraParams = safeJsonParse(paramsInput.value);
  } catch (error) {
    alert(error.message);
    return;
  }

  const payload = {
    model: modelId,
    intent: functionId,
    prompt,
    params: extraParams,
  };

  appendMessage(
    'user',
    `${modelId} • ${functionId}`,
    escapeHtml(prompt)
  );

  sendButton.disabled = true;
  sendButton.textContent = 'Running…';

  try {
    const response = await fetchJSON('/api/execute', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    appendMessage('assistant', `${response.intent} • ${response.duration_ms}ms`, formatResult(response));
  } catch (error) {
    appendMessage('assistant', 'Error', escapeHtml(error.message));
  } finally {
    sendButton.disabled = false;
    sendButton.textContent = 'Run Function';
  }
});

initialise();
