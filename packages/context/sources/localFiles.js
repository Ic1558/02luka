const fs = require('fs');
const path = require('path');

/**
 * @typedef {Object} LoadedDocument
 * @property {string} id Canonical identifier derived from file path.
 * @property {string} title Derived title from first heading or file name.
 * @property {string} content Raw text content of the document.
 * @property {Date} updatedAt Last modified timestamp.
 */

/**
 * Load markdown documents from the repository for offline retrieval.
 * @param {{rootDir: string}} params
 * @returns {LoadedDocument[]}
 */
function loadLocalDocuments({ rootDir }) {
  const files = walkMarkdown(rootDir);
  return files.map(filePath => {
    const absolute = path.resolve(rootDir, filePath);
    let stats;
    try {
      stats = fs.statSync(absolute);
    } catch (err) {
      return null;
    }

    let content = '';
    try {
      content = fs.readFileSync(absolute, 'utf8');
    } catch (err) {
      content = '';
    }

    const titleMatch = content.match(/^#\s+(.+)$/m);
    const title = titleMatch ? titleMatch[1].trim() : path.basename(filePath);

    return {
      id: filePath.replace(/\\/g, '/'),
      title,
      content,
      updatedAt: stats?.mtime ?? new Date(0)
    };
  }).filter(Boolean);
}

/**
 * Recursively walk the root directory for markdown files.
 * @param {string} rootDir
 * @returns {string[]}
 */
function walkMarkdown(rootDir) {
  /** @type {string[]} */
  const results = [];

  const entries = safeReadDir(rootDir);
  for (const entry of entries) {
    const fullPath = path.join(rootDir, entry);
    let stats;
    try {
      stats = fs.statSync(fullPath);
    } catch (err) {
      continue;
    }

    if (stats.isDirectory()) {
      results.push(...walkMarkdown(fullPath));
    } else if (stats.isFile() && entry.endsWith('.md')) {
      results.push(path.relative(rootDir, fullPath));
    }
  }

  return results;
}

/**
 * Safe `fs.readdirSync` wrapper.
 * @param {string} dir
 * @returns {string[]}
 */
function safeReadDir(dir) {
  try {
    return fs.readdirSync(dir);
  } catch (err) {
    return [];
  }
}

module.exports = {
  loadLocalDocuments
};
