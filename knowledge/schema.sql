-- Phase 7.5: SQLite Knowledge Base Schema
-- Unified offline-first storage for memories, telemetry, reports, insights

-- Memories (vector-backed TF-IDF persisted as JSON)
CREATE TABLE IF NOT EXISTS memories (
  id TEXT PRIMARY KEY,
  kind TEXT,
  text TEXT,
  importance REAL,
  queryCount INTEGER,
  lastAccess TEXT,
  timestamp TEXT,
  meta TEXT,
  tokens TEXT,
  vector TEXT
);

-- Telemetry (NDJSON flattened)
CREATE TABLE IF NOT EXISTS telemetry (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT,
  task TEXT,
  pass INTEGER,
  warn INTEGER,
  fail INTEGER,
  duration_ms INTEGER,
  meta TEXT
);

-- Reports (content and minimal metadata)
CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  filename TEXT,
  type TEXT,
  generated TEXT,
  content TEXT,
  metadata TEXT
);

-- Agent-scoped notes (optional, future use)
CREATE TABLE IF NOT EXISTS agent_memories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agent TEXT,
  category TEXT,
  content TEXT,
  timestamp TEXT,
  metadata TEXT
);

-- Insights cache (from Phase 7.1 self-review)
CREATE TABLE IF NOT EXISTS insights (
  id TEXT PRIMARY KEY AUTOINCREMENT,
  text TEXT,
  confidence REAL,
  actionable INTEGER,
  generatedBy TEXT,
  timestamp TEXT,
  type TEXT,
  meta TEXT
);

-- FTS indices (fast full-text)
CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts
USING fts5(text, content='memories', content_rowid='rowid');

CREATE VIRTUAL TABLE IF NOT EXISTS reports_fts
USING fts5(content, content='reports', content_rowid='id');
