/* Semantic chunking - split documents by headers/sections */

const path = require('path');

/**
 * Split markdown content into semantic chunks
 * @param {string} content - Markdown content
 * @param {object} metadata - Document metadata (filepath, etc.)
 * @returns {Array<object>} - Array of chunks with metadata
 */
function semanticChunk(content, metadata = {}) {
  const filepath = metadata.filepath || 'unknown';
  const filename = path.basename(filepath, path.extname(filepath));

  // Parse markdown into sections
  const sections = parseMarkdownSections(content);

  // Convert sections to chunks with context
  const chunks = [];
  for (let i = 0; i < sections.length; i++) {
    const section = sections[i];

    // Build hierarchy context (parent headers)
    const hierarchy = buildHierarchy(sections, i);

    // Format chunk text with context
    const chunkText = formatChunkWithContext(filename, hierarchy, section);

    // Extract tags and calculate importance
    const tags = extractTags(section.content);
    const importance = calculateImportance(filepath, section, tags);

    chunks.push({
      doc_path: filepath,
      chunk_index: i,
      text: chunkText,
      hierarchy: hierarchy.map(h => h.text),
      section: section.header || '(intro)',
      tags,
      importance,
      metadata: {
        level: section.level,
        wordCount: section.content.split(/\s+/).length,
        hasCode: section.content.includes('```'),
        hasList: section.content.includes('\n- ') || section.content.includes('\n* ')
      }
    });
  }

  return chunks;
}

/**
 * Parse markdown into sections by headers
 * @param {string} content - Markdown text
 * @returns {Array<object>} - Sections with headers and content
 */
function parseMarkdownSections(content) {
  const lines = content.split('\n');
  const sections = [];
  let currentSection = null;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const headerMatch = line.match(/^(#{1,6})\s+(.+)$/);

    if (headerMatch) {
      // Save previous section
      if (currentSection) {
        sections.push(currentSection);
      }

      // Start new section
      currentSection = {
        level: headerMatch[1].length,
        header: headerMatch[2].trim(),
        content: '',
        lineStart: i
      };
    } else if (currentSection) {
      currentSection.content += line + '\n';
    } else {
      // Content before first header
      if (!sections.length || !sections[0] || sections[0].header) {
        sections.unshift({
          level: 0,
          header: null,
          content: line + '\n',
          lineStart: 0
        });
        currentSection = sections[0];
      } else {
        sections[0].content += line + '\n';
      }
    }
  }

  // Save last section
  if (currentSection && !sections.includes(currentSection)) {
    sections.push(currentSection);
  }

  return sections.filter(s => s.content.trim().length > 0);
}

/**
 * Build header hierarchy for a section
 * @param {Array<object>} sections - All sections
 * @param {number} index - Current section index
 * @returns {Array<object>} - Parent headers
 */
function buildHierarchy(sections, index) {
  const current = sections[index];
  const hierarchy = [];

  // Walk backwards to find parent headers
  for (let i = index - 1; i >= 0; i--) {
    const section = sections[i];
    if (section.level < current.level) {
      hierarchy.unshift({ level: section.level, text: section.header });
      if (section.level === 1) break; // Stop at top-level header
    }
  }

  return hierarchy;
}

/**
 * Format chunk text with document and hierarchy context
 * @param {string} filename - Document filename
 * @param {Array<object>} hierarchy - Parent headers
 * @param {object} section - Current section
 * @returns {string} - Formatted chunk text
 */
function formatChunkWithContext(filename, hierarchy, section) {
  const parts = [`# ${filename}`];

  // Add hierarchy
  hierarchy.forEach((h, i) => {
    parts.push(`${'#'.repeat(i + 2)} ${h.text}`);
  });

  // Add current section header
  if (section.header) {
    const level = Math.max(2, hierarchy.length + 2);
    parts.push(`${'#'.repeat(level)} ${section.header}`);
  }

  parts.push(''); // Blank line
  parts.push(section.content.trim());

  return parts.join('\n');
}

/**
 * Extract tags from content (keywords, code blocks, etc.)
 * @param {string} content - Section content
 * @returns {Array<string>} - Extracted tags
 */
function extractTags(content) {
  const tags = new Set();

  // Extract code block languages
  const codeBlocks = content.match(/```(\w+)/g);
  if (codeBlocks) {
    codeBlocks.forEach(block => {
      const lang = block.replace('```', '');
      if (lang) tags.add(`lang:${lang}`);
    });
  }

  // Extract special markers
  if (content.match(/\b(TODO|FIXME|HACK|XXX)\b/)) tags.add('needs-attention');
  if (content.match(/✅|PASS|SUCCESS/i)) tags.add('success');
  if (content.match(/❌|FAIL|ERROR/i)) tags.add('error');
  if (content.match(/Phase \d+/i)) tags.add('phase-doc');
  if (content.match(/\b(API|endpoint|route)\b/i)) tags.add('api');
  if (content.match(/\b(performance|optimization|speed)\b/i)) tags.add('performance');

  return Array.from(tags);
}

/**
 * Calculate importance score for a chunk
 * @param {string} filepath - Document path
 * @param {object} section - Section data
 * @param {Array<string>} tags - Extracted tags
 * @returns {number} - Importance (0-1)
 */
function calculateImportance(filepath, section, tags) {
  let score = 0.5; // Base score

  // High importance paths
  if (filepath.includes('/docs/PHASE')) score += 0.3;
  if (filepath.includes('/g/reports/')) score += 0.2;
  if (filepath.includes('README') || filepath.includes('QUICK_REFERENCE')) score += 0.2;

  // Header level (h1 > h6)
  if (section.level === 1) score += 0.15;
  else if (section.level === 2) score += 0.1;
  else if (section.level === 3) score += 0.05;

  // Content quality signals
  const wordCount = section.content.split(/\s+/).length;
  if (wordCount > 100) score += 0.1;
  if (wordCount > 300) score += 0.1;

  // Tags
  if (tags.includes('needs-attention')) score += 0.15;
  if (tags.includes('api')) score += 0.1;
  if (tags.includes('performance')) score += 0.1;

  return Math.min(1.0, Math.max(0.1, score));
}

module.exports = {
  semanticChunk,
  parseMarkdownSections,
  buildHierarchy,
  extractTags,
  calculateImportance
};
