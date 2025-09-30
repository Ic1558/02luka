const gatewaySelect = document.querySelector('#gateway-select');
const pathInput = document.querySelector('#path-input');
const methodSelect = document.querySelector('#method-select');
const payloadInput = document.querySelector('#payload-input');
const headersInput = document.querySelector('#headers-input');
const timeoutInput = document.querySelector('#timeout-input');
const statusIndicator = document.querySelector('#status-indicator');
const responseOutput = document.querySelector('#response-output');
const configTimestamp = document.querySelector('#config-timestamp');
const copyResponseButton = document.querySelector('#copy-response');
const chatForm = document.querySelector('#chat-form');
const clearButton = document.querySelector('#clear-button');

function setStatus(message, variant = 'info') {
  statusIndicator.textContent = message;
  statusIndicator.classList.remove('status--ok', 'status--error');

  if (variant === 'ok') {
    statusIndicator.classList.add('status--ok');
  } else if (variant === 'error') {
    statusIndicator.classList.add('status--error');
  }
}

function safeParseJson(text) {
  if (!text || !text.trim()) {
    return undefined;
  }

  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Error(`Invalid JSON: ${error.message}`);
  }
}

function populateGateways(gateways) {
  gatewaySelect.innerHTML = '';

  const entries = Object.entries(gateways);

  if (entries.length === 0) {
    const option = document.createElement('option');
    option.value = '';
    option.textContent = 'No gateways available';
    gatewaySelect.appendChild(option);
    gatewaySelect.disabled = true;
    return;
  }

  for (const [key, url] of entries) {
    const option = document.createElement('option');
    option.value = key;
    option.textContent = `${key} → ${url}`;
    gatewaySelect.appendChild(option);
  }

  gatewaySelect.disabled = false;
}

async function loadConfig() {
  try {
    const response = await fetch('/config');
    if (!response.ok) {
      throw new Error(`Request failed (${response.status})`);
    }

    const payload = await response.json();
    populateGateways(payload.gateways || {});
    configTimestamp.textContent = new Date(payload.updatedAt || Date.now()).toLocaleString();
    setStatus('Connected to boss-api', 'ok');
  } catch (error) {
    console.error('Failed to load config', error);
    populateGateways({});
    setStatus(`Config error: ${error.message}`, 'error');
  }
}

function formatResponse(data) {
  if (data == null) {
    return 'No response payload.';
  }

  if (typeof data === 'string') {
    return data;
  }

  return JSON.stringify(data, null, 2);
}

chatForm.addEventListener('submit', async (event) => {
  event.preventDefault();

  const gateway = gatewaySelect.value;
  const pathValue = pathInput.value.trim();
  const method = methodSelect.value;
  const timeoutMs = Number.parseInt(timeoutInput.value, 10) || 90_000;

  if (!gateway) {
    setStatus('Select a gateway before sending.', 'error');
    return;
  }

  if (!pathValue) {
    setStatus('Path is required.', 'error');
    return;
  }

  let headers;
  let payload;

  try {
    headers = safeParseJson(headersInput.value);
  } catch (error) {
    setStatus(error.message, 'error');
    return;
  }

  try {
    const parsed = safeParseJson(payloadInput.value);
    payload = parsed === undefined ? payloadInput.value : parsed;
  } catch (error) {
    setStatus(error.message, 'error');
    return;
  }

  const requestBody = {
    gateway,
    path: pathValue,
    method,
    timeoutMs
  };

  if (headers) {
    requestBody.headers = headers;
  }

  if (payloadInput.value.trim()) {
    requestBody.payload = payload;
  }

  setStatus('Sending request…');
  responseOutput.textContent = 'Awaiting response…';

  try {
    const response = await fetch('/chat', {
      method: 'POST',
      headers: {
        'content-type': 'application/json'
      },
      body: JSON.stringify(requestBody)
    });

    const data = await response.json().catch(() => null);

    if (!response.ok) {
      throw new Error(data?.error || `Request failed (${response.status})`);
    }

    responseOutput.textContent = formatResponse(data);
    setStatus('Request completed', 'ok');
  } catch (error) {
    console.error('Request error', error);
    responseOutput.textContent = error.message;
    setStatus(`Error: ${error.message}`, 'error');
  }
});

copyResponseButton.addEventListener('click', async () => {
  try {
    await navigator.clipboard.writeText(responseOutput.textContent);
    setStatus('Response copied to clipboard', 'ok');
  } catch (error) {
    console.error('Clipboard error', error);
    setStatus('Unable to copy response', 'error');
  }
});

clearButton.addEventListener('click', () => {
  payloadInput.value = '';
  headersInput.value = '';
  responseOutput.textContent = 'No response yet.';
  setStatus('Cleared payload and response');
});

loadConfig();
