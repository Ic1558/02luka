#!/usr/bin/env node
/**
 * Phase 10.3 - Public Docs Publisher
 * Converts g/manuals/*.md to static HTML under /docs/ on Pages
 */

const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
  sourceDir: 'g/manuals',
  outputDir: 'dist/docs',
  assetsDir: 'dist/docs/assets',
  maxDepth: 10,
  excludePatterns: ['_private', '_internal', '_draft', '_wip'],
  includeExtensions: ['.md'],
  title: '02luka Public Documentation',
  description: 'Public knowledge base for 02luka operations and manuals'
};

// Ensure output directories exist
if (!fs.existsSync(CONFIG.outputDir)) {
  fs.mkdirSync(CONFIG.outputDir, { recursive: true });
}
if (!fs.existsSync(CONFIG.assetsDir)) {
  fs.mkdirSync(CONFIG.assetsDir, { recursive: true });
}

/**
 * Simple markdown to HTML converter (no external deps)
 */
function markdownToHtml(markdown) {
  return markdown
    // Headers
    .replace(/^### (.*$)/gim, '<h3>$1</h3>')
    .replace(/^## (.*$)/gim, '<h2>$1</h2>')
    .replace(/^# (.*$)/gim, '<h1>$1</h1>')
    
    // Bold and italic
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.*?)\*/g, '<em>$1</em>')
    
    // Code blocks
    .replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>')
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    
    // Links
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>')
    
    // Lists
    .replace(/^\* (.*$)/gim, '<li>$1</li>')
    .replace(/^\d+\. (.*$)/gim, '<li>$1</li>')
    
    // Line breaks
    .replace(/\n\n/g, '</p><p>')
    .replace(/\n/g, '<br>')
    
    // Wrap in paragraphs
    .replace(/^(.*)$/gm, '<p>$1</p>')
    
    // Clean up empty paragraphs
    .replace(/<p><\/p>/g, '')
    .replace(/<p><br><\/p>/g, '')
    
    // Clean up list items
    .replace(/<p><li>/g, '<li>')
    .replace(/<\/li><\/p>/g, '</li>')
    .replace(/(<li>.*<\/li>)/gs, '<ul>$1</ul>')
    
    // Clean up multiple ul tags
    .replace(/<\/ul><ul>/g, '');
}

/**
 * Generate HTML page template
 */
function generatePageTemplate(title, content, sidebar = '') {
  return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title} - 02luka Docs</title>
    <link rel="stylesheet" href="assets/docs.css">
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🚀</text></svg>">
</head>
<body>
    <div class="container">
        <header class="header">
            <h1><a href="index.html">🚀 02luka Docs</a></h1>
            <p>${CONFIG.description}</p>
            <div class="theme-toggle">
                <button id="theme-toggle" aria-label="Toggle theme">🌙</button>
            </div>
        </header>
        
        <div class="main">
            <nav class="sidebar">
                ${sidebar}
            </nav>
            
            <main class="content">
                <h1>${title}</h1>
                ${content}
            </main>
        </div>
        
        <footer class="footer">
            <p>Generated on ${new Date().toLocaleString()} | <a href="index.html">Back to Index</a></p>
        </footer>
    </div>
    
    <script src="assets/docs.js"></script>
</body>
</html>`;
}

/**
 * Generate sidebar navigation
 */
function generateSidebar(docs) {
  const categories = {};
  
  docs.forEach(doc => {
    const category = doc.category || 'General';
    if (!categories[category]) {
      categories[category] = [];
    }
    categories[category].push(doc);
  });
  
  let sidebar = '<h3>Documentation</h3><ul>';
  
  Object.keys(categories).sort().forEach(category => {
    sidebar += `<li><strong>${category}</strong><ul>`;
    categories[category].forEach(doc => {
      sidebar += `<li><a href="${doc.url}">${doc.title}</a></li>`;
    });
    sidebar += '</ul></li>';
  });
  
  sidebar += '</ul>';
  
  return sidebar;
}

/**
 * Scan directory for markdown files
 */
function scanDirectory(dir, depth = 0) {
  if (depth > CONFIG.maxDepth) return [];
  
  const files = [];
  
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    
    entries.forEach(entry => {
      const fullPath = path.join(dir, entry.name);
      const relativePath = path.relative(CONFIG.sourceDir, fullPath);
      
      // Skip excluded patterns
      if (CONFIG.excludePatterns.some(pattern => entry.name.includes(pattern))) {
        return;
      }
      
      if (entry.isDirectory()) {
        files.push(...scanDirectory(fullPath, depth + 1));
      } else if (entry.isFile() && CONFIG.includeExtensions.includes(path.extname(entry.name))) {
        files.push({
          fullPath,
          relativePath,
          name: entry.name,
          category: path.dirname(relativePath).split(path.sep)[0] || 'General'
        });
      }
    });
  } catch (error) {
    console.error(`⚠️ Error scanning ${dir}:`, error.message);
  }
  
  return files;
}

/**
 * Process a single markdown file
 */
function processMarkdownFile(file) {
  try {
    const content = fs.readFileSync(file.fullPath, 'utf8');
    const html = markdownToHtml(content);
    
    // Extract title from first h1 or filename
    const titleMatch = content.match(/^# (.+)$/m);
    const title = titleMatch ? titleMatch[1] : path.basename(file.name, '.md');
    
    // Generate output path
    const outputPath = path.join(CONFIG.outputDir, file.relativePath.replace('.md', '.html'));
    const outputDir = path.dirname(outputPath);
    
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    
    return {
      title,
      content: html,
      url: file.relativePath.replace('.md', '.html'),
      category: file.category,
      size: content.length,
      modified: fs.statSync(file.fullPath).mtime
    };
  } catch (error) {
    console.error(`❌ Error processing ${file.fullPath}:`, error.message);
    return null;
  }
}

/**
 * Generate index.html
 */
function generateIndex(docs) {
  const sidebar = generateSidebar(docs);
  
  let content = `
    <div class="search-box">
      <input type="text" id="search" placeholder="Search documentation..." />
      <button id="search-btn">🔍</button>
    </div>
    
    <div class="stats">
      <div class="stat">
        <strong>${docs.length}</strong> documents
      </div>
      <div class="stat">
        <strong>${new Set(docs.map(d => d.category)).size}</strong> categories
      </div>
      <div class="stat">
        <strong>${Math.round(docs.reduce((acc, d) => acc + d.size, 0) / 1024)}KB</strong> total content
      </div>
    </div>
    
    <h2>Documentation Index</h2>
    <div id="docs-list">
  `;
  
  const categories = {};
  docs.forEach(doc => {
    if (!categories[doc.category]) {
      categories[doc.category] = [];
    }
    categories[doc.category].push(doc);
  });
  
  Object.keys(categories).sort().forEach(category => {
    content += `<h3>${category}</h3><ul>`;
    categories[category].forEach(doc => {
      content += `<li><a href="${doc.url}">${doc.title}</a> <span class="doc-meta">(${Math.round(doc.size / 1024)}KB)</span></li>`;
    });
    content += '</ul>';
  });
  
  content += '</div>';
  
  return generatePageTemplate('Documentation Index', content, sidebar);
}

/**
 * Generate CSS assets
 */
function generateCSS() {
  const css = `
/* 02luka Docs CSS */
:root {
  --bg-color: #ffffff;
  --text-color: #333333;
  --accent-color: #2c3e50;
  --border-color: #e0e0e0;
  --sidebar-bg: #f8f9fa;
  --link-color: #3498db;
  --code-bg: #f4f4f4;
}

[data-theme="dark"] {
  --bg-color: #1a1a1a;
  --text-color: #e0e0e0;
  --accent-color: #3498db;
  --border-color: #404040;
  --sidebar-bg: #2d2d2d;
  --link-color: #5dade2;
  --code-bg: #333333;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  line-height: 1.6;
  color: var(--text-color);
  background-color: var(--bg-color);
  transition: all 0.3s ease;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.header {
  background: var(--accent-color);
  color: white;
  padding: 20px;
  text-align: center;
  position: relative;
}

.header h1 a {
  color: white;
  text-decoration: none;
}

.header p {
  margin-top: 10px;
  opacity: 0.9;
}

.theme-toggle {
  position: absolute;
  top: 20px;
  right: 20px;
}

.theme-toggle button {
  background: none;
  border: none;
  color: white;
  font-size: 1.5em;
  cursor: pointer;
  padding: 5px;
  border-radius: 50%;
  transition: background 0.3s ease;
}

.theme-toggle button:hover {
  background: rgba(255, 255, 255, 0.2);
}

.main {
  display: flex;
  flex: 1;
}

.sidebar {
  width: 250px;
  background: var(--sidebar-bg);
  padding: 20px;
  border-right: 1px solid var(--border-color);
  overflow-y: auto;
}

.sidebar h3 {
  margin-bottom: 15px;
  color: var(--accent-color);
}

.sidebar ul {
  list-style: none;
}

.sidebar li {
  margin-bottom: 5px;
}

.sidebar a {
  color: var(--link-color);
  text-decoration: none;
  display: block;
  padding: 5px 0;
  transition: color 0.3s ease;
}

.sidebar a:hover {
  color: var(--accent-color);
}

.content {
  flex: 1;
  padding: 30px;
  max-width: 800px;
}

.content h1 {
  color: var(--accent-color);
  margin-bottom: 20px;
  border-bottom: 2px solid var(--border-color);
  padding-bottom: 10px;
}

.content h2 {
  color: var(--accent-color);
  margin: 30px 0 15px 0;
}

.content h3 {
  color: var(--accent-color);
  margin: 20px 0 10px 0;
}

.content p {
  margin-bottom: 15px;
}

.content ul, .content ol {
  margin-bottom: 15px;
  padding-left: 20px;
}

.content li {
  margin-bottom: 5px;
}

.content code {
  background: var(--code-bg);
  padding: 2px 6px;
  border-radius: 3px;
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
  font-size: 0.9em;
}

.content pre {
  background: var(--code-bg);
  padding: 15px;
  border-radius: 5px;
  overflow-x: auto;
  margin: 15px 0;
}

.content pre code {
  background: none;
  padding: 0;
}

.content a {
  color: var(--link-color);
  text-decoration: none;
}

.content a:hover {
  text-decoration: underline;
}

.search-box {
  display: flex;
  margin-bottom: 20px;
  gap: 10px;
}

.search-box input {
  flex: 1;
  padding: 10px;
  border: 1px solid var(--border-color);
  border-radius: 5px;
  background: var(--bg-color);
  color: var(--text-color);
}

.search-box button {
  padding: 10px 15px;
  background: var(--accent-color);
  color: white;
  border: none;
  border-radius: 5px;
  cursor: pointer;
}

.stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 15px;
  margin-bottom: 30px;
}

.stat {
  background: var(--sidebar-bg);
  padding: 15px;
  border-radius: 5px;
  text-align: center;
}

.doc-meta {
  color: #666;
  font-size: 0.9em;
}

.footer {
  background: var(--sidebar-bg);
  padding: 20px;
  text-align: center;
  border-top: 1px solid var(--border-color);
  margin-top: auto;
}

.footer a {
  color: var(--link-color);
  text-decoration: none;
}

@media (max-width: 768px) {
  .main {
    flex-direction: column;
  }
  
  .sidebar {
    width: 100%;
    border-right: none;
    border-bottom: 1px solid var(--border-color);
  }
  
  .content {
    padding: 20px;
  }
  
  .stats {
    grid-template-columns: 1fr;
  }
}
`;

  fs.writeFileSync(path.join(CONFIG.assetsDir, 'docs.css'), css);
  console.log(`✅ Generated ${path.join(CONFIG.assetsDir, 'docs.css')}`);
}

/**
 * Generate JavaScript assets
 */
function generateJS() {
  const js = `
// 02luka Docs JavaScript
document.addEventListener('DOMContentLoaded', function() {
  // Theme toggle
  const themeToggle = document.getElementById('theme-toggle');
  const body = document.body;
  
  // Load saved theme
  const savedTheme = localStorage.getItem('theme') || 'light';
  body.setAttribute('data-theme', savedTheme);
  themeToggle.textContent = savedTheme === 'dark' ? '☀️' : '🌙';
  
  themeToggle.addEventListener('click', function() {
    const currentTheme = body.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    
    body.setAttribute('data-theme', newTheme);
    themeToggle.textContent = newTheme === 'dark' ? '☀️' : '🌙';
    localStorage.setItem('theme', newTheme);
  });
  
  // Search functionality
  const searchInput = document.getElementById('search');
  const searchBtn = document.getElementById('search-btn');
  const docsList = document.getElementById('docs-list');
  
  if (searchInput && docsList) {
    const allDocs = Array.from(docsList.querySelectorAll('li'));
    
    function performSearch() {
      const query = searchInput.value.toLowerCase();
      
      allDocs.forEach(doc => {
        const text = doc.textContent.toLowerCase();
        const matches = text.includes(query);
        doc.style.display = matches ? 'block' : 'none';
      });
    }
    
    searchInput.addEventListener('input', performSearch);
    searchBtn.addEventListener('click', performSearch);
    
    // Search on Enter key
    searchInput.addEventListener('keypress', function(e) {
      if (e.key === 'Enter') {
        performSearch();
      }
    });
  }
  
  // Copy link functionality
  document.querySelectorAll('h1, h2, h3').forEach(heading => {
    const id = heading.textContent.toLowerCase().replace(/[^a-z0-9]+/g, '-');
    heading.id = id;
    
    const link = document.createElement('a');
    link.href = '#' + id;
    link.textContent = ' 🔗';
    link.style.opacity = '0';
    link.style.transition = 'opacity 0.3s ease';
    link.style.textDecoration = 'none';
    link.style.marginLeft = '10px';
    
    heading.appendChild(link);
    
    heading.addEventListener('mouseenter', function() {
      link.style.opacity = '1';
    });
    
    heading.addEventListener('mouseleave', function() {
      link.style.opacity = '0';
    });
  });
});
`;

  fs.writeFileSync(path.join(CONFIG.assetsDir, 'docs.js'), js);
  console.log(`✅ Generated ${path.join(CONFIG.assetsDir, 'docs.js')}`);
}

/**
 * Main execution
 */
async function main() {
  console.log('🚀 Phase 10.3 - Public Docs Publisher');
  console.log('=====================================');
  
  try {
    // Scan for markdown files
    console.log(`📁 Scanning ${CONFIG.sourceDir} for markdown files...`);
    const files = scanDirectory(CONFIG.sourceDir);
    console.log(`✅ Found ${files.length} markdown files`);
    
    if (files.length === 0) {
      console.log('⚠️ No markdown files found, creating sample documentation');
      // Create sample documentation
      const sampleContent = `# Welcome to 02luka Docs

This is a sample documentation page. Replace this with your actual documentation.

## Getting Started

1. Add your markdown files to \`g/manuals/\`
2. Run \`node run/publish_docs.cjs\` to generate HTML
3. Deploy to GitHub Pages

## Features

- **Search functionality** - Find documents quickly
- **Dark mode** - Toggle between light and dark themes
- **Responsive design** - Works on all devices
- **Auto-generated index** - Table of contents for all docs
`;
      
      const samplePath = path.join(CONFIG.sourceDir, 'README.md');
      if (!fs.existsSync(CONFIG.sourceDir)) {
        fs.mkdirSync(CONFIG.sourceDir, { recursive: true });
      }
      fs.writeFileSync(samplePath, sampleContent);
      files.push({
        fullPath: samplePath,
        relativePath: 'README.md',
        name: 'README.md',
        category: 'General'
      });
    }
    
    // Process markdown files
    console.log('📝 Processing markdown files...');
    const docs = files.map(processMarkdownFile).filter(Boolean);
    console.log(`✅ Processed ${docs.length} documents`);
    
    // Generate individual HTML pages
    console.log('🌐 Generating HTML pages...');
    const sidebar = generateSidebar(docs);
    
    docs.forEach(doc => {
      const html = generatePageTemplate(doc.title, doc.content, sidebar);
      const outputPath = path.join(CONFIG.outputDir, doc.url);
      const outputDir = path.dirname(outputPath);
      
      if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
      }
      
      fs.writeFileSync(outputPath, html);
      console.log(`  ✅ ${doc.url}`);
    });
    
    // Generate index.html
    console.log('📋 Generating index.html...');
    const indexHtml = generateIndex(docs);
    fs.writeFileSync(path.join(CONFIG.outputDir, 'index.html'), indexHtml);
    console.log('  ✅ index.html');
    
    // Generate assets
    console.log('🎨 Generating CSS and JS assets...');
    generateCSS();
    generateJS();
    
    console.log('');
    console.log('✅ Phase 10.3 Docs Publisher completed successfully!');
    console.log(`📚 Generated ${docs.length} documents in ${CONFIG.outputDir}`);
    console.log(`🎨 Assets: ${CONFIG.assetsDir}/docs.css, ${CONFIG.assetsDir}/docs.js`);
    console.log(`🌐 Index: ${CONFIG.outputDir}/index.html`);
    console.log(`📱 Features: Search, dark mode, responsive design`);
    
  } catch (error) {
    console.error('❌ Error in docs publisher:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { main, markdownToHtml, generatePageTemplate };
