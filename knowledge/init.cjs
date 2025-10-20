#!/usr/bin/env node
/**
 * Phase 7.5: Local Knowledge Consolidation
 * Database Initialization Script
 *
 * Creates and initializes the 02luka.db SQLite database with schema.
 *
 * Usage:
 *   node init.cjs [--force]
 *
 * Options:
 *   --force  Drop and recreate database if it exists
 */

const fs = require('fs');
const path = require('path');

// Check if better-sqlite3 is installed
let Database;
try {
  Database = require('better-sqlite3');
} catch (err) {
  console.error('❌ Error: better-sqlite3 is not installed.');
  console.error('');
  console.error('This is a known issue on macOS 15 (Sequoia) with node-gyp.');
  console.error('');
  console.error('To fix, please run:');
  console.error('  bash scripts/fix_xcode_for_node_gyp.sh');
  console.error('');
  console.error('Or install Xcode (full version) temporarily:');
  console.error('  xcode-select --install');
  console.error('  # Then install from App Store');
  console.error('  sudo xcode-select --switch /Applications/Xcode.app');
  console.error('  cd knowledge && npm install better-sqlite3');
  console.error('');
  process.exit(1);
}

const REPO_ROOT = path.join(__dirname, '..');
const DB_PATH = path.join(__dirname, '02luka.db');
const SCHEMA_PATH = path.join(__dirname, 'schema.sql');

// Parse CLI args
const args = process.argv.slice(2);
const force = args.includes('--force');

/**
 * Initialize database with schema
 */
function initializeDatabase() {
  console.log('=== Phase 7.5: Knowledge Database Initialization ===\n');

  // Check if DB exists
  if (fs.existsSync(DB_PATH)) {
    if (!force) {
      console.log('✅ Database already exists at:', DB_PATH);
      console.log('');
      console.log('To recreate, run with --force flag:');
      console.log('  node init.cjs --force');
      return;
    } else {
      console.log('⚠️  Dropping existing database...');
      fs.unlinkSync(DB_PATH);
    }
  }

  // Read schema
  console.log('📄 Reading schema from:', SCHEMA_PATH);
  if (!fs.existsSync(SCHEMA_PATH)) {
    console.error('❌ Schema file not found:', SCHEMA_PATH);
    process.exit(1);
  }

  const schema = fs.readFileSync(SCHEMA_PATH, 'utf8');

  // Create database
  console.log('🔨 Creating database:', DB_PATH);
  const db = new Database(DB_PATH);

  // Enable WAL mode for better concurrency
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');

  // Execute schema
  console.log('📊 Executing schema...');
  try {
    db.exec(schema);
    console.log('✅ Schema applied successfully\n');
  } catch (error) {
    console.error('❌ Schema execution failed:', error.message);
    db.close();
    fs.unlinkSync(DB_PATH);
    process.exit(1);
  }

  // Verify tables
  console.log('🔍 Verifying tables...');
  const tables = db.prepare(`
    SELECT name FROM sqlite_master
    WHERE type='table' AND name NOT LIKE 'sqlite_%'
    ORDER BY name
  `).all();

  console.log('');
  console.log('Tables created:');
  tables.forEach(t => {
    const count = db.prepare(`SELECT COUNT(*) as count FROM ${t.name}`).get();
    console.log(`  ✓ ${t.name.padEnd(20)} (${count.count} rows)`);
  });

  // Verify FTS tables
  const ftsTables = db.prepare(`
    SELECT name FROM sqlite_master
    WHERE type='table' AND name LIKE '%_fts'
    ORDER BY name
  `).all();

  if (ftsTables.length > 0) {
    console.log('');
    console.log('FTS5 virtual tables:');
    ftsTables.forEach(t => console.log(`  ✓ ${t.name}`));
  }

  // Verify indices
  const indices = db.prepare(`
    SELECT COUNT(*) as count FROM sqlite_master
    WHERE type='index' AND name NOT LIKE 'sqlite_%'
  `).get();

  console.log('');
  console.log(`Indices created: ${indices.count}`);

  // Verify triggers
  const triggers = db.prepare(`
    SELECT COUNT(*) as count FROM sqlite_master
    WHERE type='trigger'
  `).get();

  console.log(`Triggers created: ${triggers.count}`);

  // Close database
  db.close();

  // Summary
  console.log('');
  console.log('=== Initialization Complete ✅ ===');
  console.log('');
  console.log('Database:', DB_PATH);
  console.log('Size:', (fs.statSync(DB_PATH).size / 1024).toFixed(2), 'KB');
  console.log('');
  console.log('Next steps:');
  console.log('  1. Run initial sync: node sync.cjs');
  console.log('  2. Query memories: node cli/search.cjs "keyword"');
  console.log('  3. Export data: node cli/export.cjs');
  console.log('');
}

// Run initialization
try {
  initializeDatabase();
} catch (error) {
  console.error('❌ Initialization failed:', error.message);
  console.error('');
  console.error('Stack trace:');
  console.error(error.stack);
  process.exit(1);
}
