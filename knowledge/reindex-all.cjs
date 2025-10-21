#!/usr/bin/env node
/* Reindex all documents with embeddings */

const fs = require('fs');
const path = require('path');
const glob = require('glob');
const sqlite3 = require('sqlite3').verbose();
const { semanticChunk } = require('./chunker.cjs');
const { getBatchEmbeddings } = require('./embedder.cjs');

const ROOT = path.resolve(__dirname, '..');
const DB_PATH = path.join(ROOT, 'knowledge', '02luka.db');
const BATCH_SIZE = 10; // Process 10 chunks at a time

async function main() {
  console.log('🔄 Starting full reindex with embeddings...\n');

  const db = await openDb(DB_PATH);

  // Ensure schema exists
  await ensureSchema(db);

  // Find all markdown files
  const files = await findAllMarkdownFiles();
  console.log(`📁 Found ${files.length} markdown files to index\n`);

  let totalChunks = 0;
  let processedFiles = 0;
  const startTime = Date.now();

  // Clear existing chunks
  await runAsync(db, 'DELETE FROM document_chunks');
  console.log('🗑️  Cleared existing chunks\n');

  // Process each file
  for (const filepath of files) {
    try {
      const relPath = path.relative(ROOT, filepath);
      const content = fs.readFileSync(filepath, 'utf8');

      // Skip empty files
      if (content.trim().length === 0) continue;

      // Chunk the document
      const chunks = semanticChunk(content, { filepath: relPath });

      if (chunks.length === 0) continue;

      // Generate embeddings in batches
      const texts = chunks.map(c => c.text);
      const embeddings = await getBatchEmbeddings(texts);

      // Insert chunks into database
      for (let i = 0; i < chunks.length; i++) {
        const chunk = chunks[i];
        const embedding = embeddings[i];

        await insertChunk(db, {
          ...chunk,
          embedding: floatArrayToBuffer(embedding)
        });

        totalChunks++;
      }

      processedFiles++;
      if (processedFiles % 10 === 0) {
        console.log(`  ✓ Processed ${processedFiles}/${files.length} files (${totalChunks} chunks)`);
      }

    } catch (err) {
      console.error(`  ✗ Error processing ${filepath}: ${err.message}`);
    }
  }

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log(`\n✅ Reindex complete!`);
  console.log(`   Files: ${processedFiles}/${files.length}`);
  console.log(`   Chunks: ${totalChunks}`);
  console.log(`   Time: ${elapsed}s`);
  console.log(`   Rate: ${(totalChunks / elapsed).toFixed(1)} chunks/sec\n`);

  db.close();
}

/**
 * Find all markdown files to index
 * @returns {Promise<string[]>} - Array of file paths
 */
async function findAllMarkdownFiles() {
  const patterns = [
    path.join(ROOT, 'docs/**/*.md'),
    path.join(ROOT, 'g/reports/**/*.md'),
    path.join(ROOT, 'memory/**/*.md'),
    path.join(ROOT, 'boss/reports/**/*.md'),
    path.join(ROOT, '*.md') // Root-level docs (README, etc.)
  ];

  const excludePatterns = [
    '**/node_modules/**',
    '**/.git/**',
    '**/archive/**',
    '**/deprecated/**'
  ];

  let allFiles = [];
  for (const pattern of patterns) {
    const files = glob.sync(pattern, { ignore: excludePatterns });
    allFiles = allFiles.concat(files);
  }

  // Deduplicate
  return [...new Set(allFiles)].sort();
}

/**
 * Ensure database schema exists
 * @param {object} db - Database connection
 */
async function ensureSchema(db) {
  await runAsync(db, `
    CREATE TABLE IF NOT EXISTS document_chunks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      doc_path TEXT NOT NULL,
      chunk_index INTEGER NOT NULL,
      text TEXT NOT NULL,
      embedding BLOB,
      metadata TEXT,
      indexed_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  await runAsync(db, `
    CREATE VIRTUAL TABLE IF NOT EXISTS document_chunks_fts
    USING fts5(text, content='document_chunks', content_rowid='id')
  `);

  await runAsync(db, `
    CREATE INDEX IF NOT EXISTS idx_doc_path ON document_chunks(doc_path)
  `);
}

/**
 * Insert chunk into database
 * @param {object} db - Database connection
 * @param {object} chunk - Chunk data
 */
async function insertChunk(db, chunk) {
  const metadata = JSON.stringify({
    hierarchy: chunk.hierarchy,
    section: chunk.section,
    tags: chunk.tags,
    importance: chunk.importance,
    ...chunk.metadata
  });

  // Insert into main table
  const result = await runAsync(db, `
    INSERT INTO document_chunks (doc_path, chunk_index, text, embedding, metadata)
    VALUES (?, ?, ?, ?, ?)
  `, [chunk.doc_path, chunk.chunk_index, chunk.text, chunk.embedding, metadata]);

  // Insert into FTS table
  await runAsync(db, `
    INSERT INTO document_chunks_fts (rowid, text)
    VALUES (?, ?)
  `, [result.lastID, chunk.text]);
}

/**
 * Convert float array to Buffer (for BLOB storage)
 * @param {number[]} floatArray - Embedding vector
 * @returns {Buffer} - Binary buffer
 */
function floatArrayToBuffer(floatArray) {
  const buffer = Buffer.allocUnsafe(floatArray.length * 4);
  const view = new Float32Array(buffer.buffer, buffer.byteOffset, floatArray.length);
  view.set(floatArray);
  return buffer;
}

/**
 * Open SQLite database
 * @param {string} dbPath - Path to database
 * @returns {Promise<object>} - Database connection
 */
function openDb(dbPath) {
  return new Promise((resolve, reject) => {
    const db = new sqlite3.Database(dbPath, err => {
      if (err) return reject(err);
      resolve(db);
    });
  });
}

/**
 * Run SQL with parameters (promisified)
 * @param {object} db - Database connection
 * @param {string} sql - SQL query
 * @param {Array} params - Parameters
 * @returns {Promise<object>} - Result
 */
function runAsync(db, sql, params = []) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function(err) {
      if (err) return reject(err);
      resolve({ lastID: this.lastID, changes: this.changes });
    });
  });
}

// Run if called directly
if (require.main === module) {
  main().catch(err => {
    console.error('❌ Reindex failed:', err);
    process.exit(1);
  });
}

module.exports = { main, findAllMarkdownFiles, ensureSchema };
