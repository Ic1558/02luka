const API_BASE = 'http://127.0.0.1:4000';

function setActivePage(page) {
  document.querySelectorAll('.page').forEach((section) => {
    section.classList.toggle('active', section.id === `page-${page}`);
  });
}

document.querySelectorAll('nav button[data-page]').forEach((button) => {
  button.addEventListener('click', () => {
    setActivePage(button.dataset.page);
  });
});

const outputEl = document.getElementById('chatops-output');
const preflightBtn = document.getElementById('btn-preflight');
const driftBtn = document.getElementById('btn-drift');
const gateBtn = document.getElementById('btn-gate');
const gateScopeSelect = document.getElementById('gate-scope');

function displayResult(title, result) {
  const payload = {
    title,
    timestamp: new Date().toISOString(),
    result,
  };
  outputEl.textContent = JSON.stringify(payload, null, 2);
}

async function postJSON(path, body) {
  const response = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(errorText || response.statusText);
  }
  return response.json();
}

preflightBtn?.addEventListener('click', async () => {
  displayResult('preflight (running)', { status: 'pending' });
  try {
    const data = await postJSON('/api/validate/preflight');
    displayResult('preflight', data);
  } catch (error) {
    displayResult('preflight (error)', { error: error.message });
  }
});

driftBtn?.addEventListener('click', async () => {
  displayResult('drift_guard (running)', { status: 'pending' });
  try {
    const data = await postJSON('/api/validate/drift_guard');
    displayResult('drift_guard', data);
  } catch (error) {
    displayResult('drift_guard (error)', { error: error.message });
  }
});

gateBtn?.addEventListener('click', async () => {
  displayResult('clc_gate (running)', { status: 'pending' });
  try {
    const scope = gateScopeSelect?.value || 'precommit';
    const data = await postJSON('/api/validate/gate', { scope });
    displayResult('clc_gate', data);
  } catch (error) {
    displayResult('clc_gate (error)', { error: error.message });
  }
});

// Initialize default page
setActivePage('dashboard');
