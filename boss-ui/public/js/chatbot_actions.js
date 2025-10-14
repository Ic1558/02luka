    // Get elements
    const messageInput = document.getElementById('messageInput');
    const sendButton = document.getElementById('sendButton');
    const messagesContainer = document.getElementById('messages');
    const gatewaySelect = document.getElementById('gateway');

    const GATEWAY_PROFILES = [
      {
        id: 'mcp',
        match: /5012$/,
        name: 'MCP Docker',
        type: 'mcp',
        tips: 'Use this gateway for local MCP tools and general automation.'
      },
      {
        id: 'fastvlm',
        match: /8765$/,
        name: 'FastVLM Vision',
        type: 'vision',
        tips: 'Great for describing or questioning the contents of an image.'
      },
      {
        id: 'ollama',
        match: /11434$/,
        name: 'Ollama',
        type: 'ollama',
        tips: 'Run local language models with `ollama run <model-name>`.'
      }
    ];

    // Auto-resize textarea
    messageInput.addEventListener('input', () => {
      messageInput.style.height = 'auto';
      messageInput.style.height = Math.min(messageInput.scrollHeight, 100) + 'px';
      updateSendButton();
    });

    // Update send button state
    function updateSendButton() {
      const hasText = messageInput.value.trim().length > 0;
      sendButton.disabled = !hasText;
    }

    // Send message
    async function sendMessage() {
      const text = messageInput.value.trim();
      if (!text) return;

      // Add user message
      addMessage('user', text);

      // Clear input
      messageInput.value = '';
      messageInput.style.height = 'auto';
      updateSendButton();

      // Add bot response
      try {
        const gateway = gatewaySelect.value;
        const plan = planGatewayAction(text, gateway);
        const actionResult = await executeGatewayAction(plan, gateway);
        addMessage('bot', actionResult);
      } catch (err) {
        addMessage('bot', 'Error: ' + err.message);
      }
    }

    // Add message to UI
    function addMessage(type, text) {
      const messageDiv = document.createElement('div');
      messageDiv.className = 'message' + (type === 'user' ? ' user' : '');

      const avatar = document.createElement('div');
      avatar.className = 'avatar';
      avatar.textContent = type === 'user' ? 'U' : 'L';

      const content = document.createElement('div');
      content.className = 'content';
      content.textContent = text;

      messageDiv.appendChild(avatar);
      messageDiv.appendChild(content);

      messagesContainer.appendChild(messageDiv);
      messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }

    // Handle Enter key
    messageInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
      }
    });

    // Handle button click
    sendButton.addEventListener('click', sendMessage);

    // Initial state
    updateSendButton();
    messageInput.focus();

    // Log for debugging
    console.log('Luka UI initialized. Elements found:', {
      input: !!messageInput,
      button: !!sendButton,
      messages: !!messagesContainer
    });

    function planGatewayAction(text, gatewayUrl) {
      const normalizedText = text.toLowerCase();
      const profile = getGatewayProfile(gatewayUrl);

      if (/(health|status|ping|alive|running|up|check)/.test(normalizedText)) {
        return {
          summary: `Checking ${profile.name} health...`,
          autoExecute: true,
          endpoint: '/health',
          method: 'GET',
          success: (payload) => formatHealthResponse(payload, profile),
          failure: (payload) => formatFailureMessage(payload)
        };
      }

      if (/(info|capabilities|version|about)/.test(normalizedText)) {
        return {
          summary: `Requesting info from ${profile.name}...`,
          autoExecute: true,
          endpoint: '/info',
          method: 'GET',
          success: (payload) => formatInfoResponse(payload),
          failure: (payload) => formatFailureMessage(payload)
        };
      }

      if (profile.type === 'vision' && /(image|photo|picture|vision|see|describe|look)/.test(normalizedText)) {
        const analyzeUrl = joinGatewayPath(gatewayUrl, '/analyze');
        const batchUrl = joinGatewayPath(gatewayUrl, '/batch-analyze');
        return {
          summary: `${profile.name} can analyze images for you.`,
          autoExecute: false,
          response: [
            `To describe an image, send a POST request to ${analyzeUrl} with form-data fields \`file\` and \`prompt\`.`,
            `Need multiple images? Use ${batchUrl}.`
          ].join('\n')
        };
      }

      if (profile.type === 'ollama' && /(list|show|available).*model/.test(normalizedText)) {
        return {
          summary: `Querying available Ollama models...`,
          autoExecute: true,
          endpoint: '/api/tags',
          method: 'GET',
          success: (payload) => formatOllamaModels(payload),
          failure: (payload) => formatFailureMessage(payload)
        };
      }

      return {
        summary: `No built-in action matched for ${profile.name}.`,
        autoExecute: false,
        response: buildFallbackMessage(profile)
      };
    }

    function executeGatewayAction(plan, gatewayUrl) {
      if (!plan) {
        return Promise.resolve('No plan available for this request.');
      }

      const lines = [plan.summary].filter(Boolean);

      if (!plan.autoExecute) {
        if (plan.response) {
          lines.push(plan.response);
        }
        return Promise.resolve(lines.join('\n'));
      }

      const targetUrl = joinGatewayPath(gatewayUrl, plan.endpoint || '');
      const options = {
        method: plan.method || 'GET',
        headers: Object.assign({}, plan.headers || {})
      };

      if (plan.body !== undefined) {
        const isObjectBody = typeof plan.body === 'object' && !(plan.body instanceof FormData);
        if (isObjectBody && !options.headers['Content-Type']) {
          options.headers['Content-Type'] = 'application/json';
        }
        options.body = isObjectBody ? JSON.stringify(plan.body) : plan.body;
      }

      return fetch(targetUrl, options)
        .then(async (response) => {
          const payload = await parseResponsePayload(response);
          if (!response.ok) {
            const failureMessage = plan.failure
              ? plan.failure(payload, response)
              : `Request failed with status ${response.status}.`;
            lines.push(failureMessage);
            return lines.join('\n');
          }

          const successMessage = plan.success
            ? plan.success(payload, response)
            : formatGenericSuccess(payload);
          lines.push(successMessage);
          return lines.join('\n');
        })
        .catch((error) => {
          const failureMessage = plan.failure
            ? plan.failure(error)
            : `Request error: ${error.message}`;
          lines.push(failureMessage);
          return lines.join('\n');
        });
    }

    function getGatewayProfile(gatewayUrl) {
      const normalized = (gatewayUrl || '').replace(/\/+$/, '');
      const profile = GATEWAY_PROFILES.find((item) =>
        typeof item.match === 'string' ? item.match === normalized : item.match.test(normalized)
      );

      if (profile) {
        return profile;
      }

      return {
        id: 'generic',
        match: null,
        name: normalized || 'Selected gateway',
        type: 'generic',
        tips: 'Connect the gateway and try running a health check to verify it is reachable.'
      };
    }

    function joinGatewayPath(base, path) {
      if (!base) return path;
      const trimmedBase = base.replace(/\/+$/, '');
      const trimmedPath = path.replace(/^\/+/, '');
      return `${trimmedBase}/${trimmedPath}`;
    }

    function parseResponsePayload(response) {
      const contentType = response.headers.get('content-type') || '';
      if (contentType.includes('application/json')) {
        return response.json();
      }
      return response.text();
    }

    function formatHealthResponse(payload, profile) {
      if (!payload) {
        return 'Health endpoint returned an empty response.';
      }

      if (typeof payload === 'string') {
        return payload.slice(0, 400);
      }

      if (typeof payload === 'object') {
        const status = payload.status || payload.state || payload.health || payload.ok;
        const details = Object.entries(payload)
          .filter(([key]) => !['status', 'state', 'health', 'ok'].includes(key))
          .slice(0, 5)
          .map(([key, value]) => `${key}: ${formatValue(value)}`);

        return [
          status ? `Status: ${status}` : 'Health endpoint responded.',
          details.length ? `Details:\n- ${details.join('\n- ')}` : null,
          profile.tips ? `Tip: ${profile.tips}` : null
        ]
          .filter(Boolean)
          .join('\n');
      }

      return 'Health endpoint responded, but the data format was unexpected.';
    }

    function formatInfoResponse(payload) {
      if (!payload) {
        return 'Info endpoint returned an empty response.';
      }

      if (typeof payload === 'string') {
        return payload.slice(0, 400);
      }

      if (typeof payload === 'object') {
        const entries = Object.entries(payload)
          .slice(0, 6)
          .map(([key, value]) => `${key}: ${formatValue(value)}`);
        return entries.length ? entries.join('\n') : 'Info endpoint responded with metadata.';
      }

      return 'Info endpoint responded, but the data format was unexpected.';
    }

    function formatOllamaModels(payload) {
      if (!payload) {
        return 'No models were returned by Ollama. Make sure it is running.';
      }

      const models = Array.isArray(payload.models) ? payload.models : payload;
      if (!Array.isArray(models)) {
        return formatGenericSuccess(payload);
      }

      if (models.length === 0) {
        return 'Ollama returned zero models. Install one with `ollama pull <model>`.';
      }

      const names = models
        .map((item) => (typeof item === 'string' ? item : item && item.name))
        .filter(Boolean);

      if (!names.length) {
        return 'Ollama models endpoint responded, but no names were provided.';
      }

      const displayNames = names.slice(0, 8).join(', ');
      const more = names.length > 8 ? ` ...and ${names.length - 8} more.` : '';
      return `Available models: ${displayNames}${more}`;
    }

    function formatGenericSuccess(payload) {
      if (payload === undefined || payload === null) {
        return 'Request completed with no content.';
      }

      if (typeof payload === 'string') {
        return payload.slice(0, 400);
      }

      return JSON.stringify(payload, null, 2).slice(0, 400);
    }

    function formatFailureMessage(payload) {
      if (!payload) {
        return 'Gateway request failed with no additional details.';
      }

      if (payload instanceof Error) {
        return `Gateway request failed: ${payload.message}`;
      }

      if (typeof payload === 'string') {
        return `Gateway request failed: ${payload.slice(0, 200)}`;
      }

      return `Gateway request failed: ${JSON.stringify(payload).slice(0, 200)}`;
    }

    function formatValue(value) {
      if (value === null) return 'null';
      if (typeof value === 'object') {
        try {
          const json = JSON.stringify(value);
          return json.length > 60 ? `${json.slice(0, 57)}...` : json;
        } catch (err) {
          return '[object]';
        }
      }
      return String(value);
    }

    function buildFallbackMessage(profile) {
      const suggestions = [
        'Try asking for "status" to trigger a health check.'
      ];

      if (profile.type === 'vision') {
        suggestions.push('Mention an image or photo to get FastVLM usage instructions.');
      }

      if (profile.type === 'ollama') {
        suggestions.push('Ask to "list models" to discover the installed Ollama models.');
      }

      return [profile.tips, suggestions.join(' ')].filter(Boolean).join('\n');
    }
