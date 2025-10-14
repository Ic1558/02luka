#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

function readJsonIfExists(filePath) {
  if (!filePath) {
    return {};
  }

  const resolved = path.resolve(filePath);
  if (!fs.existsSync(resolved)) {
    return {};
  }

  try {
    const raw = fs.readFileSync(resolved, 'utf8');
    if (!raw.trim()) {
      return {};
    }
    return JSON.parse(raw);
  } catch (error) {
    console.error(`⚠️  Failed to parse summary file at ${resolved}:`, error.message);
    return {};
  }
}

function normalizeItems(list) {
  if (!Array.isArray(list)) {
    return [];
  }
  return list
    .map((item) => {
      if (item == null) {
        return null;
      }
      if (typeof item === 'string') {
        return { title: item };
      }
      if (typeof item === 'object') {
        const title = item.title || item.name || item.id || 'Untitled';
        const detail = item.detail || item.message || item.description || '';
        return { title, detail };
      }
      return { title: String(item) };
    })
    .filter(Boolean);
}

function renderSection(label, emoji, items) {
  const normalized = normalizeItems(items);
  if (normalized.length === 0) {
    return '';
  }
  const lines = [`${emoji} ${label} (${normalized.length})`];
  normalized.forEach(({ title, detail }) => {
    const bullet = `  • ${title}`;
    if (detail) {
      lines.push(`${bullet}: ${detail}`);
    } else {
      lines.push(bullet);
    }
  });
  return lines.join('\n');
}

function renderOpsSummary(summary = {}) {
  const title = summary.title || 'Ops Summary';
  const okSection = renderSection('OK', '✅', summary.ok || summary.passes);
  const warnSection = renderSection('Warnings', '⚠️', summary.warns || summary.warnings);
  const failSection = renderSection('Failures', '❌', summary.fails || summary.errors);
  const notesSection = renderSection('Notes', '📝', summary.notes);

  return [
    `# ${title}`,
    summary.generatedAt ? `Generated: ${summary.generatedAt}` : '',
    summary.summary ? summary.summary : '',
    okSection,
    warnSection,
    failSection,
    notesSection,
  ]
    .filter((section) => section && section.trim().length > 0)
    .join('\n\n');
}

async function postJson(url, payload) {
  if (typeof fetch !== 'function') {
    throw new Error('Global fetch API is not available in this Node environment.');
  }

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`Request failed (${response.status}): ${text}`);
  }
}

async function notify({
  title = 'Ops Summary Alert',
  summaryText = '',
  warns = [],
  fails = [],
}) {
  const slackWebhook = process.env.SLACK_WEBHOOK;
  const tgToken = process.env.TG_BOT_TOKEN;
  const tgChatId = process.env.TG_CHAT_ID;

  if (!slackWebhook && !(tgToken && tgChatId)) {
    console.info('ℹ️  No alert transport configured (set SLACK_WEBHOOK or TG_BOT_TOKEN + TG_CHAT_ID).');
    return;
  }

  const warnItems = normalizeItems(warns);
  const failItems = normalizeItems(fails);

  const sections = [
    `*${title}*`,
  ];

  if (failItems.length > 0) {
    sections.push('❌ Failures:');
    failItems.forEach(({ title: itemTitle, detail }) => {
      if (detail) {
        sections.push(`  • ${itemTitle}: ${detail}`);
      } else {
        sections.push(`  • ${itemTitle}`);
      }
    });
  }

  if (warnItems.length > 0) {
    sections.push('⚠️ Warnings:');
    warnItems.forEach(({ title: itemTitle, detail }) => {
      if (detail) {
        sections.push(`  • ${itemTitle}: ${detail}`);
      } else {
        sections.push(`  • ${itemTitle}`);
      }
    });
  }

  if (summaryText) {
    sections.push('\n---\n');
    sections.push(summaryText);
  }

  const message = sections.join('\n');

  const promises = [];

  if (slackWebhook) {
    promises.push(
      postJson(slackWebhook, {
        text: message,
      }).catch((error) => {
        console.error('❌ Failed to send Slack alert:', error.message);
        throw error;
      }),
    );
  }

  if (tgToken && tgChatId) {
    const tgUrl = `https://api.telegram.org/bot${tgToken}/sendMessage`;
    promises.push(
      postJson(tgUrl, {
        chat_id: tgChatId,
        text: message,
      }).catch((error) => {
        console.error('❌ Failed to send Telegram alert:', error.message);
        throw error;
      }),
    );
  }

  await Promise.all(promises);
  console.info('✅ Alert notification sent.');
}

async function run() {
  const summaryPath = process.argv[2] || process.env.REPORTBOT_SUMMARY_PATH;
  const summary = {
    ...readJsonIfExists(summaryPath),
  };

  const warns = summary.warns || summary.warnings || [];
  const fails = summary.fails || summary.errors || [];
  const output = renderOpsSummary(summary);

  console.log(output);

  if ((warns && warns.length > 0) || (fails && fails.length > 0)) {
    try {
      await notify({
        title: summary.title || 'Ops Summary Alert',
        summaryText: output,
        warns,
        fails,
      });
    } catch (error) {
      console.error('⚠️  Notification dispatch failed:', error.message);
    }
  }
}

if (require.main === module) {
  run().catch((error) => {
    console.error('❌ Reportbot run failed:', error);
    process.exit(1);
  });
}

module.exports = {
  notify,
  renderOpsSummary,
  normalizeItems,
  run,
};
