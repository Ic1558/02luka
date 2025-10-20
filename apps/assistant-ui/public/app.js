const conversationEl = document.getElementById('conversation');
const traceEl = document.getElementById('trace');
const formEl = document.getElementById('chat-form');
const messageEl = document.getElementById('message');
const feedbackButtons = document.querySelectorAll('[data-feedback]');
const feedbackStatusEl = document.getElementById('feedback-status');

let lastResponse = null;

formEl.addEventListener('submit', async event => {
  event.preventDefault();
  const text = messageEl.value.trim();
  if (!text) {
    return;
  }
  appendMessage('user', text);
  messageEl.value = '';
  messageEl.focus();
  setTrace([]);
  setFeedbackStatus('');

  try {
    const response = await fetch('/rag/query', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-actor': 'ui-user',
        'x-roles': 'knowledge-navigator'
      },
      body: JSON.stringify({ query: text })
    });

    if (!response.ok) {
      const errorPayload = await response.json().catch(() => ({ error: 'Unknown error' }));
      appendMessage('ai', `Error: ${errorPayload.error}`);
      return;
    }

    const payload = await response.json();
    lastResponse = payload;
    appendMessage('ai', payload.answer);
    setTrace(payload.trace || []);
  } catch (err) {
    appendMessage('ai', `Request failed: ${err.message}`);
  }
});

feedbackButtons.forEach(button => {
  button.addEventListener('click', async () => {
    if (!lastResponse) {
      setFeedbackStatus('Send a prompt before leaving feedback.');
      return;
    }
    const kind = 'feedback';
    const text = `Feedback: ${button.dataset.feedback} for query "${lastResponse.query}"`;
    try {
      const response = await fetch('/memory/remember', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-actor': 'ui-user', 'x-roles': 'operations-orchestrator' },
        body: JSON.stringify({
          kind,
          text,
          meta: {
            feedbackType: button.dataset.feedback,
            query: lastResponse.query,
            confidence: lastResponse.confidence
          },
          importance: button.dataset.feedback === 'escalate' ? 0.8 : 0.5
        })
      });
      if (!response.ok) {
        const errorPayload = await response.json().catch(() => ({ error: 'Unknown error' }));
        setFeedbackStatus(`Failed to store feedback: ${errorPayload.error}`);
        return;
      }
      setFeedbackStatus('Feedback captured locally. Sync will occur when connectors configured.');
    } catch (err) {
      setFeedbackStatus(`Feedback failed: ${err.message}`);
    }
  });
});

function appendMessage(author, text) {
  const wrapper = document.createElement('div');
  wrapper.className = `message ${author}`;
  wrapper.innerText = text;
  conversationEl.appendChild(wrapper);
  conversationEl.scrollTop = conversationEl.scrollHeight;
}

function setTrace(entries) {
  traceEl.innerHTML = '';
  entries.forEach(entry => {
    const card = document.createElement('article');
    card.className = 'trace-entry';

    const title = document.createElement('h4');
    title.innerText = `${entry.step}: ${entry.what}`;
    card.appendChild(title);

    const reason = document.createElement('p');
    reason.innerText = `Why: ${entry.why || 'unspecified'}`;
    card.appendChild(reason);

    if (entry.sources?.length) {
      const sources = document.createElement('p');
      sources.innerText = `Sources: ${entry.sources.join(', ')}`;
      card.appendChild(sources);
    }

    if (entry.details) {
      const details = document.createElement('pre');
      details.innerText = JSON.stringify(entry.details, null, 2);
      card.appendChild(details);
    }

    traceEl.appendChild(card);
  });
}

function setFeedbackStatus(message) {
  feedbackStatusEl.innerText = message;
}
